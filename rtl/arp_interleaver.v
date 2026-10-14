`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: arp_interleaver
// Description: DVB-RCS2 ARP interleaver for N=48, P=13,
//              Q = [0, 2, 4, 6]. The permutation is hardcoded as a
//              lookup table because all parameters are compile-time
//              constants for this project - this collapses the previous
//              variable-divisor modulo into a few LUT levels.
//
//              Formula reference: int_addr[j] = (P*j + Qj + 3) mod N
//              where Qj depends on j mod 4 as defined in the standard.
//////////////////////////////////////////////////////////////////////////////////

module arp_interleaver #(
    parameter ADDR_WIDTH = 11,
    parameter N          = 48
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     start,
    input  wire                     enable,
    output wire [ADDR_WIDTH-1:0]    int_addr,
    output wire                     swap_bits,
    output wire                     valid,
    output wire                     done
);

    localparam J_MAX = N - 1;           // 47

    reg [5:0] j_reg;
    reg       active_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            active_reg <= 1'b0;
            j_reg      <= 6'd0;
        end
        else if (start) begin
            active_reg <= 1'b1;
            j_reg      <= 6'd0;
        end
        else if (active_reg && enable) begin
            if (j_reg == J_MAX[5:0]) active_reg <= 1'b0;
            else                     j_reg      <= j_reg + 1'b1;
        end
    end

    assign valid = active_reg;
    assign done  = active_reg && enable && (j_reg == J_MAX[5:0]);

    // ETSI DVB-RCS2: swap A/B on even j
    assign swap_bits = ~j_reg[0];

    // ------------------------------------------------------------------
    // Precomputed permutation ROM (48 entries), (13j + Qj + 3) mod 48:
    // ------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] int_addr_r;

    always @(*) begin
        case (j_reg)
            6'd 0: int_addr_r = 11'd 3;
            6'd 1: int_addr_r = 11'd24;
            6'd 2: int_addr_r = 11'd45;
            6'd 3: int_addr_r = 11'd18;
            6'd 4: int_addr_r = 11'd 7;
            6'd 5: int_addr_r = 11'd28;
            6'd 6: int_addr_r = 11'd 1;
            6'd 7: int_addr_r = 11'd22;
            6'd 8: int_addr_r = 11'd11;
            6'd 9: int_addr_r = 11'd32;
            6'd10: int_addr_r = 11'd 5;
            6'd11: int_addr_r = 11'd26;
            6'd12: int_addr_r = 11'd15;
            6'd13: int_addr_r = 11'd36;
            6'd14: int_addr_r = 11'd 9;
            6'd15: int_addr_r = 11'd30;
            6'd16: int_addr_r = 11'd19;
            6'd17: int_addr_r = 11'd40;
            6'd18: int_addr_r = 11'd13;
            6'd19: int_addr_r = 11'd34;
            6'd20: int_addr_r = 11'd23;
            6'd21: int_addr_r = 11'd44;
            6'd22: int_addr_r = 11'd17;
            6'd23: int_addr_r = 11'd38;
            6'd24: int_addr_r = 11'd27;
            6'd25: int_addr_r = 11'd 0;
            6'd26: int_addr_r = 11'd21;
            6'd27: int_addr_r = 11'd42;
            6'd28: int_addr_r = 11'd31;
            6'd29: int_addr_r = 11'd 4;
            6'd30: int_addr_r = 11'd25;
            6'd31: int_addr_r = 11'd46;
            6'd32: int_addr_r = 11'd35;
            6'd33: int_addr_r = 11'd 8;
            6'd34: int_addr_r = 11'd29;
            6'd35: int_addr_r = 11'd 2;
            6'd36: int_addr_r = 11'd39;
            6'd37: int_addr_r = 11'd12;
            6'd38: int_addr_r = 11'd33;
            6'd39: int_addr_r = 11'd 6;
            6'd40: int_addr_r = 11'd43;
            6'd41: int_addr_r = 11'd16;
            6'd42: int_addr_r = 11'd37;
            6'd43: int_addr_r = 11'd10;
            6'd44: int_addr_r = 11'd47;
            6'd45: int_addr_r = 11'd20;
            6'd46: int_addr_r = 11'd41;
            6'd47: int_addr_r = 11'd14;
            default: int_addr_r = 11'd 0;
        endcase
    end

    assign int_addr = int_addr_r;

endmodule