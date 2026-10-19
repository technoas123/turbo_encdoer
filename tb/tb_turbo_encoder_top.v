`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: tb_turbo_encoder_top
// Engineer: Ahammed Salahuddeen N Y
// Description: AXI Stream based automated cross-verification testbench for the
//              DVB-RCS2 Turbo Encoder. Compares FPGA outputs against Octave
//              reference vectors with FSM probes, watchdog, and field-level
//              diagnostics.
//////////////////////////////////////////////////////////////////////////////////

module tb_turbo_encoder_top;

    localparam ADDR_WIDTH  = 6;
    localparam N_COUPLES   = 48;
    localparam N_BITS      = 96;
    localparam N_IN_WORDS  = 3;     // 96 bits / 32 bits per word
    localparam N_OUT_WORDS = 9;     // 288 bits / 32 bits per word
    localparam TIMEOUT_CYC = 5000;

    // FSM state codes (kept in sync with turbo_encoder_top)
    localparam S_PASS1_TAIL  = 4'd2;
    localparam S_PASS3_TAIL  = 4'd6;
    localparam S_PASS3_TAIL2 = 4'd11;
    localparam S_READOUT     = 4'd9;

    // Reference circular states (from Octave)
    localparam EXPECTED_LAST_STATE1 = 4'd15;
    localparam EXPECTED_C1          = 4'd7;
    localparam EXPECTED_LAST_STATE2 = 4'd11;
    localparam EXPECTED_C2          = 4'd5;

    // Parameters read from tb_parameters.txt
    integer param_N;
    integer param_P;
    integer param_Q0, param_Q1, param_Q2, param_Q3;
    integer param_C1, param_C2;

    // ---------------- DUT ports (AXI Stream) ----------------
    reg        clk;
    reg        rst_n;

    reg        s_axis_tvalid;
    wire       s_axis_tready;
    reg [31:0] s_axis_tdata;
    reg        s_axis_tlast;

    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire [31:0] m_axis_tdata;
    wire        m_axis_tlast;

    turbo_encoder_top #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
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

    // 100 MHz system clock (10 ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================================
    //  INTERNAL FSM PROBES
    // =================================================================
    reg [3:0] probed_c1;
    reg [3:0] probed_c2;
    reg       bug1_flag;
    reg       bug2_flag;
    reg       tail2_seen;

    initial begin
        probed_c1  = 4'hx;
        probed_c2  = 4'hx;
        bug1_flag  = 1'b0;
        bug2_flag  = 1'b0;
        tail2_seen = 1'b0;
    end

    always @(posedge clk) begin
        if (uut.state_reg == S_PASS1_TAIL) begin
            probed_c1 <= uut.rom_circ_state;
            if (uut.rom_circ_state !== EXPECTED_C1) begin
                $display("[DBG] %0t  PASS1_TAIL : lastState1=%0d (expect %0d) -> C1=%0d (expect %0d)   <-- BUG #1",
                         $time, uut.ce_state_out, EXPECTED_LAST_STATE1,
                         uut.rom_circ_state, EXPECTED_C1);
                bug1_flag <= 1'b1;
            end else begin
                $display("[DBG] %0t  PASS1_TAIL : lastState1=%0d -> C1=%0d   OK",
                         $time, uut.ce_state_out, uut.rom_circ_state);
            end
        end

        if (uut.state_reg == S_PASS3_TAIL2) begin
            tail2_seen <= 1'b1;
            probed_c2  <= uut.rom_circ_state;
            if (uut.rom_circ_state !== EXPECTED_C2) begin
                $display("[DBG] %0t  PASS3_TAIL2: lastState2=%0d (expect %0d) -> C2=%0d (expect %0d)   <-- BUG #2",
                         $time, uut.ce_state_out, EXPECTED_LAST_STATE2,
                         uut.rom_circ_state, EXPECTED_C2);
                bug2_flag <= 1'b1;
            end else begin
                $display("[DBG] %0t  PASS3_TAIL2: lastState2=%0d -> C2=%0d   OK",
                         $time, uut.ce_state_out, uut.rom_circ_state);
            end
        end

        if (uut.state_reg == S_PASS3_TAIL) begin
            $display("[DBG] %0t  PASS3_TAIL  : ce_state_out=%0d (still S47; PASS3_TAIL2 missing in RTL)",
                     $time, uut.ce_state_out);
        end
    end

    // =================================================================
    //  SYMBOL/PIPE-VALID COUNTERS (for debug)
    // =================================================================
    integer pipe_valid_cnt;
    integer sym_valid_cnt;
    initial begin
        pipe_valid_cnt = 0;
        sym_valid_cnt  = 0;
    end
    always @(posedge clk) begin
        if (rst_n && (uut.state_reg == S_READOUT) && uut.pipe_valid)
            pipe_valid_cnt <= pipe_valid_cnt + 1;
        if (rst_n && uut.sym_valid)
            sym_valid_cnt  <= sym_valid_cnt + 1;
    end

    // =================================================================
    //  WATCHDOG
    // =================================================================
    integer wd_cycles;
    initial wd_cycles = 0;

    reg [3:0] wd_state_prev;
    initial wd_state_prev = 4'd0;

    always @(posedge clk) begin
        if (!rst_n) begin
            wd_cycles      <= 0;
            wd_state_prev  <= 4'd0;
        end
        else if (uut.state_reg != wd_state_prev) begin
            wd_cycles     <= 0;
            wd_state_prev <= uut.state_reg;
        end
        else begin
            wd_cycles <= wd_cycles + 1;
        end

        if (wd_cycles > TIMEOUT_CYC) begin
            $display("\n[FATAL] WATCHDOG TIMEOUT after %0d cycles in state %0d.", TIMEOUT_CYC, uut.state_reg);
            $display("[FATAL] count = %0d, pipe_valid = %b, arp_enable = %b",
                     uut.count, uut.pipe_valid, uut.arp_enable);
            $display("[FATAL] packer: acc_bits=%0d word_cnt=%0d m_axis_tvalid=%b",
                     uut.out_acc_bits, uut.out_word_cnt, uut.m_axis_tvalid);
            $display("[FATAL] counters: pipe_valid_cnt=%0d sym_valid_cnt=%0d (expect 48 each)",
                     pipe_valid_cnt, sym_valid_cnt);

            if (uut.state_reg == 4'd7)
                $display("[FATAL] Detected: stuck in PASS4.");
            else if (uut.state_reg == S_READOUT)
                $display("[FATAL] Detected: stuck in READOUT.");
            else if (uut.state_reg == 4'd0)
                $display("[FATAL] Detected: FSM in IDLE but output packer not drained.");

            if (!tail2_seen)
                $display("[FATAL] Detected: PASS3_TAIL2 was never reached.");

            if (bug1_flag)
                $display("[FATAL] Detected: C1 is wrong.");

            $display("");
            $finish;
        end
    end

    // =================================================================
    //  REFERENCE / CAPTURE STORAGE
    // =================================================================
    reg [0:0] raw_input_bits       [0:N_BITS-1];
    reg [7:0] expected_hex_symbols [0:N_COUPLES-1];
    reg [5:0] captured_symbols     [0:N_COUPLES-1];

    // Buffer to hold the 9 x 32-bit AXI Stream output words.
    // *** FIX B ***
    // Built as a genuine MSB-first shift register (see assembly loop
    // below) so that this 288-bit value represents the logical message
    // M[287:0] with M[287:282]=symbol0 ... M[5:0]=symbol47, matching
    // the RTL's actual output-accumulator convention.
    reg [N_OUT_WORDS*32-1:0] received_bitstream;

    integer i;
    integer word_idx;
    integer sym_count;
    integer match_count;
    integer error_count;
    integer sys_match;
    integer par1_match;
    integer par2_match;

    integer fd;

    // =================================================================
    //  AXI STREAM INPUT TASK
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
    //  MAIN FLOW
    // =================================================================
    initial begin
        rst_n          = 0;
        s_axis_tvalid  = 0;
        s_axis_tdata   = 32'd0;
        s_axis_tlast   = 0;
        m_axis_tready  = 1'b1;
        sym_count      = 0;

        $readmemb("tb_input_bits.txt",       raw_input_bits);
        $readmemh("tb_expected_symbols.txt", expected_hex_symbols);

        begin
            fd = $fopen("tb_parameters.txt", "r");
            if (fd == 0) begin
                $display("[WARN] Could not open tb_parameters.txt; using defaults");
                param_N = 48; param_P = 13;
                param_Q0 = 0; param_Q1 = 2; param_Q2 = 4; param_Q3 = 6;
                param_C1 = 7; param_C2 = 5;
            end
            else begin
                $fscanf(fd, "N=%d\n", param_N);
                $fscanf(fd, "P=%d\n", param_P);
                $fscanf(fd, "Q0=%d\n", param_Q0);
                $fscanf(fd, "Q1=%d\n", param_Q1);
                $fscanf(fd, "Q2=%d\n", param_Q2);
                $fscanf(fd, "Q3=%d\n", param_Q3);
                $fscanf(fd, "C1=%d\n", param_C1);
                $fscanf(fd, "C2=%d\n", param_C2);
                $fclose(fd);
            end
        end

        @(negedge clk);
        rst_n = 1;

        $display("");
        $display("=== DVB-RCS2 Turbo Encoder AXI Stream Cross-Verification ===");
        $display("[INFO] Expected: C1=%0d (lastState1=%0d), C2=%0d (lastState2=%0d)",
                 EXPECTED_C1, EXPECTED_LAST_STATE1, EXPECTED_C2, EXPECTED_LAST_STATE2);
        $display("");

        for (word_idx = 0; word_idx < N_IN_WORDS; word_idx = word_idx + 1) begin
            s_axis_tdata = 32'd0;
            for (i = 0; i < 16; i = i + 1) begin
                s_axis_tdata[{i[3:0], 1'b0} +: 2] = {raw_input_bits[2*(16*word_idx + i)],
                                                      raw_input_bits[2*(16*word_idx + i) + 1]};
            end
            send_input_word(s_axis_tdata, (word_idx == N_IN_WORDS - 1));
            $display("[INFO] Sent input word %0d: 0x%08X", word_idx, s_axis_tdata);
        end

        $display("[INFO] Input block sent. FSM running Pass1->2->3->4->Readout...");
        $display("");

        // *** FIX B ***
        // Assemble the output message as a true shift register, matching
        // the RTL's own (out_acc << 6) | sym_data convention:
        //   - The FIRST word received is the MOST-significant chunk of
        //     the logical 288-bit message (it was produced first, i.e.
        //     it contains the OLDEST / first symbols).
        //   - Each subsequent word shifts the accumulated message LEFT
        //     by 32 and inserts the new word at the bottom (LSB end).
        //   - After all 9 words arrive, received_bitstream[287:0] holds
        //     M[287:0] = {symbol0, symbol1, ..., symbol47} MSB-first.
        received_bitstream = {N_OUT_WORDS*32{1'b0}};

        word_idx = 0;
        while (word_idx < N_OUT_WORDS) begin
            @(posedge clk);
            if (m_axis_tvalid) begin
                received_bitstream = {received_bitstream[N_OUT_WORDS*32-33:0], m_axis_tdata};
                $display("[OUT] %0d: 0x%08X tlast=%b acc=%0d cnt=%0d",
                         word_idx, m_axis_tdata, m_axis_tlast,
                         uut.out_acc_bits, uut.out_word_cnt);
                word_idx = word_idx + 1;
            end
        end

        // *** FIX B ***
        // Symbol i occupies message bits [287-6*i : 287-6*i-5], MSB-first.
        // (Previously assumed LSB-first: received_bitstream[6*i+5 -: 6],
        //  which read the mirror-image location in the stream.)
        for (i = 0; i < N_COUPLES; i = i + 1) begin
            captured_symbols[i] = received_bitstream[(N_OUT_WORDS*32-1) - 6*i -: 6];
        end

        // --- Compare and report ---
        match_count = 0;
        error_count = 0;
        sys_match   = 0;
        par1_match  = 0;
        par2_match  = 0;

        $display("");
        $display("=================== VERIFICATION RESULTS (Octave vs Vivado) ===================");
        $display("Idx |  FPGA  = {A,B,Y1,W1,Y2,W2} |  Octave = {A,B,Y1,W1,Y2,W2} | Status");
        $display("----+----------------------------+-----------------------------+-------");

        for (i = 0; i < N_COUPLES; i = i + 1) begin
            if (captured_symbols[i][5:4] == expected_hex_symbols[i][5:4])
                sys_match  = sys_match  + 1;
            if (captured_symbols[i][3:2] == expected_hex_symbols[i][3:2])
                par1_match = par1_match + 1;
            if (captured_symbols[i][1:0] == expected_hex_symbols[i][1:0])
                par2_match = par2_match + 1;

            if (captured_symbols[i] == expected_hex_symbols[i][5:0]) begin
                $display("%3d | 6'b%b  (%02X)            | 6'b%b  (%02X)             | PASS",
                         i, captured_symbols[i], captured_symbols[i],
                            expected_hex_symbols[i][5:0], expected_hex_symbols[i][5:0]);
                match_count = match_count + 1;
            end else begin
                $display("%3d | 6'b%b  (%02X)            | 6'b%b  (%02X)             | FAIL",
                         i, captured_symbols[i], captured_symbols[i],
                            expected_hex_symbols[i][5:0], expected_hex_symbols[i][5:0]);
                error_count = error_count + 1;
            end
        end

        $display("-------------------------------------------------------------------------------");
        $display("SUMMARY");
        $display("  Full-symbol matches : %0d / %0d", match_count, N_COUPLES);
        $display("  Mismatches          : %0d",        error_count);
        $display("  Field-level matches :");
        $display("    sys  (A , B)      : %0d / %0d", sys_match,  N_COUPLES);
        $display("    par1 (Y1, W1)     : %0d / %0d    [Pass 2, RSC1]", par1_match, N_COUPLES);
        $display("    par2 (Y2, W2)     : %0d / %0d    [Pass 4, RSC2 + ARP]", par2_match, N_COUPLES);
        $display("  Probed C1 = %0d (expect %0d),  C2 = %0d (expect %0d)",
                 probed_c1, EXPECTED_C1, probed_c2, EXPECTED_C2);
        $display("  Parameters from file: N=%0d P=%0d Q=[%0d,%0d,%0d,%0d] C1=%0d C2=%0d",
                 param_N, param_P, param_Q0, param_Q1, param_Q2, param_Q3, param_C1, param_C2);
        $display("-------------------------------------------------------------------------------");

        if (error_count == 0) begin
            $display("");
            $display("  SUCCESS: VERILOG RTL MATCHES OCTAVE REFERENCE 100%%!");
            $display("");
        end else begin
            $display("");
            $display("  FAILURE: %0d symbol mismatches.", error_count);
            $display("  Diagnosis:");

            if (sys_match < N_COUPLES && par1_match < N_COUPLES && par2_match < N_COUPLES)
                $display("   -> ALL fields wrong: input packing / RAM / reset problem.");
            else if (par1_match < N_COUPLES && par2_match < N_COUPLES)
                $display("   -> BOTH parity streams wrong: check C1 and C2.");
            else if (par1_match < N_COUPLES)
                $display("   -> Y1/W1 wrong: check Pass 1 dry-run and C1 load (BUG #1).");
            else if (par2_match < N_COUPLES)
                $display("   -> Y2/W2 wrong: check Pass 3 tail / C2 load / ARP swap (BUG #2).");

            if (bug1_flag)
                $display("   -> CONFIRMED BUG #1: C1 wrong.");
            if (!tail2_seen)
                $display("   -> CONFIRMED BUG #2: PASS3_TAIL2 absent.");
            $display("");
        end

        $display("=== SUMMARY ===");
        $display("words=%0d/9 acc_bits=%0d word_cnt=%0d state=%0d output_done=%b",
                 word_idx, uut.out_acc_bits, uut.out_word_cnt, uut.state_reg, uut.output_done);
        $display("pipe_valid_cnt=%0d sym_valid_cnt=%0d (expect 48 each)",
                 pipe_valid_cnt, sym_valid_cnt);
        $display("c1=%0d/%0d c2=%0d/%0d bug1=%b bug2=%b tail2=%b",
                 probed_c1, param_C1, probed_c2, param_C2, bug1_flag, bug2_flag, tail2_seen);

        if ((probed_c1 !== param_C1) || (probed_c2 !== param_C2))
            $display("[FAIL] Circular states do not match tb_parameters.txt");
        else
            $display("[OK]   Circular states match tb_parameters.txt");

        #40;
        $finish;
    end

endmodule