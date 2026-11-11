`timescale 1ns / 1ps

//==============================================================================
// DVB-RCS2 Generalized ARP (Almost Regular Permutation) Interleaver
//
// Matches MATLAB Reference (ARPInterleaver.m):
//   int_addr[j] = (P * j + Q(j) + 3) mod N
//   where for j mod 4:
//     case 0: Q(j) = 0             -> Q_tilde_0 = 3 mod N
//     case 1: Q(j) = 4*Q1          -> Q_tilde_1 = (4*Q1 + 3) mod N
//     case 2: Q(j) = 4*Q0*P + 4*Q2 -> Q_tilde_2 = (4*Q0*P + 4*Q2 + 3) mod N
//     case 3: Q(j) = 4*Q0*P + 4*Q3 -> Q_tilde_3 = (4*Q0*P + 4*Q3 + 3) mod N
//==============================================================================

module arp_interleaver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,      // 1-cycle pulse before Pass 2 begins (j=0 setup)
    input  wire        step,       // 1-cycle pulse per couple during Pass 2

    // Active frame parameters (latched in shadow registers at top level)
    input  wire [11:0] cfg_N,
    input  wire [11:0] cfg_P,
    input  wire [11:0] cfg_Q0,
    input  wire [11:0] cfg_Q1,
    input  wire [11:0] cfg_Q2,
    input  wire [11:0] cfg_Q3,

    output wire [11:0] int_addr,   // Interleaved BRAM read address (0 .. N-1)
    output wire        swap_bits   // 1 = swap (B,A) for even j; 0 = normal (A,B)
);

    //--------------------------------------------------------------------------
    // Combinational modulo-N reduction helper for Q_tilde precomputation
    // Max possible raw value: 4 * Q0 * P + 4 * Q3 + 3
    // Since Q0, Q3 < N and P < N, max raw value < 4*N^2 + 4*N + 3 (< 2^25).
    // Uses shift-and-subtract (13 stages) to reduce a 25-bit value modulo N.
    //--------------------------------------------------------------------------
    function [11:0] mod_n_reduce;
        input [24:0] val;
        input [11:0] n;
        reg   [24:0] rem;
        integer k;
        begin
            rem = val;
            if (n != 12'd0) begin
                for (k = 13; k >= 0; k = k - 1) begin
                    if (rem >= ({13'd0, n} << k))
                        rem = rem - ({13'd0, n} << k);
                end
            end
            mod_n_reduce = rem[11:0];
        end
    endfunction

    //--------------------------------------------------------------------------
    // Pre-reduced Q_tilde terms: computed combinationally from shadow registers
    // All reg declarations are at module scope (strictly outside always block)
    //--------------------------------------------------------------------------
    reg [24:0] term_q0_p;
    reg [24:0] raw0, raw1, raw2, raw3;
    reg [11:0] q_tilde_0;
    reg [11:0] q_tilde_1;
    reg [11:0] q_tilde_2;
    reg [11:0] q_tilde_3;

    always @(*) begin
        // 4 * Q0 * P = (Q0 * P) << 2
        term_q0_p = ({13'd0, cfg_Q0} * {13'd0, cfg_P}) << 2;

        raw0 = 25'd3;
        raw1 = ({13'd0, cfg_Q1} << 2) + 25'd3;
        raw2 = term_q0_p + ({13'd0, cfg_Q2} << 2) + 25'd3;
        raw3 = term_q0_p + ({13'd0, cfg_Q3} << 2) + 25'd3;

        q_tilde_0 = mod_n_reduce(raw0, cfg_N);
        q_tilde_1 = mod_n_reduce(raw1, cfg_N);
        q_tilde_2 = mod_n_reduce(raw2, cfg_N);
        q_tilde_3 = mod_n_reduce(raw3, cfg_N);
    end

    //--------------------------------------------------------------------------
    // Running Index (j_reg) and Base Accumulator S_reg = (P * j) mod N
    //--------------------------------------------------------------------------
    reg [11:0] j_reg;
    reg [11:0] S_reg;

    wire [12:0] S_plus_P = {1'b0, S_reg} + {1'b0, cfg_P};
    wire [11:0] S_next   = (S_plus_P >= {1'b0, cfg_N}) ?
                           (S_plus_P[11:0] - cfg_N) : S_plus_P[11:0];

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
    // Select Q_tilde based on j mod 4 (j_reg[1:0])
    //--------------------------------------------------------------------------
    reg [11:0] selected_q_tilde;

    always @(*) begin
        case (j_reg[1:0])
            2'b00: selected_q_tilde = q_tilde_0;
            2'b01: selected_q_tilde = q_tilde_1;
            2'b10: selected_q_tilde = q_tilde_2;
            2'b11: selected_q_tilde = q_tilde_3;
        endcase
    end

    //--------------------------------------------------------------------------
    // Final Modulo Addition: (S_reg + selected_q_tilde) mod cfg_N
    // Since S_reg < N and selected_q_tilde < N, their sum is < 2*N.
    //--------------------------------------------------------------------------
    wire [12:0] addr_sum = {1'b0, S_reg} + {1'b0, selected_q_tilde};

    assign int_addr  = (addr_sum >= {1'b0, cfg_N}) ?
                       (addr_sum - {1'b0, cfg_N}) : addr_sum[11:0];

    // MATLAB: if mod(j, 2) == 0 -> swap bits (even j in 0-based indexing)
    assign swap_bits = ~j_reg[0];

endmodule