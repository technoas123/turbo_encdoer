`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ahammed Salahuddeen N Y
// 
// Create Date: 09/28/2026 12:33:15 PM
// Design Name: 
// Module Name: constituent_encoder
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


module constituent_encoder(
    input wire clk,
    input wire rst_n,
    input wire load_init,
    input wire [3:0] init_state,
    input wire enable,
    input wire a,
    input wire b,
    output wire y,
    output wire w,
    output wire [3:0] state_out
    );
    
    reg [3:0] state_reg;
    wire f; 
    
    assign state_out = state_reg;
    assign f = a ^ b ^ state_reg[1] ^ state_reg[0];
    assign y = f ^ b ^ state_reg[3] ^ state_reg[2] ^ state_reg[0];
    assign w = f ^ b ^ state_reg[2] ^ state_reg[1] ^ state_reg[0];
    
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= 4'b0000;
        end
        else if (load_init) begin
            state_reg <= init_state; 
        end
        else if (enable) begin
            state_reg <= {f,state_reg[3:1]};
        end
    end    
endmodule