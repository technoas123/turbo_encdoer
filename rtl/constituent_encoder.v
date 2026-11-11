`timescale 1ns / 1ps

module constituent_encoder(
    input  wire clk,
    input  wire rst_n,
    input  wire load_init,
    input  wire [3:0] init_state,
    input  wire enable,
    input  wire a,
    input  wire b,
    output wire y,
    output wire w,
    output wire [3:0] state_out
);

    reg [3:0] state_reg;
    wire f;

    assign state_out = state_reg;
    
    // MATLAB: F = mod(A + B + S3 + S4, 2)
    assign f = a ^ b ^ state_reg[1] ^ state_reg[0];
    
    // MATLAB: Y = mod(F + B + S1 + S2 + S4, 2)
    assign y = f ^ b ^ state_reg[3] ^ state_reg[2] ^ state_reg[0];
    
    // MATLAB: W = mod(F + B + S2 + S3 + S4, 2)
    assign w = f ^ b ^ state_reg[2] ^ state_reg[1] ^ state_reg[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 4'b0000;
        end
        else if (load_init) begin
            state_reg <= init_state;
        end
        else if (enable) begin
            // MATLAB: nextBits = [F S1 S2 S3] -> shift right
            state_reg <= {f, state_reg[3:1]};
        end
    end

endmodule