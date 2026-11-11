`timescale 1ns / 1ps

module tb_circular_state_rom;

    reg  [3:0] r;
    reg  [3:0] last_state;
    wire [3:0] circ_state;

    integer r_index;
    integer state_index;
    integer error_count;
    integer check_count;

    reg [63:0] expected_row;
    reg [3:0]  expected_state;

    circular_state_rom dut (
        .r          (r),
        .last_state (last_state),
        .circ_state (circ_state)
    );

    // Golden table copied from the specified lookup values.
    // Default (including r=0 and r=15) is zero, matching the current RTL.
    function [63:0] golden_row;
        input [3:0] row_index;
        begin
            case (row_index)
                4'd1:  golden_row = 64'h5b68_2c1f_a497_d3e0;
                4'd2:  golden_row = 64'h924f_38e5_c71a_6db0;
                4'd3:  golden_row = 64'h7fe6_5dc4_3ba2_1980;
                4'd4:  golden_row = 64'heda9_6521_fcb8_7430;
                4'd5:  golden_row = 64'h481d_f3a6_2eb7_95c0;
                4'd6:  golden_row = 64'h37fb_ae62_15d9_8c40;
                4'd7:  golden_row = 64'h248e_71db_9f35_ca60;
                4'd8:  golden_row = 64'hda52_cb43_e961_f870;
                4'd9:  golden_row = 64'hc927_14fa_638d_be50;
                4'd10: golden_row = 64'hb6c1_493e_582f_a7d0;
                4'd11: golden_row = 64'h1375_dfb9_8aec_4620;
                4'd12: golden_row = 64'h813a_e75c_4df6_2b90;
                4'd13: golden_row = 64'h6c93_827d_b14e_5fa0;
                4'd14: golden_row = 64'ha5b4_9687_d2c3_e1f0;
                default: golden_row = 64'd0;
            endcase
        end
    endfunction

    initial begin
        r             = 4'd0;
        last_state    = 4'd0;
        error_count   = 0;
        check_count   = 0;
        expected_row  = 64'd0;
        expected_state = 4'd0;

        // Exercise every row and every last_state value.
        for (r_index = 0; r_index < 16; r_index = r_index + 1) begin
            for (state_index = 0; state_index < 16; state_index = state_index + 1) begin
                r          = r_index;
                last_state = state_index;
                expected_row = golden_row(r_index);

                // Allow the combinational DUT output to settle.
                #1;

                // The RTL selects nibble (last_state * 4), starting at the LSB.
                expected_state = expected_row >> (state_index * 4);
                check_count = check_count + 1;

                if (circ_state !== expected_state) begin
                    error_count = error_count + 1;
                    if (error_count <= 20) begin
                        $display("[ERROR] r=%0d last_state=%0d: expected %h, got %h",
                                 r_index, state_index, expected_state, circ_state);
                    end
                end
            end
        end

        if (error_count == 0)
            $display("[PASS] circular_state_rom: all %0d combinations passed.",
                     check_count);
        else begin
            $display("[FAIL] circular_state_rom: %0d errors in %0d checks.",
                     error_count, check_count);
            if (error_count > 20)
                $display("       Only the first 20 errors were displayed.");
        end

        $finish;
    end

endmodule