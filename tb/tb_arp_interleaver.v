`timescale 1ns / 1ps

module tb_arp_interleaver;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         step;
    reg  [5:0]  waveform_id;

    wire [11:0] cfg_N;
    wire [11:0] cfg_P_rom;
    wire [11:0] cfg_Q0;
    wire [11:0] cfg_Q1;
    wire [11:0] cfg_Q2;
    wire [11:0] cfg_Q3;

    wire [11:0] int_addr;
    wire        swap_bits;

    integer total_errors;

    // The ARP module currently accepts an 11-bit P.
    // Explicitly narrow the ROM value so the test can detect if P[11] is set.
    wire [10:0] cfg_P_to_dut;
    assign cfg_P_to_dut = cfg_P_rom[10:0];

    // Use the actual profile values from your ROM.
    profile_lookup_rom u_profile_lookup_rom (
        .waveform_id (waveform_id),
        .cfg_N       (cfg_N),
        .cfg_P       (cfg_P_rom),
        .cfg_Q0      (cfg_Q0),
        .cfg_Q1      (cfg_Q1),
        .cfg_Q2      (cfg_Q2),
        .cfg_Q3      (cfg_Q3)
    );

    arp_interleaver dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .step       (step),
        .cfg_N      (cfg_N),
        .cfg_P      (cfg_P_to_dut),
        .cfg_Q0     (cfg_Q0),
        .cfg_Q1     (cfg_Q1),
        .cfg_Q2     (cfg_Q2),
        .cfg_Q3     (cfg_Q3),
        .int_addr   (int_addr),
        .swap_bits  (swap_bits)
    );

    // 100 MHz test clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Check every j for one waveform profile.
    task run_profile;
        input [5:0] wf_id;
        input integer required_n;

        integer n_val;
        integer p_val;
        integer q0_val;
        integer q1_val;
        integer q2_val;
        integer q3_val;

        integer j;
        integer q_term;
        integer expected_addr;
        integer local_errors;
        reg [11:0] required_n_bits;

        begin
            waveform_id = wf_id;
            #1; // allow the combinational profile ROM to settle

            local_errors   = 0;
            required_n_bits = required_n;

            if ((^cfg_N) === 1'bx ||
                (^cfg_P_rom) === 1'bx ||
                (^cfg_Q0) === 1'bx ||
                (^cfg_Q1) === 1'bx ||
                (^cfg_Q2) === 1'bx ||
                (^cfg_Q3) === 1'bx) begin

                $display("[FAIL] WF%0d: profile ROM returned X/Z parameter(s).",
                         wf_id);
                local_errors = local_errors + 1;
                total_errors = total_errors + 1;

            end else begin
                n_val  = cfg_N;
                p_val  = cfg_P_rom;
                q0_val = cfg_Q0;
                q1_val = cfg_Q1;
                q2_val = cfg_Q2;
                q3_val = cfg_Q3;

                $display("");
                $display("[ARP] WF%0d: N=%0d P=%0d Q0=%0d Q1=%0d Q2=%0d Q3=%0d",
                         wf_id, n_val, p_val, q0_val, q1_val, q2_val, q3_val);

                if (cfg_N !== required_n_bits) begin
                    $display("[ERROR] WF%0d: expected N=%0d from the test, ROM returned N=%0d",
                             wf_id, required_n, n_val);
                    local_errors = local_errors + 1;
                    total_errors = total_errors + 1;
                end

                // The RTL port is [10:0]. Report if this profile needs bit 11.
                if (cfg_P_rom[11] === 1'b1) begin
                    $display("[ERROR] WF%0d: P=%0d needs 12 bits, but arp_interleaver.cfg_P is only 11 bits.",
                             wf_id, p_val);
                    local_errors = local_errors + 1;
                    total_errors = total_errors + 1;
                end

                if (p_val >= n_val) begin
                    $display("[ERROR] WF%0d: invalid profile for this recurrence: P=%0d is not less than N=%0d",
                             wf_id, p_val, n_val);
                    local_errors = local_errors + 1;
                    total_errors = total_errors + 1;
                end

                if (n_val > 0) begin
                    // start establishes j=0; check each address before stepping.
                    @(negedge clk);
                    start = 1'b1;

                    @(posedge clk);
                    #1;
                    start = 1'b0;

                    for (j = 0; j < n_val; j = j + 1) begin

                        // Independent reference for Q(j), using integer arithmetic
                        // in the testbench (not synthesized hardware).
                        case (j % 4)
                            0: q_term = 0;
                            1: q_term = 4 * q1_val;
                            2: q_term = (4 * q0_val * p_val) + (4 * q2_val);
                            3: q_term = (4 * q0_val * p_val) + (4 * q3_val);
                            default: q_term = 0;
                        endcase

                        expected_addr = (p_val * j + q_term + 3) % n_val;

                        if (int_addr !== expected_addr[11:0]) begin
                            if (local_errors < 10)
                                $display("[ERROR] WF%0d j=%0d: address expected %0d, got %0d",
                                         wf_id, j, expected_addr, int_addr);
                            local_errors = local_errors + 1;
                            total_errors = total_errors + 1;
                        end

                        if (swap_bits !== ((j % 2) == 0)) begin
                            if (local_errors < 10)
                                $display("[ERROR] WF%0d j=%0d: swap expected %0d, got %0d",
                                         wf_id, j, ((j % 2) == 0), swap_bits);
                            local_errors = local_errors + 1;
                            total_errors = total_errors + 1;
                        end

                        // Advance the interleaver to the next j.
                        if (j < n_val - 1) begin
                            @(negedge clk);
                            step = 1'b1;

                            @(posedge clk);
                            #1;
                            step = 1'b0;
                        end
                    end
                end else begin
                    $display("[ERROR] WF%0d: N is zero; cannot test addresses.", wf_id);
                    local_errors = local_errors + 1;
                    total_errors = total_errors + 1;
                end
            end

            if (local_errors == 0)
                $display("[PASS] WF%0d: checked all %0d addresses and swap bits.",
                         wf_id, required_n);
            else
                $display("[FAIL] WF%0d: %0d error(s).", wf_id, local_errors);
        end
    endtask

    initial begin
        rst_n        = 1'b0;
        start        = 1'b0;
        step         = 1'b0;
        waveform_id  = 6'd0;
        total_errors = 0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        run_profile(6'd2,  56);
        run_profile(6'd22, 2396);

        $display("");
        if (total_errors == 0)
            $display(">>> ARP INTERLEAVER TEST PASSED <<<");
        else
            $display(">>> ARP INTERLEAVER TEST FAILED: %0d total error(s) <<<",
                     total_errors);

        $finish;
    end

endmodule