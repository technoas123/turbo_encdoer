`timescale 1ns / 1ps

//==============================================================================
// DVB-RCS2 ARP (Almost Regular Permutation) interleaver
//
//   int_addr(j)  = (P*j + Qt[j mod 4]) mod N
//   swap_bits(j) = ~j[0]          (pair swap for even j, 0-based)
//
// Qt0..Qt3 are precomputed per waveform in profile_lookup_rom:
//   Qt0 = 3 mod N
//   Qt1 = (4*Q1 + 3) mod N
//   Qt2 = (4*Q0*P + 4*Q2 + 3) mod N
//   Qt3 = (4*Q0*P + 4*Q3 + 3) mod N
//
// Per couple, the logic is one 12-bit add and compare for S = P*j mod N,
// then one mux and one add and compare for the final address.
//==============================================================================

module arp_interleaver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,      // 1-cycle pulse before Pass 2 (sets j = 0)
    input  wire        step,       // 1-cycle pulse per couple in Pass 2

    input  wire [11:0] cfg_N,
    input  wire [11:0] cfg_P,
    input  wire [11:0] cfg_qt0,
    input  wire [11:0] cfg_qt1,
    input  wire [11:0] cfg_qt2,
    input  wire [11:0] cfg_qt3,

    output wire [11:0] int_addr,   // interleaved address, 0 .. N-1
    output wire        swap_bits   // 1 = swap (B,A) for even j
);

    //--------------------------------------------------------------------------
    // Running index j and base accumulator S = (P*j) mod N
    //--------------------------------------------------------------------------
    reg [11:0] j_reg;
    reg [11:0] S_reg;

    wire [12:0] S_plus_P = {1'b0, S_reg} + {1'b0, cfg_P};
    wire [11:0] S_next   = (S_plus_P >= {1'b0, cfg_N})
                         ? (S_plus_P[11:0] - cfg_N)
                         :  S_plus_P[11:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            j_reg <= 12'd0;
            S_reg <= 12'd0;
        end else if (start) begin
            j_reg <= 12'd0;
            S_reg <= 12'd0;
        end else if (step) begin
            j_reg <= j_reg + 12'd1;
            S_reg <= S_next;
        end
    end

    //--------------------------------------------------------------------------
    // Select Qt by j mod 4
    //--------------------------------------------------------------------------
    reg [11:0] selected_qt;

    always @(*) begin
        case (j_reg[1:0])
            2'b00: selected_qt = cfg_qt0;
            2'b01: selected_qt = cfg_qt1;
            2'b10: selected_qt = cfg_qt2;
            2'b11: selected_qt = cfg_qt3;
        endcase
    end

    //--------------------------------------------------------------------------
    // Address = (S + Qt) mod N. Both operands are < N, so the sum is < 2N.
    //--------------------------------------------------------------------------
    wire [12:0] addr_sum = {1'b0, S_reg} + {1'b0, selected_qt};

    assign int_addr = (addr_sum >= {1'b0, cfg_N})
                    ? (addr_sum[11:0] - cfg_N)
                    :  addr_sum[11:0];

    // MATLAB: mod(j,2) == 0 -> swap (0-based j)
    assign swap_bits = ~j_reg[0];

endmodule