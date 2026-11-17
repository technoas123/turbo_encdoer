`timescale 1ns / 1ps
//============================================================================
// puncturer_ctrl.v
//
// DVB-RCS2 Turbo Code Puncturer Control
// ETSI EN 301 545-2 V1.5.1, Table A-1
//
// Generates a keep/drop decision for each parity bit based on the
// configured code rate, the current parity stream, and the couple index.
//
// Systematic bits (stream_id == 0) are NEVER punctured.
// The same Y/W pattern applies to both encoders (Y1=Y2, W1=W2).
//
// Rate encoding (rate_code):
//   3'd0 = 1/3    3'd1 = 1/2    3'd2 = 2/3    3'd3 = 3/4
//   3'd4 = 4/5    3'd5 = 5/6    3'd6 = 6/7    3'd7 = 7/8
//
// Stream encoding (stream_id):
//   3'd0 = systematic (always keep)
//   3'd1 = Y1    3'd2 = W1    3'd3 = Y2    3'd4 = W2
//
// Pattern convention:
//   keep = pattern[ addr mod period ]
//   pattern[0] corresponds to addr == 0, period, 2*period, ...
//   ETSI "10" (period 2) => pattern[0]=1, pattern[1]=0
//============================================================================

module puncturer_ctrl (
    input  wire [2:0]  rate_code,
    input  wire [2:0]  stream_id,
    input  wire [11:0] addr,
    output wire        keep
);

    //------------------------------------------------------------------------
    // Systematic bypass
    //------------------------------------------------------------------------
    wire is_sys = (stream_id == 3'd0);

    //------------------------------------------------------------------------
    // Determine if this stream uses the Y pattern or the W pattern
    //   Y streams: Y1 (1), Y2 (3)
    //   W streams: W1 (2), W2 (4)
    //------------------------------------------------------------------------
    wire is_y_stream = (stream_id == 3'd1) || (stream_id == 3'd3);
    wire is_w_stream = (stream_id == 3'd2) || (stream_id == 3'd4);

    //------------------------------------------------------------------------
    // Per-rate period and pattern lookup
    //
    // ETSI Table A-1 puncturing patterns (same for both encoders):
    //
    // Rate  Y_Per  Y_Pattern                     W_Per  W_Pattern
    // 1/3   1      1                              1      1
    // 1/2   1      1                              1      0
    // 2/3   2      10                             1      0
    // 3/4   6      101000                         1      0
    // 4/5   4      1000                           1      0
    // 5/6   20     10001000100010000000           1      0
    // 6/7   12     100010000000                   1      0
    // 7/8   28     1000100000001000000010000000   1      0
    //
    // Pattern bit mapping: ETSI string "101000" (MSB first) maps to
    //   pattern[0]=1, pattern[1]=0, pattern[2]=1, pattern[3..5]=0
    //   => 32'h0000_0005
    //------------------------------------------------------------------------
    reg [4:0]  y_period;
    reg [31:0] y_pattern;
    reg [4:0]  w_period;
    reg [31:0] w_pattern;

    always @(*) begin
        // Defaults: keep everything (rate 1/3)
        y_period  = 5'd1;
        y_pattern = 32'h0000_0001;
        w_period  = 5'd1;
        w_pattern = 32'h0000_0001;

        case (rate_code)
            //----------------------------------------------------------
            // Rate 1/3: no puncturing
            // Y: period=1, "1"    W: period=1, "1"
            //----------------------------------------------------------
            3'd0: begin
                y_period  = 5'd1;  y_pattern = 32'h0000_0001;
                w_period  = 5'd1;  w_pattern = 32'h0000_0001;
            end

            //----------------------------------------------------------
            // Rate 1/2: keep all Y, drop all W
            // Y: period=1, "1"    W: period=1, "0"
            //----------------------------------------------------------
            3'd1: begin
                y_period  = 5'd1;  y_pattern = 32'h0000_0001;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            //----------------------------------------------------------
            // Rate 2/3: keep half Y, drop all W
            // Y: period=2, "10"   W: period=1, "0"
            //   "10" => pattern[0]=1, pattern[1]=0 => 0x01
            //----------------------------------------------------------
            3'd2: begin
                y_period  = 5'd2;  y_pattern = 32'h0000_0001;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            //----------------------------------------------------------
            // Rate 3/4: keep 2/6 Y, drop all W
            // Y: period=6, "101000"  W: period=1, "0"
            //   "101000" => pattern[0]=1,[1]=0,[2]=1,[3]=0,[4]=0,[5]=0
            //   => 0x05
            //----------------------------------------------------------
            3'd3: begin
                y_period  = 5'd6;  y_pattern = 32'h0000_0005;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            //----------------------------------------------------------
            // Rate 4/5: keep 1/4 Y, drop all W
            // Y: period=4, "1000"  W: period=1, "0"
            //   "1000" => pattern[0]=1,[1..3]=0 => 0x01
            //----------------------------------------------------------
            3'd4: begin
                y_period  = 5'd4;  y_pattern = 32'h0000_0001;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            //----------------------------------------------------------
            // Rate 5/6: keep 4/20 Y, drop all W
            // Y: period=20, "10001000100010000000"  W: period=1, "0"
            //   pattern[0]=1,[4]=1,[8]=1,[12]=1, rest=0
            //   => 0x1111
            //----------------------------------------------------------
            3'd5: begin
                y_period  = 5'd20; y_pattern = 32'h0000_1111;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            //----------------------------------------------------------
            // Rate 6/7: keep 2/12 Y, drop all W
            // Y: period=12, "100010000000"  W: period=1, "0"
            //   pattern[0]=1,[4]=1, rest=0 => 0x11
            //----------------------------------------------------------
            3'd6: begin
                y_period  = 5'd12; y_pattern = 32'h0000_0011;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            //----------------------------------------------------------
            // Rate 7/8: keep 4/28 Y, drop all W
            // Y: period=28, "1000100000001000000010000000"  W: period=1, "0"
            //   pattern[0]=1,[4]=1,[12]=1,[20]=1, rest=0
            //   => 2^0 + 2^4 + 2^12 + 2^20 = 0x0010_1011
            //----------------------------------------------------------
            3'd7: begin
                y_period  = 5'd28; y_pattern = 32'h0010_1011;
                w_period  = 5'd1;  w_pattern = 32'h0000_0000;
            end

            default: begin
                y_period  = 5'd1;  y_pattern = 32'h0000_0001;
                w_period  = 5'd1;  w_pattern = 32'h0000_0001;
            end
        endcase
    end

    //------------------------------------------------------------------------
    // Select the active period/pattern based on stream type
    //------------------------------------------------------------------------
    wire [4:0]  active_period  = is_w_stream ? w_period  : y_period;
    wire [31:0] active_pattern = is_w_stream ? w_pattern : y_pattern;

    //------------------------------------------------------------------------
    // addr mod period (combinational, small constants → LUTs)
    //------------------------------------------------------------------------
    reg [4:0] addr_mod;

    always @(*) begin
        case (active_period)
            5'd1:  addr_mod = 5'd0;
            5'd2:  addr_mod = {4'd0, addr[0]};
            5'd4:  addr_mod = {3'd0, addr[1:0]};
            5'd6:  addr_mod = addr % 12'd6;
            5'd12: addr_mod = addr % 12'd12;
            5'd20: addr_mod = addr % 12'd20;
            5'd28: addr_mod = addr % 12'd28;
            default: addr_mod = 5'd0;
        endcase
    end

    //------------------------------------------------------------------------
    // Final keep decision
    //------------------------------------------------------------------------
    assign keep = is_sys | active_pattern[addr_mod];

endmodule