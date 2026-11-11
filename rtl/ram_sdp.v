`timescale 1ns / 1ps

module ram_sdp #(
    parameter DATA_WIDTH = 2,
    parameter ADDR_WIDTH = 12
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] din,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire [DATA_WIDTH-1:0] dout_comb
);

    (* ram_style = "distributed" *)
    reg [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH)-1:0];

    always @(posedge clk) if (we) mem[waddr] <= din;
    always @(posedge clk)         dout <= mem[raddr];

    assign dout_comb = mem[raddr];

endmodule