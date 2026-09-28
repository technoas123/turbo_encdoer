`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ahammed salahudeen N Y 
// 
// Create Date: 09/28/2026 01:26:06 PM
// Design Name: 
// Module Name: circular_state_rom
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module circular_state_rom(
    input wire [3:0] r,
    input wire [3:0] last_state,
    output reg [3:0] circ_state
    );
    
    reg [63:0] raw_data;
    
    always @(*) begin
        case (r)
            4'd1:  raw_data = 64'h5b68_2c1f_a497_d3e0;
            4'd2:  raw_data = 64'h924f_38e5_c71a_6db0;
            4'd3:  raw_data = 64'h7fe6_5dc4_3ba2_1980;
            4'd4:  raw_data = 64'heda9_6521_fcb8_7430;
            4'd5:  raw_data = 64'h481d_f3a6_2eb7_95c0;
            4'd6:  raw_data = 64'h37fb_ae62_15d9_8c40;
            4'd7:  raw_data = 64'h248e_71db_9f35_ca60;
            4'd8:  raw_data = 64'hda52_cb43_e961_f870;
            4'd9:  raw_data = 64'hc927_14fa_638d_be50;
            4'd10: raw_data = 64'hb6c1_493e_582f_a7d0;
            4'd11: raw_data = 64'h1375_dfb9_8aec_4620;
            4'd12: raw_data = 64'h813a_e75c_4df6_2b90;
            4'd13: raw_data = 64'h6c93_827d_b14e_5fa0;
            4'd14: raw_data = 64'ha5b4_9687_d2c3_e1f0;
            default: raw_data = 64'd0;
        endcase      
        circ_state = raw_data[last_state * 4 +: 4]; 
    end
endmodule