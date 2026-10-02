`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ahammed Salahuddeen N Y
// 
// Create Date: 09/28/2026 06:52:45 PM
// Design Name: 
// Module Name: ram_sdp
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
module ram_sdp #(
    parameter DATA_WIDTH = 2 ,
    parameter ADDR_WIDTH = 11 
)(
    input wire clk,
    input wire we,
    input wire [ADDR_WIDTH -1: 0] waddr,
    input wire [DATA_WIDTH -1: 0] din,
    input wire [ADDR_WIDTH - 1: 0] raddr,
    output reg [DATA_WIDTH -1: 0] dout
    );
    
    reg [DATA_WIDTH -1: 0] mem [(2**ADDR_WIDTH)- 1: 0];
    
    always @(posedge clk) begin
        if (we) begin
            mem[waddr] <= din;
        end
            dout <= mem[raddr];        
    end
endmodule
