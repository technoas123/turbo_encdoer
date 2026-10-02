`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ahammed Salahuddeen N Y
// 
// Create Date: 09/29/2026 11:45:07 AM
// Design Name: 
// Module Name: turbo_encoder_top
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


module turbo_encoder_top #(
    parameter ADDR_WIDTH = 11
)(
    input wire clk,
    input wire rst_n,
    input wire [ADDR_WIDTH - 1: 0] blk_size_N,
    input wire [ADDR_WIDTH - 1: 0] arp_p,
    input wire [ADDR_WIDTH - 1: 0] arp_Q0,
    input wire [ADDR_WIDTH - 1: 0] arp_Q1,
    input wire [ADDR_WIDTH - 1: 0] arp_Q2,
    input wire [ADDR_WIDTH - 1: 0] arp_Q3,
    input wire in_valid,
    input wire [1:0] in_couple,
    output wire in_ready,
    output reg out_valid,
    output reg [5:0] out_symbol,
    output reg out_done
    );
    
    localparam STATE_IDLE = 4'd0;
    localparam STATE_PASS1 = 4'd1;
    localparam STATE_PASS1_TAIL = 4'd2;
    localparam STATE_PASS2 = 4'd3;
    localparam STATE_PASS2_TAIL = 4'd4;
    localparam STATE_PASS3 = 4'd5;
    localparam STATE_PASS3_TAIL = 4'd6;
    localparam STATE_PASS4 = 4'd7;
    localparam STATE_PASS4_TAIL = 4'd8;
    localparam STATE_READOUT = 4'd9;
    localparam STATE_READOUT_TAIL = 4'd10;
    
    reg [3:0] state_reg;
    assign in_ready = (state_reg == STATE_IDLE);
    
    //systematic rams to store input -> A,B, store parity pairs -> Y1, W1, store paity pairs -> Y2, W2
    
    reg sys_we;
    reg [ADDR_WIDTH - 1: 0] sys_waddr;
    reg [1:0] sys_din;
    reg [ADDR_WIDTH - 1: 0] sys_raddr;
    wire [1:0] sys_dout;
    
    ram_sdp #(
        .DATA_WIDTH(2),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_sys_ram (
        .clk (clk),
        .we (sys_we),
        .waddr (sys_waddr),
        .din (sys_din),
        .raddr (sys_raddr),
        .dout (sys_dout)
    );
    
    reg par1_we;
    reg [ADDR_WIDTH - 1: 0] par1_waddr;
    reg [1:0] par1_din;
    reg [ADDR_WIDTH - 1: 0] par1_raddr;
    wire [1:0] par1_dout;
    
    ram_sdp #(
        .DATA_WIDTH(2),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) par1_ram (
        .clk (clk),
        .we (par1_we),
        .waddr (par1_waddr),
        .din (par1_din),
        .raddr (par1_raddr),
        .dout (par1_dout)
    );
    
    reg par2_we;
    reg [ADDR_WIDTH - 1: 0] par2_waddr;
    reg [1:0] par2_din;
    reg [ADDR_WIDTH - 1: 0] par2_raddr;
    wire [1:0] par2_dout;
    
    ram_sdp #(
        .DATA_WIDTH(2),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) par2_ram (
        .clk (clk),
        .we (par2_we),
        .waddr (par2_waddr),
        .din (par2_din),
        .raddr (par2_raddr),
        .dout (par2_dout)
    );
    
    reg ce_load_init;
    reg [3:0] ce_init_state;
    reg ce_enable;
    reg ce_a;
    reg ce_b;
    wire ce_y;
    wire ce_w;
    wire [3:0] ce_state_out;
    
    constituent_encoder u_ce (
        .clk (clk),
        .rst_n (rst_n),
        .load_init (ce_load_init),
        .init_state (ce_init_state),
        .enable (ce_enable),
        .a (ce_a),
        .b (ce_b),
        .y (ce_y),
        .w (ce_w),
        .state_out (ce_state_out)        
    );
    
    wire [3:0] r_mod15;
    wire [3:0] rom_circ_state;
    
    assign r_mod15 = blk_size_N  % 15;
    
    circular_state_rom u_circ_rom (
        .r (r_mod15),
        .last_state (ce_state_out),
        .circ_state (rom_circ_state)
    );
    
    reg arp_start;
    reg arp_enable;
    wire [ADDR_WIDTH -1: 0] arp_int_addr;
    wire arp_swap_bits;
    wire arp_valid;
    wire arp_done;
    
    arp_interleaver #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_arp (
        .clk (clk),
        .rst_n (rst_n),
        .start (arp_start),
        .enable (arp_enable),
        .N (blk_size_N),
        .p (arp_p),
        .Q0 (arp_Q0),
        .Q1 (arp_Q1),
        .Q2 (arp_Q2),
        .Q3 (arp_Q3),
        .int_addr (arp_int_addr),
        .swap_bits (arp_swap_bits),
        .valid (arp_valid),
        .done (arp_done)        
    );
    
    reg [ADDR_WIDTH - 1: 0] count;
    reg pipe_valid;
    reg arp_swap_q;
    reg [3:0] c1_reg;
    reg [3:0] c2_reg;
    
    always @(*) begin
        case (state_reg)
            STATE_PASS1: begin
                ce_enable = in_valid;
                ce_a = in_couple[1];
                ce_b = in_couple [0];
            end
            
            STATE_PASS2, STATE_PASS2_TAIL: begin 
                ce_enable = pipe_valid;
                ce_a = sys_dout[1];
                ce_b = sys_dout[0];
            end
            
            STATE_PASS3, STATE_PASS3_TAIL, 
            STATE_PASS4, STATE_PASS4_TAIL: begin
                ce_enable = pipe_valid;
                if (arp_swap_q) begin
                    ce_a = sys_dout[0];
                    ce_b = sys_dout[1];
                end else begin 
                    ce_a = sys_dout[1];
                    ce_b = sys_dout[0];
                end
            end
            
            default: begin
                ce_enable = 1'b0;
                ce_a = 1'b0;
                ce_b = 1'b0;
            end
        endcase
    end
    
    //storage read and write routing muxes
    
    always @(*) begin
        sys_we = ((state_reg == STATE_PASS1) || (state_reg == STATE_IDLE)) && in_valid;
        sys_waddr = count;
        sys_din = in_couple;
        
        case (state_reg)
            STATE_PASS2, STATE_PASS2_TAIL,
            STATE_READOUT, STATE_READOUT_TAIL: sys_raddr = count;
            STATE_PASS3, STATE_PASS3_TAIL,
            STATE_PASS4, STATE_PASS4_TAIL:    sys_raddr = arp_int_addr;
            default:                          sys_raddr = {ADDR_WIDTH{1'b0}};           
        endcase
        
        par1_we = ((state_reg == STATE_PASS2) || 
                    (state_reg == STATE_PASS2_TAIL)) && pipe_valid;
        par1_waddr = (count > 0) ? (count - 1'b1) : (blk_size_N - 1'b1);
        par1_din = {ce_y, ce_w};
        par1_raddr = count;
        
        par2_we = ((state_reg == STATE_PASS4) ||
                    (state_reg == STATE_PASS4_TAIL)) && pipe_valid;
        par2_waddr = (count > 0) ? (count - 1'b1) : (blk_size_N - 1'b1);
        par2_din = {ce_y, ce_w};
        par2_raddr = count;        
    end
    
    //master fsm 
    
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= STATE_IDLE;
            count <= {ADDR_WIDTH{1'b0}};
            pipe_valid <= 1'b0;
            arp_swap_q <= 1'b0;
            c1_reg <= 4'd0;
            c2_reg <= 4'd0;
            ce_load_init <= 1'b0;
            ce_init_state <= 4'd0;
            arp_start <= 1'b0;
            arp_enable <= 1'b0;
            out_valid <= 1'b0;
            out_symbol <= 6'd0;
            out_done <= 1'b0;
        end
        else begin
            ce_load_init <= 1'b0;
            arp_start <= 1'b0;
            out_done <= 1'b0;
            
            case (state_reg) 
                STATE_IDLE: begin 
                    count <= {ADDR_WIDTH{1'b0}};
                    pipe_valid <= 1'b0;
                    out_valid <= 1'b0;
                    
                    if (in_valid) begin
                        ce_load_init  <= 1'b1;
                        ce_init_state <= 4'd0;
                        count         <= 11'd1; // couple 0 is written at addr 0; next write goes to addr 1
                        state_reg     <= STATE_PASS1;
                    end
                 end
                 
                 STATE_PASS1: begin
                    if(in_valid) begin
                        if (count == blk_size_N - 1'b1) begin
                            count <= {ADDR_WIDTH{1'b0}};
                            state_reg <= STATE_PASS1_TAIL;
                        end
                        else begin 
                            count <= count + 1'b1;
                        end
                    end
                 end
                 
                 STATE_PASS1_TAIL: begin
                    c1_reg <= rom_circ_state;
                    ce_load_init <= 1'b1;
                    ce_init_state <= rom_circ_state;
                    count <= {ADDR_WIDTH{1'b0}};
                    pipe_valid <= 1'b0;
                    state_reg <= STATE_PASS2;
                 end
                 
                STATE_PASS2: begin
                    pipe_valid <= 1'b1;                 // mem read launched
                    count      <= count + 1'b1;

                    if (count == blk_size_N - 1'b1) begin
                        state_reg <= STATE_PASS2_TAIL;
                    end
                end
                
                STATE_PASS2_TAIL: begin
                    pipe_valid    <= 1'b0;
                    count         <= {ADDR_WIDTH{1'b0}};
                    arp_start     <= 1'b1;
                    arp_enable    <= 1'b1;
                    ce_load_init  <= 1'b1;
                    ce_init_state <= 4'd0;
                    state_reg     <= STATE_PASS3;
                end
                 
                STATE_PASS3: begin
                    pipe_valid <= arp_valid;
                    arp_swap_q <= arp_swap_bits;

                    if (arp_done) arp_enable <= 1'b0;

                    if (arp_valid) begin
                        count <= count + 1'b1;
                        if (count == blk_size_N - 1'b1) begin
                            arp_enable <= 1'b0;
                            state_reg <= STATE_PASS3_TAIL;
                        end
                    end
                end
                
                STATE_PASS3_TAIL: begin
                    c2_reg        <= rom_circ_state;
                    arp_start     <= 1'b1;
                    arp_enable    <= 1'b1;
                    ce_load_init  <= 1'b1;
                    ce_init_state <= rom_circ_state;
                    count         <= {ADDR_WIDTH{1'b0}};
                    pipe_valid    <= 1'b0;
                    state_reg     <= STATE_PASS4;
                end
                 
                STATE_PASS4: begin
                    pipe_valid <= arp_valid;
                    arp_swap_q <= arp_swap_bits;

                    if (arp_done) arp_enable <= 1'b0;

                    if (arp_valid) begin
                        count <= count + 1'b1;
                        if (count == blk_size_N - 1'b1) begin
                            arp_enable <= 1'b0;
                            state_reg <= STATE_PASS4_TAIL;
                        end
                    end
                end
                
                STATE_PASS4_TAIL: begin
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_READOUT;
                end
                
                STATE_READOUT: begin
                    pipe_valid <= 1'b1;
                    count      <= count + 1'b1;

                    if (pipe_valid) begin
                        out_valid  <= 1'b1;
                        out_symbol <= {sys_dout, par1_dout, par2_dout};
                    end

                    if (count == blk_size_N - 1'b1) begin
                        state_reg <= STATE_READOUT_TAIL;
                    end
                end
                
                STATE_READOUT_TAIL: begin
                    out_valid  <= 1'b1;
                    out_symbol <= {sys_dout, par1_dout, par2_dout};
                    out_done   <= 1'b1;
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_IDLE;
                end
                
                default: state_reg <= STATE_IDLE;                
            endcase            
        end
    end    
endmodule
