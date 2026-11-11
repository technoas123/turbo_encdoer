`timescale 1ns / 1ps

`define DEBUG_DUMP 1

module tb_turbo_encoder_top;

    reg clk;
    reg rst_n;

    reg [5:0] cfg_waveform_id;
    reg       cfg_valid;

    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire        m_axis_tlast;

    turbo_encoder_top uut (
        .clk            (clk),
        .rst_n          (rst_n),
        .cfg_waveform_id(cfg_waveform_id),
        .cfg_valid      (cfg_valid),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast)
    );

    always #8.138 clk = ~clk;

    //--------------------------------------------------------------------------
    // Storage
    //--------------------------------------------------------------------------
    reg [31:0] in_mem  [0:2047];
    reg [31:0] out_mem [0:2047];
    reg [31:0] got_mem [0:2047];

    integer i, k;
    integer match_cnt, mismatch_cnt, frame_err;
    integer in_words, out_words;
    integer total_fail;
    integer first_bad;
    integer print_cnt;

    localparam MAX_PRINT   = 16;
    localparam IN_TIMEOUT  = 100000;   // cycles to push all input words
    localparam OUT_TIMEOUT = 200000;   // cycles to wait for tlast

    //--------------------------------------------------------------------------
    // Output monitor: records every accepted output beat
    //--------------------------------------------------------------------------
    integer got_cnt;
    integer tlast_cnt;
    integer last_idx;
    reg     mon_en;

    always @(posedge clk) begin
        if (mon_en && m_axis_tvalid && m_axis_tready) begin
            if (got_cnt < 2048) got_mem[got_cnt] = m_axis_tdata;
            if (m_axis_tlast) begin
                tlast_cnt = tlast_cnt + 1;
                last_idx  = got_cnt;
            end
            got_cnt = got_cnt + 1;
        end
    end

    //--------------------------------------------------------------------------
    // Global watchdog
    //--------------------------------------------------------------------------
    initial begin
        #100_000_000;
        $display("GLOBAL WATCHDOG TIMEOUT - simulation aborted");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Debug helpers
    //--------------------------------------------------------------------------
    task dump_bram_slice;
        input [255:0]     name;
        input [1:0]       dut_mem_sel;
        integer kk;
        begin
            $write("    %0s[0..11] = ", name);
            for (kk = 0; kk < 12; kk = kk + 1) begin
                case (dut_mem_sel)
                    2'd0: $write("%b%b ", uut.sys_ram.mem[kk][1],  uut.sys_ram.mem[kk][0]);
                    2'd1: $write("%b%b ", uut.par1_ram.mem[kk][1], uut.par1_ram.mem[kk][0]);
                    2'd2: $write("%b%b ", uut.par2_ram.mem[kk][1], uut.par2_ram.mem[kk][0]);
                endcase
            end
            $display("");
        end
    endtask

    task wait_for_state;
        input [3:0] target;
        integer guard;
        begin
            guard = 0;
            while (uut.state !== target && guard < OUT_TIMEOUT) begin
                @(posedge clk);
                guard = guard + 1;
            end
            if (guard >= OUT_TIMEOUT)
                $display("TIMEOUT: FSM never reached state %0d (stuck in %0d)",
                         target, uut.state);
        end
    endtask

    // Map the first wrong bit of the output stream to a section.
    // Stream layout (MSB first): SYS (2N bits: A,B per couple), Y1, W1, Y2, W2 (N bits each)
    task locate_first_bad;
        input integer       word_idx;
        input [31:0]        x;          // got ^ expected
        input integer       n;
        integer p, b, rem;
        begin
            p = 31;
            while (p > 0 && !x[p]) p = p - 1;
            b = word_idx * 32 + (31 - p);

            if (b < 2*n) begin
                if (b % 2) $display("    First bad bit %0d -> SYSTEMATIC couple %0d, bit B", b, b/2);
                else       $display("    First bad bit %0d -> SYSTEMATIC couple %0d, bit A", b, b/2);
            end else if (b < 4*n) begin
                rem = b - 2*n;
                if (rem < n) $display("    First bad bit %0d -> Y1, couple %0d", b, rem);
                else         $display("    First bad bit %0d -> W1, couple %0d", b, rem - n);
            end else if (b < 6*n) begin
                rem = b - 4*n;
                if (rem < n) $display("    First bad bit %0d -> Y2, couple %0d", b, rem);
                else         $display("    First bad bit %0d -> W2, couple %0d", b, rem - n);
            end else begin
                $display("    First bad bit %0d -> PADDING (beyond 6N = %0d bits)", b, 6*n);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Reference model (independent of the DUT's control logic)
    //--------------------------------------------------------------------------
    reg [1:0] m_cpl [0:4095];
    reg       m_a1  [0:4095];
    reg       m_b1  [0:4095];
    reg       m_a2  [0:4095];
    reg       m_b2  [0:4095];
    reg       m_y   [0:4095];
    reg       m_w   [0:4095];

    // bit 'bitidx' of the expected output stream (MSB of word 0 is bit 0)
    function exp_bit;
        input integer bitidx;
        reg [31:0] wd;
        begin
            wd = out_mem[bitidx / 32];
            exp_bit = wd[31 - (bitidx % 32)];
        end
    endfunction

    // run the constituent encoder for nsteps couples from start state s0
    task m_enc_run;
        input integer which;          // 1 = natural order, 2 = interleaved
        input [3:0]   s0;
        input integer nsteps;
        output [3:0]  sn;
        reg [3:0] s;
        reg       a, b, f;
        integer   jj;
        begin
            s = s0;
            for (jj = 0; jj < nsteps; jj = jj + 1) begin
                a = (which == 1) ? m_a1[jj] : m_a2[jj];
                b = (which == 1) ? m_b1[jj] : m_b2[jj];
                f = a ^ b ^ s[1] ^ s[0];
                m_y[jj] = f ^ b ^ s[3] ^ s[2] ^ s[0];
                m_w[jj] = f ^ b ^ s[2] ^ s[1] ^ s[0];
                s = {f, s[3:1]};
            end
            sn = s;
        end
    endtask

    // compare m_y / m_w against the expected file
    task m_count_err;
        input  integer yoff;          // bit offset of the Y stream; W follows at yoff+n
        input  integer n;
        output integer ey, ew;
        integer jj;
        begin
            ey = 0; ew = 0;
            for (jj = 0; jj < n; jj = jj + 1) begin
                if (m_y[jj] !== exp_bit(yoff + jj))     ey = ey + 1;
                if (m_w[jj] !== exp_bit(yoff + n + jj)) ew = ew + 1;
            end
        end
    endtask

    task ref_model_check;
        input integer n, p, q0, q1, q2, q3;
        integer    jj, addr, qj, sec, s0c, nfound, ey, ew;
        reg [3:0]  sn, tmp4, z_n, z_nm1, s_true, s_dut, f_dut;
        reg [31:0] wd;
        begin
            // couple j = in_mem[j/16] bits [2*(j%16)+1 : 2*(j%16)], A = MSB
            for (jj = 0; jj < n; jj = jj + 1) begin
                wd = in_mem[jj / 16];
                m_cpl[jj] = wd >> (2 * (jj % 16));
                m_a1[jj]  = m_cpl[jj][1];
                m_b1[jj]  = m_cpl[jj][0];
            end

            // ARP: pi(j) = (P*j + Q(j) + 3) mod N ; swap A/B for even j
            $write("    [MODEL] pi(0..7) for N=%0d P=%0d Q=%0d,%0d,%0d,%0d : ",
                   n, p, q0, q1, q2, q3);
            for (jj = 0; jj < n; jj = jj + 1) begin
                case (jj % 4)
                    0:       qj = 0;
                    1:       qj = 4 * q1;
                    2:       qj = 4 * q0 * p + 4 * q2;
                    default: qj = 4 * q0 * p + 4 * q3;
                endcase
                addr = (p * jj + qj + 3) % n;
                if (jj < 8) $write("%0d ", addr);
                if (jj % 2 == 0) begin
                    m_a2[jj] = m_cpl[addr][0];  m_b2[jj] = m_cpl[addr][1];
                end else begin
                    m_a2[jj] = m_cpl[addr][1];  m_b2[jj] = m_cpl[addr][0];
                end
            end
            $display("");

            for (sec = 1; sec <= 2; sec = sec + 1) begin
                m_enc_run(sec, 4'd0, n,     z_n);      // S_N   from state 0
                m_enc_run(sec, 4'd0, n - 1, z_nm1);    // S_N-1 from state 0

                // brute-force the true circulation state: S_N(s0) == s0
                nfound = 0; s_true = 4'd0;
                for (s0c = 0; s0c < 16; s0c = s0c + 1) begin
                    tmp4 = s0c;
                    m_enc_run(sec, tmp4, n, sn);
                    if (sn === tmp4) begin nfound = nfound + 1; s_true = tmp4; end
                end

                s_dut = (sec == 1) ? uut.s0_enc1      : uut.s0_enc2;
                f_dut = (sec == 1) ? uut.s_final_enc1 : uut.s_final_enc2;

                $display("    [MODEL enc%0d] S_N(0)=%b  S_N-1(0)=%b | DUT s_final=%b",
                         sec, z_n, z_nm1, f_dut);
                $display("    [MODEL enc%0d] true circ s0=%b (%0d found) | DUT s0=%b",
                         sec, s_true, nfound, s_dut);

                m_enc_run(sec, s_true, n, sn);
                m_count_err((sec == 1) ? 2 * n : 4 * n, n, ey, ew);
                $display("    [MODEL enc%0d] with TRUE s0: Y errors=%0d  W errors=%0d", sec, ey, ew);

                m_enc_run(sec, s_dut, n, sn);
                m_count_err((sec == 1) ? 2 * n : 4 * n, n, ey, ew);
                $display("    [MODEL enc%0d] with DUT  s0: Y errors=%0d  W errors=%0d", sec, ey, ew);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // One complete waveform test
    //--------------------------------------------------------------------------
    task run_waveform_test;
        input [5:0]         wf_id;
        input [11:0]        N;
        input [8*256-1:0]   in_file;
        input [8*256-1:0]   out_file;
        integer fd;
        begin
            $display("\n==================================================");
            $display("STARTING TEST FOR WAVEFORM ID: %0d (N = %0d)", wf_id, N);
            $display("==================================================");

            in_words  = (N + 15) / 16;
            out_words = (N * 6 + 31) / 32;

            for (i = 0; i < 2048; i = i + 1) begin
                in_mem[i]  = 32'h0;
                out_mem[i] = 32'h0;
                got_mem[i] = 32'h0;
            end

            fd = $fopen(in_file, "r");
            if (fd == 0) begin
                $display("FATAL: cannot open %0s", in_file);
                $finish;
            end
            $fclose(fd);

            fd = $fopen(out_file, "r");
            if (fd == 0) begin
                $display("FATAL: cannot open %0s", out_file);
                $finish;
            end
            $fclose(fd);

            $readmemh(in_file,  in_mem);
            $readmemh(out_file, out_mem);

            if (in_mem[0] == 32'h00000000 && in_mem[1] == 32'h00000000) begin
                $display("FATAL: input file %0s appears empty or malformed", in_file);
                $finish;
            end

`ifdef DEBUG_DUMP
            $display("[TB DEBUG] in_file  word 0..4 = ");
            for (k = 0; k < 5; k = k + 1) $display("    0x%08X", in_mem[k]);
            $display("[TB DEBUG] out_file word 0..4 = ");
            for (k = 0; k < 5; k = k + 1) $display("    0x%08X", out_mem[k]);
`endif

            // ---------------- reset ----------------
            mon_en = 0;
            rst_n  = 0;
            #50;
            rst_n  = 1;
            #30;

            got_cnt   = 0;
            tlast_cnt = 0;
            last_idx  = -1;
            mon_en    = 1;

            // ---------------- configuration ----------------
            @(posedge clk);
            cfg_waveform_id <= wf_id;
            cfg_valid       <= 1'b1;
            @(posedge clk);
            cfg_valid       <= 1'b0;
            @(posedge clk);

            // ---------------- push input ----------------
            i = 0;
            k = 0;
            while (i < in_words && k < IN_TIMEOUT) begin
                s_axis_tdata  <= in_mem[i];
                s_axis_tlast  <= (i == in_words - 1);
                s_axis_tvalid <= 1'b1;

                @(posedge clk);
                if (s_axis_tready) i = i + 1;
                k = k + 1;
            end
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;

            if (k >= IN_TIMEOUT) begin
                $display("TIMEOUT: DUT never accepted input word %0d", i);
                $finish;
            end

`ifdef DEBUG_DUMP
            wait_for_state(4'd2);
            $display("\n[DEBUG] After LOAD (sys_ram):");
            dump_bram_slice("sys_ram", 2'd0);
            $display("    active_N=%0d active_P=%0d", uut.active_N, uut.active_P);

            wait_for_state(4'd4);
            $display("\n[DEBUG] After ENCODE1 (par1_ram):");
            dump_bram_slice("par1_ram", 2'd1);
            $display("    s_final_enc1=%b s0_enc1=%b", uut.s_final_enc1, uut.s0_enc1);

            wait_for_state(4'd8);
            $display("\n[DEBUG] After ENCODE2 (par2_ram):");
            dump_bram_slice("par2_ram", 2'd2);
            $display("    s_final_enc2=%b s0_enc2=%b", uut.s_final_enc2, uut.s0_enc2);
`endif

            // ---------------- wait for end of frame (tlast) ----------------
            k = 0;
            while (tlast_cnt == 0 && k < OUT_TIMEOUT) begin
                @(posedge clk);
                k = k + 1;
            end
            if (k >= OUT_TIMEOUT)
                $display("TIMEOUT: no m_axis_tlast seen (got %0d words so far)", got_cnt);

            // let any unexpected extra beats show up
            repeat (50) @(posedge clk);
            mon_en = 0;

            // ---------------- compare ----------------
            match_cnt    = 0;
            mismatch_cnt = 0;
            frame_err    = 0;
            first_bad    = -1;
            print_cnt    = 0;

            for (i = 0; i < out_words; i = i + 1) begin
                if (i >= got_cnt) begin
                    mismatch_cnt = mismatch_cnt + 1;      // word never produced
                end else if (got_mem[i] === out_mem[i]) begin
                    match_cnt = match_cnt + 1;
                end else begin
                    if (print_cnt < MAX_PRINT)
                        $display("MISMATCH [Word %0d]: Expected = 0x%08X, Got = 0x%08X",
                                 i, out_mem[i], got_mem[i]);
                    print_cnt    = print_cnt + 1;
                    mismatch_cnt = mismatch_cnt + 1;
                    if (first_bad < 0) first_bad = i;
                end
            end
            if (print_cnt > MAX_PRINT)
                $display("... %0d further mismatches not printed", print_cnt - MAX_PRINT);

            if (first_bad >= 0)
                locate_first_bad(first_bad, got_mem[first_bad] ^ out_mem[first_bad], N);

`ifdef DEBUG_DUMP
            ref_model_check(uut.active_N, uut.active_P,
                            uut.active_Q0, uut.active_Q1, uut.active_Q2, uut.active_Q3);
`endif

            // ---------------- framing checks ----------------
            if (got_cnt != out_words) begin
                $display("FRAMING ERROR: expected %0d output words, got %0d", out_words, got_cnt);
                frame_err = frame_err + 1;
            end
            if (tlast_cnt != 1) begin
                $display("FRAMING ERROR: expected exactly 1 tlast, saw %0d", tlast_cnt);
                frame_err = frame_err + 1;
            end else if (last_idx != out_words - 1) begin
                $display("FRAMING ERROR: tlast on word %0d, expected word %0d",
                         last_idx, out_words - 1);
                frame_err = frame_err + 1;
            end

            $display("--------------------------------------------------");
            $display("WF%0d RESULT: %0d Matches, %0d Mismatches, %0d Framing errors",
                     wf_id, match_cnt, mismatch_cnt, frame_err);
            $display("--------------------------------------------------");

            if (mismatch_cnt > 0 || frame_err > 0) begin
                $display(">>> TEST FAILED FOR WF%0d <<<", wf_id);
                total_fail = total_fail + 1;
            end else begin
                $display(">>> TEST PASSED FOR WF%0d <<<", wf_id);
            end

            #200;
        end
    endtask

    //--------------------------------------------------------------------------
    // Main
    //--------------------------------------------------------------------------
    initial begin
        clk             = 0;
        rst_n           = 0;
        cfg_waveform_id = 0;
        cfg_valid       = 0;
        s_axis_tdata    = 0;
        s_axis_tvalid   = 0;
        s_axis_tlast    = 0;
        m_axis_tready   = 1'b1;
        mon_en          = 0;
        got_cnt         = 0;
        tlast_cnt       = 0;
        last_idx        = -1;
        total_fail      = 0;

        #100;

        run_waveform_test(
            6'd1,
            12'd152,
            "/home/ahammed/Documents/turbo_encdoer/input_wf1.txt",
            "/home/ahammed/Documents/turbo_encdoer/output_wf1.txt"
        );

        run_waveform_test(
            6'd13,
            12'd492,
            "/home/ahammed/Documents/turbo_encdoer/input_wf13.txt",
            "/home/ahammed/Documents/turbo_encdoer/output_wf13.txt"
        );

        $display("\n==================================================");
        if (total_fail == 0)
            $display("ALL TEST WAVEFORMS PASSED!");
        else
            $display("%0d TEST WAVEFORM(S) FAILED", total_fail);
        $display("==================================================\n");
        $finish;
    end

endmodule