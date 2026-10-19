`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: turbo_encoder_top
// Description: DVB-RCS2 Turbo Encoder Top with AXI Stream interfaces.
//              - Slave AXI Stream input: 32-bit words, 3 words per block
//                (48 couples packed as 16 couples/word, 2 bits/couple).
//              - Master AXI Stream output: 32-bit words, 9 words per block
//                (48 symbols packed as 6 bits/symbol, bit-aligned).
//              - Rate 1/3 mother code: 96 input bits -> 288 output bits.
//////////////////////////////////////////////////////////////////////////////////

module turbo_encoder_top #(
    parameter ADDR_WIDTH = 6
)(
    input wire clk,
    input wire rst_n,

    // AXI Stream slave input (block-based, 3 words = 48 couples)
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tlast,

    // AXI Stream master output (9 words = 288 bits)
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tlast
);

    // ------------------------------------------------------------------
    // Compile-time constants for N=48 configuration
    // ------------------------------------------------------------------
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

    localparam [ADDR_WIDTH-1:0] N_VAL      = 11'd48;
    localparam [ADDR_WIDTH-1:0] N_MINUS_1  = 11'd47;
    localparam [3:0]            R_MOD15    = 4'd3;   // 48 % 15

    // ------------------------------------------------------------------
    // FSM state and counter (declared early because they are referenced
    // by the AXI Stream input logic below)
    // ------------------------------------------------------------------
    reg [3:0]               state_reg;
    reg [ADDR_WIDTH - 1: 0] count;

    // ------------------------------------------------------------------
    // AXI Stream input buffer: 3 words x 32 bits = 96 bits = 48 couples
    // ------------------------------------------------------------------
    reg [31:0] in_buf          [0:2];
    reg [1:0]  in_word_cnt;
    wire       in_block_ready = (in_word_cnt == 2'd3);

    // Accept input only in IDLE, when previous output is drained, and
    // while the 3-word block is not yet complete.
    wire output_done;
    assign s_axis_tready = (state_reg == STATE_IDLE) && !in_block_ready && output_done;

    always @(posedge clk) begin
        if (!rst_n) begin
            in_word_cnt <= 2'd0;
        end
        else if (s_axis_tvalid && s_axis_tready) begin
            in_buf[in_word_cnt] <= s_axis_tdata;
            in_word_cnt <= in_word_cnt + 1'b1;
        end
        else if (state_reg == STATE_IDLE && in_block_ready && output_done) begin
            // Block consumed; reset counter for next block
            in_word_cnt <= 2'd0;
        end
    end

    // ------------------------------------------------------------------
    // Current input couple mux: selects 2-bit couple from 96-bit buffer
    //   word index  = count[5:4]  (0..2)
    //   couple lsb  = count[3:0] * 2
    // ------------------------------------------------------------------
    wire [1:0] current_couple = in_buf[count[5:4]][{count[3:0], 1'b0} +: 2];

    // ------------------------------------------------------------------
    // sys RAM: stores input couples
    // ------------------------------------------------------------------
    reg sys_we;
    reg [ADDR_WIDTH - 1: 0] sys_waddr;
    reg [1:0] sys_din;
    reg [ADDR_WIDTH - 1: 0] sys_raddr;
    wire [1:0] sys_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) u_sys_ram (
        .clk(clk), .we(sys_we), .waddr(sys_waddr), .din(sys_din),
        .raddr(sys_raddr), .dout(sys_dout)
    );

    // ------------------------------------------------------------------
    // par1 RAM: stores parity from systematic real encode
    // ------------------------------------------------------------------
    reg par1_we;
    reg [ADDR_WIDTH - 1: 0] par1_waddr;
    reg [1:0] par1_din;
    reg [ADDR_WIDTH - 1: 0] par1_raddr;
    wire [1:0] par1_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) par1_ram (
        .clk(clk), .we(par1_we), .waddr(par1_waddr), .din(par1_din),
        .raddr(par1_raddr), .dout(par1_dout)
    );

    // ------------------------------------------------------------------
    // par2 RAM: stores parity from interleaved real encode
    // ------------------------------------------------------------------
    reg par2_we;
    reg [ADDR_WIDTH - 1: 0] par2_waddr;
    reg [1:0] par2_din;
    reg [ADDR_WIDTH - 1: 0] par2_raddr;
    wire [1:0] par2_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) par2_ram (
        .clk(clk), .we(par2_we), .waddr(par2_waddr), .din(par2_din),
        .raddr(par2_raddr), .dout(par2_dout)
    );

    // ------------------------------------------------------------------
    // Constituent encoder (shared resource for all four passes)
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // Circular state ROM: maps (N mod 15, last_state) -> circular state
    // ------------------------------------------------------------------
    wire [3:0] rom_circ_state;
    circular_state_rom u_circ_rom (
        .r(R_MOD15), .last_state(ce_state_out), .circ_state(rom_circ_state)
    );

    // ------------------------------------------------------------------
    // ARP interleaver: generates permuted read addresses for passes 3/4
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // Remaining FSM and datapath registers
    // ------------------------------------------------------------------
    reg [ADDR_WIDTH - 1: 0] par_count;
    reg pipe_valid;
    reg arp_swap_q;
    reg [3:0] c1_reg;   // debug probe
    reg [3:0] c2_reg;   // debug probe

    // ------------------------------------------------------------------
    // Output AXI Stream packer: accumulates 6-bit symbols into 32-bit words
    // 48 symbols * 6 bits = 288 bits = 9 words exactly.
    //
    // Accumulator convention: acc_next = (out_acc << 6) | sym_data
    //   -> NEWEST symbol lands at the LSB end, OLDEST symbol is pushed
    //      up toward the MSB end of the valid window [out_acc_bits-1:0].
    //   -> Therefore the oldest (first-produced) data must be extracted
    //      from the TOP of the valid window - which is what the -: 32
    //      indexed part-select below does.
    //   -> CRITICAL: after extracting the top 32 bits, the leftover
    //      bits are ALREADY sitting at the bottom of the register,
    //      correctly positioned for next cycle's (out_acc << 6) math.
    //      No shift of out_acc is required on emit - only out_acc_bits
    //      (the valid-bit bookkeeping) decreases by 32.
    // ------------------------------------------------------------------
        reg        sym_valid;
        reg [5:0]  sym_data;
        reg [63:0] out_acc;
        reg [5:0]  out_acc_bits;
        reg [3:0]  out_word_cnt;
        // *** FIX C: pipe_valid_q removed - see explanation above ***
    
        wire output_stall = m_axis_tvalid && !m_axis_tready;
    
        wire       push_sym = sym_valid;
        wire [63:0] acc_next      = push_sym ? ((out_acc << 6) | sym_data) : out_acc;
        wire [5:0]  acc_bits_next = push_sym ? (out_acc_bits + 6'd6)       : out_acc_bits;
        wire        emit_word     = (acc_bits_next >= 6'd32) && !m_axis_tvalid;
    
        assign output_done = (out_word_cnt == 4'd0) && !m_axis_tvalid && (out_acc_bits == 6'd0);
    
        always @(posedge clk) begin
            if (!rst_n) begin
                sym_valid     <= 1'b0;
                sym_data      <= 6'd0;
                out_acc       <= 64'd0;
                out_acc_bits  <= 6'd0;
                out_word_cnt  <= 4'd0;
                m_axis_tvalid <= 1'b0;
                m_axis_tdata  <= 32'd0;
                m_axis_tlast  <= 1'b0;
            end
            else begin
                if (m_axis_tvalid && m_axis_tready) begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    if (out_word_cnt == 4'd9)
                        out_word_cnt <= 4'd0;
                end
    
                // *** FIX C ***
                // Single-stage capture, matching the original proven-correct
                // READOUT pattern: gate directly on 'pipe_valid'.
                sym_valid <= (state_reg == STATE_READOUT) && pipe_valid && !output_stall;
                if ((state_reg == STATE_READOUT) && pipe_valid && !output_stall)
                    sym_data <= {sys_dout, par1_dout, par2_dout};
    
                out_acc      <= acc_next;
                out_acc_bits <= acc_bits_next;
    
                if (emit_word) begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata  <= acc_next[acc_bits_next - 1 -: 32];
                    out_acc       <= acc_next;              // FIX A - no shift
                    out_acc_bits  <= acc_bits_next - 6'd32;
                    out_word_cnt  <= out_word_cnt + 1'b1;
                    if (out_word_cnt == 4'd8)
                        m_axis_tlast <= 1'b1;
                end
            end
        end    
    

    // ------------------------------------------------------------------
    // CE input multiplexer
    // ------------------------------------------------------------------
    always @(*) begin
        case (state_reg)
            STATE_IDLE: begin
                ce_enable = in_block_ready && output_done;
                ce_a = current_couple[1];
                ce_b = current_couple[0];
            end

            STATE_PASS1: begin
                ce_enable = 1'b1;
                ce_a = current_couple[1];
                ce_b = current_couple[0];
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

    // ------------------------------------------------------------------
    // Memory read/write routing
    // ------------------------------------------------------------------
    always @(*) begin
        sys_we    = ((state_reg == STATE_IDLE) && in_block_ready && output_done) ||
                    (state_reg == STATE_PASS1);
        sys_waddr = count;
        sys_din   = current_couple;

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

    // ------------------------------------------------------------------
    // Master FSM
    // ------------------------------------------------------------------
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
        end
        else begin
            ce_load_init <= 1'b0;
            arp_start    <= 1'b0;

            case (state_reg)

                STATE_IDLE: begin
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    pipe_valid <= 1'b0;

                    if (in_block_ready && output_done) begin
                        count     <= 11'd1;
                        state_reg <= STATE_PASS1;
                    end
                end

                STATE_PASS1: begin
                    if (count == N_MINUS_1) begin
                        count     <= {ADDR_WIDTH{1'b0}};
                        state_reg <= STATE_PASS1_TAIL;
                    end
                    else begin
                        count <= count + 1'b1;
                    end
                end

                STATE_PASS1_TAIL: begin
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
                    ce_init_state <= 4'd0;
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
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_PASS3_TAIL2;
                end

                STATE_PASS3_TAIL2: begin
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

                        if (count == N_MINUS_1) begin
                            arp_enable <= 1'b0;
                            state_reg  <= STATE_PASS4_TAIL;
                        end
                    end
                end

                STATE_PASS4_TAIL: begin
                    pipe_valid <= 1'b0;
                    count      <= {ADDR_WIDTH{1'b0}};
                    par_count  <= {ADDR_WIDTH{1'b0}};
                    state_reg  <= STATE_READOUT;
                end

                STATE_READOUT: begin
                    if (!output_stall) begin
                        pipe_valid <= 1'b1;
                        count      <= count + 1'b1;

                        if (count == N_VAL) begin
                            ce_load_init  <= 1'b1;
                            ce_init_state <= 4'd0;
                            state_reg     <= STATE_READOUT_TAIL;
                        end
                    end
                end

                STATE_READOUT_TAIL: begin
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