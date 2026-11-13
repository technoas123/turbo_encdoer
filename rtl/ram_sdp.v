module ram_sdp #(
    parameter DATA_WIDTH = 2,
    parameter ADDR_WIDTH = 12
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] din,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output reg  [DATA_WIDTH-1:0] dout
);
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH)-1:0];

    always @(posedge clk) begin
        if (we) mem[waddr] <= din;
        dout <= mem[raddr];      // synchronous read: BRAM-compatible
    end
endmodule