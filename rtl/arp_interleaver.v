`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ahammed Salahuddeen N Y 
// 
// Create Date: 09/29/2026 09:56:12 AM
// Design Name: 
// Module Name: arp_interleaver
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


module arp_interleaver #(
    parameter ADDR_WIDTH = 11
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire enable,
    input wire [ADDR_WIDTH - 1: 0] N,
    input wire [ADDR_WIDTH - 1: 0] p,
    input wire [ADDR_WIDTH - 1: 0] Q0,
    input wire [ADDR_WIDTH - 1: 0] Q1,
    input wire [ADDR_WIDTH - 1: 0] Q2,
    input wire [ADDR_WIDTH - 1: 0] Q3,
    output wire [ADDR_WIDTH - 1:0] int_addr,
    output wire swap_bits,
    output wire valid,
    output wire done
    );
    
    reg [ADDR_WIDTH -1: 0] j_reg;
    reg active_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            active_reg <= 0;
            j_reg <= 0;
        end
        else if (start) begin
            active_reg <= 1'b1;
            j_reg <= {ADDR_WIDTH{1'b0}};
        end
        else if (active_reg && enable) begin
            if (j_reg == N - 1'b1)begin
                active_reg <= 1'b0;
            end
            else begin
                j_reg <= j_reg + 1'b1;
            end
        end
    end
    
    assign valid = active_reg;
    assign done = active_reg && enable && (j_reg == N - 1'b1);
    
    
    assign swap_bits = (j_reg[0] == 1'b0);
    reg [ADDR_WIDTH - 1: 0] d_j;
    
    always @(*) begin
        case (j_reg[1:0])
            2'b00: d_j = {ADDR_WIDTH{1'b0}};
            2'b01: d_j = Q1;
            2'b10: d_j = Q2;
            2'b11: d_j = Q3;
            default: d_j = {ADDR_WIDTH{1'b0}};
        endcase
    end
    
    wire [(2* ADDR_WIDTH) - 1: 0] full_sum;
    assign full_sum = (p * j_reg) + Q0 + d_j;
    assign int_addr = full_sum % N;
endmodule
