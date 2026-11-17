`timescale 1ns / 1ps

module tb_arp_interleaver;

    //--------------------------------------------------------------------------
    // Clock and reset
    //--------------------------------------------------------------------------
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;

    //--------------------------------------------------------------------------
    // Profile ROM (waveform id driven by the test)
    //--------------------------------------------------------------------------
    reg  [5:0]  wf_id = 6'd0;
    wire [11:0] rom_N, rom_P, rom_Np1, rom_Np2;
    wire [3:0]  rom_R15;
    wire [11:0] rom_qt0, rom_qt1, rom_qt2, rom_qt3;

    profile_lookup_rom rom_inst (
        .waveform_id(wf_id),
        .cfg_N(rom_N), .cfg_P(rom_P), .cfg_Np1(rom_Np1), .cfg_Np2(rom_Np2),
        .cfg_R15(rom_R15),
        .cfg_qt0(rom_qt0), .cfg_qt1(rom_qt1), .cfg_qt2(rom_qt2), .cfg_qt3(rom_qt3)
    );

    //--------------------------------------------------------------------------
    // ARP under test
    //--------------------------------------------------------------------------
    reg         start = 1'b0;
    reg         step  = 1'b0;
    wire [11:0] int_addr;
    wire        swap_bits;

    arp_interleaver dut (
        .clk(clk), .rst_n(rst_n), .start(start), .step(step),
        .cfg_N(rom_N), .cfg_P(rom_P),
        .cfg_qt0(rom_qt0), .cfg_qt1(rom_qt1), .cfg_qt2(rom_qt2), .cfg_qt3(rom_qt3),
        .int_addr(int_addr), .swap_bits(swap_bits)
    );

    //--------------------------------------------------------------------------
    // Bookkeeping
    //--------------------------------------------------------------------------
    reg     seen [0:2395];
    integer total_fail = 0;
    integer wf_pass    = 0;
    integer wf_run     = 0;

    //--------------------------------------------------------------------------
    // Check one waveform. Raw parameters come from the MATLAB definition.
    //--------------------------------------------------------------------------
    task check_wf;
        input [5:0]  id;
        input [31:0] N;
        input [31:0] P;
        input [31:0] Q0;
        input [31:0] Q1;
        input [31:0] Q2;
        input [31:0] Q3;

        integer j, qj, ref_addr;
        integer rom_err, arp_err, swap_err, dup_err, errs;
        integer e_qt0, e_qt1, e_qt2, e_qt3;
        begin
            wf_run = wf_run + 1;

            //--- ROM check against formulas from raw parameters -------------
            wf_id = id;
            #1;
            e_qt0 = 3 % N;
            e_qt1 = (4*Q1 + 3) % N;
            e_qt2 = (4*Q0*P + 4*Q2 + 3) % N;
            e_qt3 = (4*Q0*P + 4*Q3 + 3) % N;

            rom_err = 0;
            if (rom_N   !== N)       rom_err = rom_err + 1;
            if (rom_P   !== P)       rom_err = rom_err + 1;
            if (rom_Np1 !== N + 1)   rom_err = rom_err + 1;
            if (rom_Np2 !== N + 2)   rom_err = rom_err + 1;
            if (rom_R15 !== N % 15)  rom_err = rom_err + 1;
            if (rom_qt0 !== e_qt0)   rom_err = rom_err + 1;
            if (rom_qt1 !== e_qt1)   rom_err = rom_err + 1;
            if (rom_qt2 !== e_qt2)   rom_err = rom_err + 1;
            if (rom_qt3 !== e_qt3)   rom_err = rom_err + 1;

            //--- Clear permutation tracker ----------------------------------
            for (j = 0; j < 2396; j = j + 1) seen[j] = 1'b0;
            arp_err  = 0;
            swap_err = 0;
            dup_err  = 0;

            //--- Start (j = 0), then one step per couple --------------------
            start = 1'b1; @(posedge clk); #1; start = 1'b0;

            for (j = 0; j < N; j = j + 1) begin
                #1;   // int_addr and swap_bits are combinational from j_reg = j

                case (j % 4)
                    0: qj = 0;
                    1: qj = 4*Q1;
                    2: qj = 4*Q0*P + 4*Q2;
                    default: qj = 4*Q0*P + 4*Q3;
                endcase
                ref_addr = (P*j + qj + 3) % N;

                if (int_addr !== ref_addr) arp_err = arp_err + 1;
                if (swap_bits !== ((j % 2) == 0)) swap_err = swap_err + 1;
                if (seen[int_addr] === 1'b1) dup_err = dup_err + 1;
                seen[int_addr] = 1'b1;

                step = 1'b1; @(posedge clk); #1; step = 1'b0;
            end

            errs = rom_err + arp_err + swap_err + dup_err;
            if (errs == 0) wf_pass = wf_pass + 1;
            total_fail = total_fail + errs;

            $display("WF%0d N=%0d P=%0d : ROM err=%0d  ARP addr err=%0d  swap err=%0d  duplicates=%0d  -> %s",
                     id, N, P, rom_err, arp_err, swap_err, dup_err,
                     (errs == 0) ? "PASS" : "FAIL");
        end
    endtask

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------
    initial begin
        rst_n = 1'b0;
        #20 rst_n = 1'b1;
        #10;

        // id  N     P    Q0  Q1  Q2  Q3
        check_wf(6'd0,   48,   13,   0,  2,  4,  6);   // legacy / debug
        check_wf(6'd1,   152,  17,   9,  5, 14,  1);   // WF1
        check_wf(6'd2,   56,    9,   2,  2,  8,  0);   // WF2
        check_wf(6'd13,  492,  31,   0,  3,  1,  0);   // WF13
        check_wf(6'd22,  2396, 81,   1,  2,  5,  2);   // WF22 (largest N)
        check_wf(6'd44,  204,  23,  10,  5,  0,  0);   // WF44
        check_wf(6'd49,  372,  25,   1,  7,  2,  1);   // WF49

        $display("------------------------------------------------------------");
        if (total_fail == 0)
            $display("ARP TEST PASSED: %0d / %0d waveforms", wf_pass, wf_run);
        else
            $display("ARP TEST FAILED: %0d / %0d waveforms passed, %0d total errors",
                     wf_pass, wf_run, total_fail);
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule