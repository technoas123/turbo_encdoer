`timescale 1ns / 1ps

module tb_circular_state_rom;

    reg  [3:0] r;
    reg  [3:0] last_state;
    wire [3:0] circ_state;

    // Instantiate Unit Under Test (UUT)
    circular_state_rom uut (
        .r          (r),
        .last_state (last_state),
        .circ_state (circ_state)
    );

    initial begin
        $display("=== Starting Circular State ROM Test ===");

        // Test 1: Row 1, Column 0
        r = 4'd1; last_state = 4'd0;
        #5;
        $display("r=%0d | last_state=%0d | circ_state=%0d (Expected: 0)", r, last_state, circ_state);

        // Test 2: Row 1, Column 1
        r = 4'd1; last_state = 4'd1;
        #5;
        $display("r=%0d | last_state=%0d | circ_state=%0d (Expected: 14)", r, last_state, circ_state);

        // Test 3: Row 1, Column 15
        r = 4'd1; last_state = 4'd15;
        #5;
        $display("r=%0d | last_state=%0d | circ_state=%0d (Expected: 5)", r, last_state, circ_state);

        // Test 4: Row 11, Column 7 (checks Row 11 fix)
        r = 4'd11; last_state = 4'd7;
        #5;
        $display("r=%0d | last_state=%0d | circ_state=%0d (Expected: 8)", r, last_state, circ_state);

        // Test 5: Row 11, Column 8
        r = 4'd11; last_state = 4'd8;
        #5;
        $display("r=%0d | last_state=%0d | circ_state=%0d (Expected: 9)", r, last_state, circ_state);

        // Test 6: Row 14, Column 15
        r = 4'd14; last_state = 4'd15;
        #5;
        $display("r=%0d | last_state=%0d | circ_state=%0d (Expected: 10)", r, last_state, circ_state);

        $display("=== Test Completed ===");
        $finish;
    end

endmodule