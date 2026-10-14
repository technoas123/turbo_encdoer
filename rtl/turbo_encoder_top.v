`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: turbo_encoder_top
// Description: DVB-RCS2 Turbo Encoder Top - rate 1/3 mother code
// Corrections: (1) IDLE encodes couple 0 in PASS1 dry-run
//              (2) PASS3_TAIL2 so C2 ROM sample happens after state settles
//              (3) PASS4 exit = N-1
//              (4) clean READOUT (exactly N valid beats), clean CE clear
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

    localparam STATE_IDLE         = 4'd0;
    localparam STATE_PASS1        = 4'd1;
    localparam STATE_PASS1_TAIL   = 4'd2;
    localparam STATE_PASS2        = 4'd3;
    localparam STATE_PASS2_TAIL   = 4'd4;
    localparam STATE_PASS3        = 4'd5;
    localparam STATE_PASS3_TAIL   = 4'd6;
    localparam STATE_PASS3_TAIL2  = 4'd11;
    localparam STATE_PASS4        = 4'd7;
    localparam STATE_PASS4_TAIL   = 4'd8;
    localparam STATE_READOUT      = 4'd9;
    localparam STATE_READOUT_TAIL = 4'd10;
        // ---- Compile-time constants (this configuration: N=48) ----
    localparam [ADDR_WIDTH-1:0] N_VAL      = 11'd48;
    localparam [ADDR_WIDTH-1:0] N_MINUS_1  = 11'd47;
    localparam [3:0]            R_MOD15    = 4'd3;   // 48 % 15

    reg [3:0] state_reg;
    reg       in_ready_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) in_ready_r <= 1'b1;                               // reset → ready
        else        in_ready_r <= (state_reg == STATE_IDLE);
    end
    assign in_ready = in_ready_r;

    // ---- sys RAM ----
    reg sys_we;
    reg [ADDR_WIDTH - 1: 0] sys_waddr;
    reg [1:0] sys_din;
    reg [ADDR_WIDTH - 1: 0] sys_raddr;
    wire [1:0] sys_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) u_sys_ram (
        .clk(clk), .we(sys_we), .waddr(sys_waddr), .din(sys_din),
        .raddr(sys_raddr), .dout(sys_dout)
    );

    // ---- par1 (encoder 1) ----
    reg par1_we;
    reg [ADDR_WIDTH - 1: 0] par1_waddr;
    reg [1:0] par1_din;
    reg [ADDR_WIDTH - 1: 0] par1_raddr;
    wire [1:0] par1_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) par1_ram (
        .clk(clk), .we(par1_we), .waddr(par1_waddr), .din(par1_din),
        .raddr(par1_raddr), .dout(par1_dout)
    );

    // ---- par2 (encoder 2) ----
    reg par2_we;
    reg [ADDR_WIDTH - 1: 0] par2_waddr;
    reg [1:0] par2_din;
    reg [ADDR_WIDTH - 1: 0] par2_raddr;
    wire [1:0] par2_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) par2_ram (
        .clk(clk), .we(par2_we), .waddr(par2_waddr), .din(par2_din),
        .raddr(par2_raddr), .dout(par2_dout)
    );

    // ---- constituent encoder ----
    reg ce_load_init;
    reg [3:0] ce_init_state;
    reg ce_enable;
    reg ce_a;
    reg ce_b;
    wire ce_y;
    wire ce_w;
    wire [3:0] ce_state_out;

    constituent_encoder u_ce (
        .clk(clk), .rst_n(rst_n), .load_init(ce_load_init),
        .init_state(ce_init_state), .enable(ce_enable),
        .a(ce_a), .b(ce_b), .y(ce_y), .w(ce_w),
        .state_out(ce_state_out)
    );

    // ---- circular state ROM ----
        wire [3:0] rom_circ_state;
    // Constant: 48 % 15 = 3 - no runtime divider synthesized

        circular_state_rom u_circ_rom (
        .r(R_MOD15), .last_state(ce_state_out), .circ_state(rom_circ_state)
    );

    // ---- ARP interleaver ----
    reg arp_start;
    reg arp_enable;
    wire [ADDR_WIDTH - 1: 0] arp_int_addr;
    wire arp_swap_bits;
    wire arp_valid;
    wire arp_done;

        arp_interleaver #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .N(48)
    ) u_arp (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (arp_start),
        .enable     (arp_enable),
        .int_addr   (arp_int_addr),
        .swap_bits  (arp_swap_bits),
        .valid      (arp_valid),
        .done       (arp_done)
    );

    reg [ADDR_WIDTH - 1: 0] count;
    reg [ADDR_WIDTH - 1: 0] par_count;
    reg pipe_valid;
    reg arp_swap_q;
    reg [3:0] c1_reg;   // debug probe - unused in netlist but visible to TB
    reg [3:0] c2_reg;   // debug probe

    // ---------------- CE input multiplexer ----------------
    always @(*) begin
        case (state_reg)

            // FIX #1: couple 0 arrives during IDLE and must be encoded,
            // otherwise the PASS1 dry-run sees only 47 couples -> C1 wrong.
            STATE_IDLE, STATE_PASS1: begin
                ce_enable = in_valid;
                ce_a = in_couple[1];
                ce_b = in_couple[0];
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

    // ---------------- Memory read/write routing ----------------
    always @(*) begin
        sys_we    = ((state_reg == STATE_PASS1) || (state_reg == STATE_IDLE)) && in_valid;
        sys_waddr = count;
        sys_din   = in_couple;

        case (state_reg)
            STATE_PASS2, STATE_PASS2_TAIL,
            STATE_READOUT, STATE_READOUT_TAIL: sys_raddr = count;
            STATE_PASS3, STATE_PASS3_TAIL,
            STATE_PASS4, STATE_PASS4_TAIL:    sys_raddr = arp_int_addr;
            default:                          sys_raddr = {ADDR_WIDTH{1'b0}};
        endcase

        par1_we    = ((state_reg == STATE_PASS2) || (state_reg == STATE_PASS2_TAIL)) && pipe_valid;
        par1_waddr = par_count;
        par1_din   = {ce_y, ce_w};
        par1_raddr = count;

        par2_we    = ((state_reg == STATE_PASS4) || (state_reg == STATE_PASS4_TAIL)) && pipe_valid;
        par2_waddr = par_count;
        par2_din   = {ce_y, ce_w};
        par2_raddr = count;
    end

    // ---------------- Master FSM ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg     <= STATE_IDLE;
            count         <= {ADDR_WIDTH{1'b0}};
            par_count     <= {ADDR_WIDTH{1'b0}};
            pipe_valid    <= 1'b0;
            arp_swap_q    <= 1'b0;
            c1_reg        <= 4'd0;
            c2_reg        <= 4'd0;
            ce_load_init  <= 1'b0;
            ce_init_state <= 4'd0;
            arp_start     <= 1'b0;
            arp_enable    <= 1'b0;
            out_valid     <= 1'b0;
            out_symbol    <= 6'd0;
            out_done      <= 1'b0;
        end
        else begin
            ce_load_init <= 1'b0;
            arp_start    <= 1'b0;
            out_done     <= 1'b0;

            case (state_reg)

                STATE_IDLE: begin
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    pipe_valid <= 1'b0;
                    out_valid  <= 1'b0;

                    if (in_valid) begin
                        count     <= 11'd1;
                        state_reg <= STATE_PASS1;
                    end
                end

                STATE_PASS1: begin
                    if (in_valid) begin
                        if (count == N_MINUS_1) begin
                            count     <= {ADDR_WIDTH{1'b0}};
                            state_reg <= STATE_PASS1_TAIL;
                        end
                        else begin
                            count <= count + 1'b1;
                        end
                    end
                end

                STATE_PASS1_TAIL: begin
                    // ce_state_out already holds lastState1 (PAST1 had a
                    // full bubble cycle after the last encode) -> sample OK
                    c1_reg        <= rom_circ_state;
                    ce_load_init  <= 1'b1;
                    ce_init_state <= rom_circ_state;
                    count         <= {ADDR_WIDTH{1'b0}};
                    par_count     <= {ADDR_WIDTH{1'b0}};
                    pipe_valid    <= 1'b0;
                    state_reg     <= STATE_PASS2;
                end

                STATE_PASS2: begin
                    pipe_valid <= 1'b1;
                    count      <= count + 1'b1;
                    if (pipe_valid) begin
                        par_count <= par_count + 1'b1;
                    end

                    if (count == N_VAL) begin
                        state_reg <= STATE_PASS2_TAIL;
                    end
                end

                STATE_PASS2_TAIL: begin
                    pipe_valid    <= 1'b0;
                    count         <= {ADDR_WIDTH{1'b0}};
                    par_count     <= {ADDR_WIDTH{1'b0}};
                    arp_start     <= 1'b1;
                    arp_enable    <= 1'b1;
                    ce_load_init  <= 1'b1;
                    ce_init_state <= 4'd0;      // dry-run of encoder 2 starts at 0
                    state_reg     <= STATE_PASS3;
                end

                STATE_PASS3: begin
                    pipe_valid <= arp_valid;
                    arp_swap_q <= arp_swap_bits;

                    if (arp_done) arp_enable <= 1'b0;

                    if (arp_valid) begin
                        count <= count + 1'b1;
                        if (count == N_MINUS_1) begin
                            arp_enable <= 1'b0;
                            state_reg  <= STATE_PASS3_TAIL;
                        end
                    end
                end

                STATE_PASS3_TAIL: begin
                    // FIX #2a: the 48th interleaved couple is encoded during
                    // THIS cycle -- ce_state_out updates at the end of it.
                    // Do not sample the ROM yet; kill the pipeline.
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_PASS3_TAIL2;
                end

                STATE_PASS3_TAIL2: begin
                    // FIX #2b: ce_state_out is now lastState2 -> ROM gives C2
                    c2_reg        <= rom_circ_state;
                    ce_load_init  <= 1'b1;
                    ce_init_state <= rom_circ_state;
                    arp_start     <= 1'b1;
                    arp_enable    <= 1'b1;
                    pipe_valid    <= 1'b0;
                    count         <= {ADDR_WIDTH{1'b0}};
                    par_count     <= {ADDR_WIDTH{1'b0}};
                    state_reg     <= STATE_PASS4;
                end

                STATE_PASS4: begin
                    pipe_valid <= arp_valid;
                    arp_swap_q <= arp_swap_bits;

                    if (arp_done) arp_enable <= 1'b0;

                    if (arp_valid) begin
                        count <= count + 1'b1;
                        if (pipe_valid) par_count <= par_count + 1'b1;

                        // FIX #3: was blk_size_N (never reached while arp_valid
                        // is high -> deadlock). Must be N-1, same as PASS3.
                        if (count == N_MINUS_1) begin
                            arp_enable <= 1'b0;
                            state_reg  <= STATE_PASS4_TAIL;
                        end
                    end
                end

                STATE_PASS4_TAIL: begin
                    // 48th couple's parity is written this cycle
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_READOUT;
                end

                STATE_READOUT: begin
                    pipe_valid <= 1'b1;
                    count      <= count + 1'b1;

                    if (pipe_valid) begin
                        out_valid  <= 1'b1;
                        out_symbol <= {sys_dout, par1_dout, par2_dout};
                    end

                    if (count == N_VAL) begin
                        // FIX #4a: clear CE here so it is already 0 when the
                        // FSM is back in IDLE (safe for back-to-back blocks)
                        ce_load_init  <= 1'b1;
                        ce_init_state <= 4'd0;
                        state_reg     <= STATE_READOUT_TAIL;
                    end
                end

                STATE_READOUT_TAIL: begin
                    // FIX #4b: exactly N valid beats, then done; no junk beat
                    out_done   <= 1'b1;
                    out_valid  <= 1'b0;
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_IDLE;
                end

                default: state_reg <= STATE_IDLE;
            endcase
        end
    end
endmodule