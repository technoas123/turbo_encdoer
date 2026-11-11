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

    reg [31:0] in_mem  [0:2047];
    reg [31:0] out_mem [0:2047];

    integer i, k;
    integer match_cnt, mismatch_cnt;
    integer in_words, out_words;

    task dump_bram_slice;
        input [255:0]     name;
        input [1:0]       dut_mem_sel;
        integer k;
        begin
            $write("    %0s[0..11] = ", name);
            for (k = 0; k < 12; k = k + 1) begin
                case (dut_mem_sel)
                    2'd0: $write("%b%b ", uut.sys_ram.mem[k][1], uut.sys_ram.mem[k][0]);
                    2'd1: $write("%b%b ", uut.par1_ram.mem[k][1], uut.par1_ram.mem[k][0]);
                    2'd2: $write("%b%b ", uut.par2_ram.mem[k][1], uut.par2_ram.mem[k][0]);
                endcase
            end
            $display("");
        end
    endtask

    task wait_for_state;
        input [3:0] target;
        begin
            while (uut.state !== target) @(posedge clk);
        end
    endtask

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
            for (k=0; k<5; k=k+1) $display("    0x%08X", in_mem[k]);
            $display("[TB DEBUG] out_file word 0..4 = ");
            for (k=0; k<5; k=k+1) $display("    0x%08X", out_mem[k]);
`endif

            rst_n = 0;
            #50;
            rst_n = 1;
            #30;

            @(posedge clk);
            cfg_waveform_id <= wf_id;
            cfg_valid       <= 1'b1;
            @(posedge clk);
            cfg_valid       <= 1'b0;
            @(posedge clk);

            i = 0;
            while (i < in_words) begin
                s_axis_tdata  <= in_mem[i];
                s_axis_tlast  <= (i == in_words - 1);
                s_axis_tvalid <= 1'b1;

                @(posedge clk);
                if (s_axis_tready) begin
                    i = i + 1;
                end
            end
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;

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

            match_cnt    = 0;
            mismatch_cnt = 0;

            for (i = 0; i < out_words; i = i + 1) begin
                // Watchdog timer to prevent infinite loops
                k = 0;
                while (!m_axis_tvalid && k < 10000) begin
                    @(posedge clk);
                    k = k + 1;
                end
                
                if (k >= 10000) begin
                    $display("TIMEOUT: no m_axis_tvalid at word %0d", i);
                    mismatch_cnt = mismatch_cnt + (out_words - i);
                    i = out_words;
                end else begin
                    if (m_axis_tdata === out_mem[i]) begin
                        match_cnt = match_cnt + 1;
                    end else begin
                        $display("MISMATCH [Word %0d]: Expected = 0x%08X, Got = 0x%08X",
                                 i, out_mem[i], m_axis_tdata);
                        mismatch_cnt = mismatch_cnt + 1;
                    end
                    @(posedge clk);
                end
            end

            $display("--------------------------------------------------");
            $display("WF%0d RESULT: %0d Matches, %0d Mismatches", wf_id, match_cnt, mismatch_cnt);
            $display("--------------------------------------------------");

            if (mismatch_cnt > 0) begin
                $display(">>> TEST FAILED FOR WF%0d <<<", wf_id);
            end else begin
                $display(">>> TEST PASSED FOR WF%0d <<<", wf_id);
            end
            
            #200;
        end
    endtask

    initial begin
        clk             = 0;
        rst_n           = 0;
        cfg_waveform_id = 0;
        cfg_valid       = 0;
        s_axis_tdata    = 0;
        s_axis_tvalid   = 0;
        s_axis_tlast    = 0;
        m_axis_tready   = 1'b1;

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
        $display("ALL TEST WAVEFORMS COMPLETED!");
        $display("==================================================\n");
        $finish;
    end

endmodule