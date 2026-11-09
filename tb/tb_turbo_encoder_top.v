`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_turbo_encoder_top
// Dual-FIFO turbo encoder + shift-register LOAD path.
//
// Plusargs:
//   +STALL=0/1/2/3   output back-pressure mode (default 0)
//   +SEED=n          RNG seed (default 1)
//   +HOLD=n          STALL=3 hold cycles (default 60)
//////////////////////////////////////////////////////////////////////////////////

module tb_turbo_encoder_top;

    localparam ADDR_WIDTH  = 6;
    localparam N_COUPLES   = 48;
    localparam N_BITS      = 96;
    localparam N_IN_WORDS  = 3;
    localparam N_OUT_WORDS = 9;
    localparam TIMEOUT_CYC = 8000;

    // FSM state codes (must match turbo_encoder_top.v)
    localparam S_IDLE         = 4'd0;
    localparam S_PASS1        = 4'd1;
    localparam S_PASS1_TAIL   = 4'd2;
    localparam S_PASS2        = 4'd3;
    localparam S_PASS3_TAIL2  = 4'd11;
    localparam S_READOUT      = 4'd9;
    localparam S_LOAD         = 4'd12;
    localparam S_LOAD_RELOAD  = 4'd13;

    localparam EXPECTED_LAST_STATE1 = 4'd15;
    localparam EXPECTED_C1          = 4'd7;
    localparam EXPECTED_LAST_STATE2 = 4'd11;
    localparam EXPECTED_C2          = 4'd5;

    integer param_N, param_P;
    integer param_Q0, param_Q1, param_Q2, param_Q3;
    integer param_C1, param_C2;

    // ---------------- DUT ports ----------------
    reg         clk;
    reg         rst_n;

    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tlast;

    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire [31:0] m_axis_tdata;
    wire        m_axis_tlast;

    turbo_encoder_top #(.ADDR_WIDTH(ADDR_WIDTH)) uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tlast  (s_axis_tlast),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tlast  (m_axis_tlast)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================================
    // OUTPUT BACK-PRESSURE DRIVER
    // =================================================================
    integer    stall_mode;
    integer    seed_init, seed_state;
    integer    hold_cycles, hold_cnt;
    reg [31:0] rnd;

    initial begin
        stall_mode  = 0;
        seed_init   = 1;
        hold_cycles = 60;
        hold_cnt    = 0;
        if (!$value$plusargs("STALL=%d", stall_mode))  stall_mode  = 0;
        if (!$value$plusargs("SEED=%d",  seed_init))   seed_init   = 1;
        if (!$value$plusargs("HOLD=%d",  hold_cycles)) hold_cycles = 60;
        seed_state    = seed_init;
        m_axis_tready = (stall_mode != 3);
        $display("[TB] STALL mode=%0d seed=%0d hold=%0d", stall_mode, seed_init, hold_cycles);
    end

    always @(negedge clk) begin
        rnd = {$random(seed_state)};
        case (stall_mode)
            0: m_axis_tready = 1'b1;
            1: m_axis_tready = rnd[0];
            2: m_axis_tready = ((rnd % 10) < 2);
            3: begin
                if (m_axis_tvalid && (hold_cnt < hold_cycles))
                    hold_cnt = hold_cnt + 1;
                m_axis_tready = (hold_cnt >= hold_cycles);
            end
            default: m_axis_tready = 1'b1;
        endcase
    end

    // =================================================================
    // AXI OUTPUT RULE CHECKER
    // =================================================================
    reg        prev_valid, prev_ready, prev_last;
    reg [31:0] prev_data;
    integer    axi_violations;

    initial begin
        prev_valid = 0; prev_ready = 0; prev_data = 0; prev_last = 0;
        axi_violations = 0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_valid <= 0;
            prev_ready <= 0;
        end
        else begin
            if (prev_valid && !prev_ready) begin
                if (!m_axis_tvalid) begin
                    axi_violations = axi_violations + 1;
                    $display("[AXI-VIOLATION] %0t tvalid dropped while stalled", $time);
                end
                else begin
                    if (m_axis_tdata !== prev_data) begin
                        axi_violations = axi_violations + 1;
                        $display("[AXI-VIOLATION] %0t tdata changed while stalled", $time);
                    end
                    if (m_axis_tlast !== prev_last) begin
                        axi_violations = axi_violations + 1;
                        $display("[AXI-VIOLATION] %0t tlast changed while stalled", $time);
                    end
                end
            end
            prev_valid <= m_axis_tvalid;
            prev_ready <= m_axis_tready;
            prev_data  <= m_axis_tdata;
            prev_last  <= m_axis_tlast;
        end
    end

    // =================================================================
    // FIFO PEAK PROBES
    // =================================================================
    integer in_fifo_peak, out_fifo_peak;
    initial begin in_fifo_peak = 0; out_fifo_peak = 0; end

    always @(posedge clk) begin
        if (rst_n) begin
            if (uut.in_fifo_count  > in_fifo_peak)  in_fifo_peak  <= uut.in_fifo_count;
            if (uut.out_fifo_count > out_fifo_peak) out_fifo_peak <= uut.out_fifo_count;
        end
    end

    // =================================================================
    // LOAD / SHIFT PROBES  (new path)
    // =================================================================
    reg [1:0] expected_couple [0:N_COUPLES-1];
    reg [1:0] loaded_couple   [0:N_COUPLES-1];
    integer   load_wr_count;
    integer   load_mismatch;
    integer   load_done_flag;
    integer   reload_events;

    initial begin
        load_wr_count   = 0;
        load_mismatch   = 0;
        load_done_flag  = 0;
        reload_events   = 0;
    end

    // Capture every systematic write driven by the shifter
    always @(posedge clk) begin
        if (!rst_n) begin
            load_wr_count  <= 0;
            load_done_flag <= 0;
            reload_events  <= 0;
        end
        else begin
            if (uut.couple_valid &&
                (uut.state_reg == S_LOAD || uut.state_reg == S_LOAD_RELOAD)) begin
                if (load_wr_count < N_COUPLES) begin
                    loaded_couple[load_wr_count] <= uut.current_couple;
                    // Live boundary print
                    if ((load_wr_count % 16 == 0) || (load_wr_count % 16 == 15) ||
                        (load_wr_count == N_COUPLES-1)) begin
                        $display("[LOAD] %0t idx=%0d word_bit=%0d shift=%08h couple=%b",
                                 $time, load_wr_count, uut.word_bit_cnt,
                                 uut.shift_reg, uut.current_couple);
                    end
                    load_wr_count <= load_wr_count + 1;
                end
            end

            if (uut.state_reg == S_LOAD_RELOAD)
                reload_events <= reload_events + 1;

            // First cycle of PASS1 means LOAD finished
            if (uut.state_reg == S_PASS1 && !load_done_flag) begin
                load_done_flag <= 1;
                $display("[LOAD] %0t LOAD complete -> PASS1  writes=%0d",
                         $time, load_wr_count);
            end
        end
    end

    // =================================================================
    // FSM PROBES (circular states)
    // =================================================================
    reg [3:0] probed_c1, probed_c2;
    reg       bug1_flag, bug2_flag, tail2_seen;

    initial begin
        probed_c1 = 4'hx; probed_c2 = 4'hx;
        bug1_flag = 0; bug2_flag = 0; tail2_seen = 0;
    end

    always @(posedge clk) begin
        if (uut.state_reg == S_PASS1_TAIL) begin
            probed_c1 <= uut.rom_circ_state;
            if (uut.rom_circ_state !== EXPECTED_C1) begin
                $display("[DBG] %0t PASS1_TAIL: lastState1=%0d -> C1=%0d (expect %0d) BUG#1",
                         $time, uut.ce_state_out, uut.rom_circ_state, EXPECTED_C1);
                bug1_flag <= 1'b1;
            end
            else
                $display("[DBG] %0t PASS1_TAIL: lastState1=%0d -> C1=%0d OK",
                         $time, uut.ce_state_out, uut.rom_circ_state);
        end

        if (uut.state_reg == S_PASS3_TAIL2) begin
            tail2_seen <= 1'b1;
            probed_c2  <= uut.rom_circ_state;
            if (uut.rom_circ_state !== EXPECTED_C2) begin
                $display("[DBG] %0t PASS3_TAIL2: lastState2=%0d -> C2=%0d (expect %0d) BUG#2",
                         $time, uut.ce_state_out, uut.rom_circ_state, EXPECTED_C2);
                bug2_flag <= 1'b1;
            end
            else
                $display("[DBG] %0t PASS3_TAIL2: lastState2=%0d -> C2=%0d OK",
                         $time, uut.ce_state_out, uut.rom_circ_state);
        end
    end

    // =================================================================
    // Counters + watchdog
    // =================================================================
    integer pipe_valid_cnt, sym_valid_cnt;
    initial begin pipe_valid_cnt = 0; sym_valid_cnt = 0; end

    always @(posedge clk) begin
        if (rst_n && (uut.state_reg == S_READOUT) && uut.pipe_valid)
            pipe_valid_cnt <= pipe_valid_cnt + 1;
        if (rst_n && uut.sym_valid)
            sym_valid_cnt <= sym_valid_cnt + 1;
    end

    integer wd_cycles;
    reg [3:0] wd_state_prev;
    initial begin wd_cycles = 0; wd_state_prev = 0; end

    always @(posedge clk) begin
        if (!rst_n) begin
            wd_cycles     <= 0;
            wd_state_prev <= 0;
        end
        else if (uut.state_reg != wd_state_prev) begin
            wd_cycles     <= 0;
            wd_state_prev <= uut.state_reg;
            $display("[FSM] %0t -> state %0d  count=%0d word_bit=%0d",
                     $time, uut.state_reg, uut.count, uut.word_bit_cnt);
        end
        else
            wd_cycles <= wd_cycles + 1;

        if (wd_cycles > TIMEOUT_CYC) begin
            $display("\n[FATAL] WATCHDOG in state %0d after %0d cycles", uut.state_reg, TIMEOUT_CYC);
            $display("[FATAL] count=%0d pipe_valid=%b couple_valid=%b",
                     uut.count, uut.pipe_valid, uut.couple_valid);
            $display("[FATAL] word_bit=%0d shift=%08h", uut.word_bit_cnt, uut.shift_reg);
            $display("[FATAL] out_fifo=%0d in_fifo=%0d acc_bits=%0d word_cnt=%0d",
                     uut.out_fifo_count, uut.in_fifo_count, uut.out_acc_bits, uut.out_word_cnt);
            $display("[FATAL] tvalid=%b tready=%b", m_axis_tvalid, m_axis_tready);
            $finish;
        end
    end

    // =================================================================
    // Storage
    // =================================================================
    reg [0:0] raw_input_bits       [0:N_BITS-1];
    reg [7:0] expected_hex_symbols [0:N_COUPLES-1];
    reg [5:0] captured_symbols     [0:N_COUPLES-1];
    reg [N_OUT_WORDS*32-1:0] received_bitstream;

    integer i, word_idx, match_count, error_count;
    integer sys_match, par1_match, par2_match;
    integer tlast_errors, extra_words, fd, rc;
    integer c;

    // =================================================================
    // Input task
    // =================================================================
    task send_input_word;
        input [31:0] word_data;
        input        is_last;
        begin
            @(negedge clk);
            s_axis_tvalid = 1'b1;
            s_axis_tdata  = word_data;
            s_axis_tlast  = is_last;
            while (!s_axis_tready) @(negedge clk);
            @(negedge clk);
            s_axis_tvalid = 1'b0;
            s_axis_tlast  = 1'b0;
        end
    endtask

    // =================================================================
    // Main
    // =================================================================
    initial begin
        rst_n         = 0;
        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        s_axis_tlast  = 0;
        tlast_errors  = 0;
        extra_words   = 0;

        $readmemb("tb_input_bits.txt",       raw_input_bits);
        $readmemh("tb_expected_symbols.txt", expected_hex_symbols);

        // Build expected 2-bit couples from the same packing as AXI words
        for (c = 0; c < N_COUPLES; c = c + 1)
            expected_couple[c] = { raw_input_bits[2*c], raw_input_bits[2*c + 1] };

        fd = $fopen("tb_parameters.txt", "r");
        if (fd == 0) begin
            $display("[WARN] tb_parameters.txt missing - defaults");
            param_N = 48; param_P = 13;
            param_Q0 = 0; param_Q1 = 2; param_Q2 = 4; param_Q3 = 6;
            param_C1 = 7; param_C2 = 5;
        end
        else begin
            rc = $fscanf(fd, "N=%d\n",  param_N);
            rc = $fscanf(fd, "P=%d\n",  param_P);
            rc = $fscanf(fd, "Q0=%d\n", param_Q0);
            rc = $fscanf(fd, "Q1=%d\n", param_Q1);
            rc = $fscanf(fd, "Q2=%d\n", param_Q2);
            rc = $fscanf(fd, "Q3=%d\n", param_Q3);
            rc = $fscanf(fd, "C1=%d\n", param_C1);
            rc = $fscanf(fd, "C2=%d\n", param_C2);
            $fclose(fd);
        end

        @(negedge clk);
        rst_n = 1;

        $display("");
        $display("=== DVB-RCS2 Turbo Encoder  (shift-LOAD + dual-FIFO) ===");
        $display("[INFO] Expected C1=%0d C2=%0d", EXPECTED_C1, EXPECTED_C2);
        $display("");

        // Send one 3-word frame (same packing as shift reference)
        for (word_idx = 0; word_idx < N_IN_WORDS; word_idx = word_idx + 1) begin
            s_axis_tdata = 32'd0;
            for (i = 0; i < 16; i = i + 1) begin
                s_axis_tdata[{i[3:0], 1'b0} +: 2] =
                    {raw_input_bits[2*(16*word_idx + i)],
                     raw_input_bits[2*(16*word_idx + i) + 1]};
            end
            send_input_word(s_axis_tdata, (word_idx == N_IN_WORDS-1));
            $display("[INFO] Sent input word %0d: 0x%08X", word_idx, s_axis_tdata);
        end
        $display("[INFO] Input block sent. Core running (LOAD -> 4 passes -> OUT)...");
        $display("");

        // Collect 9 output words
        received_bitstream = {N_OUT_WORDS*32{1'b0}};
        word_idx = 0;
        while (word_idx < N_OUT_WORDS) begin
            @(posedge clk);
            if (m_axis_tvalid && m_axis_tready) begin
                received_bitstream = {received_bitstream[N_OUT_WORDS*32-33:0], m_axis_tdata};
                $display("[OUT] %0d: 0x%08X tlast=%b  out_fifo=%0d",
                         word_idx, m_axis_tdata, m_axis_tlast, uut.out_fifo_count);

                if (m_axis_tlast !== (word_idx == N_OUT_WORDS-1)) begin
                    tlast_errors = tlast_errors + 1;
                    $display("[TLAST-ERROR] word %0d tlast=%b expected %b",
                             word_idx, m_axis_tlast, (word_idx == N_OUT_WORDS-1));
                end
                word_idx = word_idx + 1;
            end
        end

        for (i = 0; i < N_COUPLES; i = i + 1)
            captured_symbols[i] = received_bitstream[(N_OUT_WORDS*32-1) - 6*i -: 6];

        // ---------------------------------------------------------------
        // A) LOAD path scoreboard (shift -> couples)
        // ---------------------------------------------------------------
        load_mismatch = 0;
        $display("");
        $display("=================== LOAD / SHIFT CHECK ====================");
        $display("writes=%0d  (expect %0d)  reload_events=%0d",
                 load_wr_count, N_COUPLES, reload_events);
        for (i = 0; i < N_COUPLES; i = i + 1) begin
            if (loaded_couple[i] !== expected_couple[i]) begin
                if (load_mismatch < 8)
                    $display("LOAD FAIL idx %0d got %b exp %b",
                             i, loaded_couple[i], expected_couple[i]);
                load_mismatch = load_mismatch + 1;
            end
        end
        if (load_wr_count == N_COUPLES && load_mismatch == 0)
            $display("[LOAD-RESULT] PASS  48/48 couples match reference packing");
        else
            $display("[LOAD-RESULT] FAIL  wr=%0d mism=%0d", load_wr_count, load_mismatch);

        // ---------------------------------------------------------------
        // B) Full encoded symbol compare (Octave golden)
        // ---------------------------------------------------------------
        match_count = 0; error_count = 0;
        sys_match = 0; par1_match = 0; par2_match = 0;

        $display("");
        $display("=================== ENCODER VERIFICATION ==================");
        $display("Idx | FPGA {A,B,Y1,W1,Y2,W2} | Octave | Status");
        $display("----+------------------------+--------+-------");

        for (i = 0; i < N_COUPLES; i = i + 1) begin
            if (captured_symbols[i][5:4] == expected_hex_symbols[i][5:4]) sys_match  = sys_match  + 1;
            if (captured_symbols[i][3:2] == expected_hex_symbols[i][3:2]) par1_match = par1_match + 1;
            if (captured_symbols[i][1:0] == expected_hex_symbols[i][1:0]) par2_match = par2_match + 1;

            if (captured_symbols[i] == expected_hex_symbols[i][5:0]) begin
                $display("%3d | 6'b%b (%02X) | 6'b%b (%02X) | PASS",
                         i, captured_symbols[i], captured_symbols[i],
                            expected_hex_symbols[i][5:0], expected_hex_symbols[i][5:0]);
                match_count = match_count + 1;
            end
            else begin
                $display("%3d | 6'b%b (%02X) | 6'b%b (%02X) | FAIL",
                         i, captured_symbols[i], captured_symbols[i],
                            expected_hex_symbols[i][5:0], expected_hex_symbols[i][5:0]);
                error_count = error_count + 1;
            end
        end

        $display("-----------------------------------------------------------");
        $display("SUMMARY  matches=%0d/%0d  mismatches=%0d", match_count, N_COUPLES, error_count);
        $display("  sys=%0d/%0d  par1=%0d/%0d  par2=%0d/%0d",
                 sys_match, N_COUPLES, par1_match, N_COUPLES, par2_match, N_COUPLES);
        $display("  C1=%0d (expect %0d)  C2=%0d (expect %0d)",
                 probed_c1, EXPECTED_C1, probed_c2, EXPECTED_C2);

        if (error_count == 0)
            $display("\n  SUCCESS: RTL matches Octave 100%%\n");
        else
            $display("\n  FAILURE: %0d mismatches\n", error_count);

        #40;
        if (m_axis_tvalid) begin
            extra_words = extra_words + 1;
            $display("[EXTRA-WORD] tvalid still high: %08X", m_axis_tdata);
        end

        $display("=== SUMMARY ===");
        $display("stall_mode=%0d seed=%0d", stall_mode, seed_init);
        $display("words=%0d/9 acc_bits=%0d word_cnt=%0d state=%0d output_done=%b",
                 word_idx, uut.out_acc_bits, uut.out_word_cnt, uut.state_reg, uut.output_done);
        $display("out_fifo_now=%0d out_fifo_peak=%0d  in_fifo_now=%0d in_fifo_peak=%0d",
                 uut.out_fifo_count, out_fifo_peak, uut.in_fifo_count, in_fifo_peak);
        $display("axi_violations=%0d tlast_errors=%0d extra_words=%0d",
                 axi_violations, tlast_errors, extra_words);
        $display("pipe_valid_cnt=%0d sym_valid_cnt=%0d (expect 48)", pipe_valid_cnt, sym_valid_cnt);
        $display("load_wr=%0d load_mism=%0d reload_ev=%0d",
                 load_wr_count, load_mismatch, reload_events);
        $display("c1=%0d/%0d c2=%0d/%0d bug1=%b bug2=%b tail2=%b",
                 probed_c1, param_C1, probed_c2, param_C2, bug1_flag, bug2_flag, tail2_seen);

        if ((probed_c1 !== param_C1) || (probed_c2 !== param_C2))
            $display("[FAIL] Circular states mismatch tb_parameters.txt");
        else
            $display("[OK]   Circular states match");

        if (load_wr_count == N_COUPLES && load_mismatch == 0 &&
            error_count == 0 && axi_violations == 0 &&
            tlast_errors == 0 && extra_words == 0)
            $display("[TB-RESULT] PASS  (LOAD + data + AXI rules + tlast)");
        else
            $display("[TB-RESULT] FAIL  (load_err=%0d enc_err=%0d axi=%0d tlast=%0d extra=%0d)",
                     load_mismatch, error_count, axi_violations, tlast_errors, extra_words);

        $finish;
    end

endmodule