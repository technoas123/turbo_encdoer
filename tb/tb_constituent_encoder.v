`timescale 1ns / 1ps

module tb_constituent_encoder;

    reg clk;
    reg rst_n;
    reg load_init;
    reg enable;
    reg a;
    reg b;
    reg [3:0] init_state;

    wire y;
    wire w;
    wire [3:0] state_out;

    integer errors;

    constituent_encoder dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .load_init  (load_init),
        .enable     (enable),
        .a          (a),
        .b          (b),
        .init_state (init_state),
        .y          (y),
        .w          (w),
        .state_out  (state_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_state;
        input [3:0] expected;
        begin
            if (state_out !== expected) begin
                $display("[ERROR] t=%0t state: expected %0d, got %0d",
                         $time, expected, state_out);
                errors = errors + 1;
            end
        end
    endtask

    task check_outputs;
        input expected_y;
        input expected_w;
        begin
            if ((y !== expected_y) || (w !== expected_w)) begin
                $display("[ERROR] t=%0t outputs: expected y/w=%b%b, got %b%b",
                         $time, expected_y, expected_w, y, w);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors     = 0;
        rst_n      = 1'b0;
        load_init  = 1'b0;
        enable     = 1'b0;
        a          = 1'b0;
        b          = 1'b0;
        init_state = 4'd0;

        // Synchronous reset: check after reset has been sampled on rising edges.
        repeat (2) @(posedge clk);
        #1;
        check_state(4'd0);

        // Load initial state 5.
        @(negedge clk);
        rst_n      = 1'b1;
        load_init  = 1'b1;
        init_state = 4'd5;
        a          = 1'b0;
        b          = 1'b0;

        @(posedge clk);
        #1;
        check_state(4'd5);
        check_outputs(1'b1, 1'b1);

        // With enable low, state should hold.
        @(negedge clk);
        load_init = 1'b0;

        @(posedge clk);
        #1;
        check_state(4'd5);

        // Reset state to zero.
        @(negedge clk);
        rst_n  = 1'b0;
        enable = 1'b0;

        @(posedge clk);
        #1;
        check_state(4'd0);

        // Couple (a,b)=(1,0): state 0 -> state 8.
        @(negedge clk);
        rst_n  = 1'b1;
        enable = 1'b1;
        a      = 1'b1;
        b      = 1'b0;

        @(posedge clk);
        #1;
        check_state(4'd8);
        check_outputs(1'b0, 1'b1);

        // Couple (a,b)=(0,1): state 8 -> state 12.
        @(negedge clk);
        a = 1'b0;
        b = 1'b1;

        @(posedge clk);
        #1;
        check_state(4'd12);
        check_outputs(1'b0, 1'b1);

        // Check that disabling the encoder holds the state.
        @(negedge clk);
        enable = 1'b0;

        @(posedge clk);
        #1;
        check_state(4'd12);

        if (errors == 0)
            $display("[PASS] constituent_encoder checks passed.");
        else
            $display("[FAIL] constituent_encoder: %0d error(s).", errors);

        $finish;
    end

endmodule