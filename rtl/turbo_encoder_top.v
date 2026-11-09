`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: turbo_encoder_top
// Description: DVB-RCS2 Turbo Encoder with Xilinx AXI-Stream Data FIFOs.
//              Updated with 32-bit right-shift input extraction (Task 2).
//////////////////////////////////////////////////////////////////////////////////

module turbo_encoder_top #(
    parameter ADDR_WIDTH = 6
)(
    input  wire        clk,
    input  wire        rst_n,

    // ==========================================
    // 1. AXI-STREAM INPUT (Directly to Xilinx Input FIFO)
    // ==========================================
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    output wire        s_axis_tready,

    // ==========================================
    // 2. AXI-STREAM OUTPUT (Directly from Xilinx Output FIFO)
    // ==========================================
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast,
    input  wire        m_axis_tready
);

    // ------------------------------------------------------------------
    // Constants & State Definitions
    // ------------------------------------------------------------------
    localparam STATE_IDLE         = 4'd0;
    localparam STATE_LOAD         = 4'd12; // NEW: Shift stream into sys_ram
    localparam STATE_LOAD_RELOAD  = 4'd13; // NEW: Handle FIFO stall mid-frame
    localparam STATE_PASS1        = 4'd1;  // UPDATED: Read from sys_ram
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

    localparam [ADDR_WIDTH-1:0] N_VAL     = 6'd48;
    localparam [ADDR_WIDTH-1:0] N_MINUS_1 = 6'd47;
    localparam [3:0]            R_MOD15   = 4'd3;

    localparam FIFO_DEPTH      = 16;
    localparam WORDS_PER_FRAME = 9;

    // ------------------------------------------------------------------
    // FSM Internal Registers
    // ------------------------------------------------------------------
    reg [3:0]               state_reg;
    reg [ADDR_WIDTH-1:0]    count;
    reg [ADDR_WIDTH-1:0]    par_count;
    reg                     pipe_valid;
    reg                     arp_swap_q;
    reg [3:0]               c1_reg, c2_reg;

    // Shift Register Components
    reg [31:0]              shift_reg;
    reg [3:0]               word_bit_cnt;
    reg                     couple_valid;

    // ------------------------------------------------------------------
    // INPUT FIFO WIRES (Unpacked from Xilinx IP Master side)
    // ------------------------------------------------------------------
    wire [31:0] fifo_m_axis_tdata;
    wire        fifo_m_axis_tvalid;
    wire        fifo_m_axis_tlast;
    wire        fifo_m_axis_tready;

    // ------------------------------------------------------------------
    // OUTPUT FIFO WIRES & ROOM GUARD
    // ------------------------------------------------------------------
    wire [31:0] out_fifo_s_axis_tdata;
    wire        out_fifo_s_axis_tvalid;
    wire        out_fifo_s_axis_tlast;
    wire        out_fifo_s_axis_tready;
    wire [31:0] out_fifo_count;

    wire output_done;
    wire out_fifo_room = (out_fifo_count <= (FIFO_DEPTH - WORDS_PER_FRAME));

    wire [4:0] in_fifo_count  = 5'd0;
    wire [4:0] out_fifo_count_tb = out_fifo_count[4:0];

    // ------------------------------------------------------------------
    // 1. XILINX INPUT FIFO INSTANTIATION (RRC_Chain_AXI Pattern)
    // ------------------------------------------------------------------
    axis_data_fifo_0 U_INPUT_FIFO (
        .s_axis_aclk    (clk),
        .s_axis_aresetn (rst_n),

        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tready  (s_axis_tready),

        .m_axis_tdata   (fifo_m_axis_tdata),
        .m_axis_tvalid  (fifo_m_axis_tvalid),
        .m_axis_tlast   (fifo_m_axis_tlast),
        .m_axis_tready  (fifo_m_axis_tready)
    );

    // ------------------------------------------------------------------
    // Input Shift Extraction Logic
    // ------------------------------------------------------------------
    wire [1:0] current_couple = shift_reg[1:0]; // Combinational tap (0 LUTs)

    // AXI handshake logic for the Shift Register
    assign fifo_m_axis_tready = 
        (state_reg == STATE_IDLE && output_done && out_fifo_room) ||
        (state_reg == STATE_LOAD && word_bit_cnt == 4'd15 && count < N_MINUS_1) ||
        (state_reg == STATE_LOAD_RELOAD);

    // ------------------------------------------------------------------
    // Sub-module Instantiations (RAMs, Encoder, ARP)
    // ------------------------------------------------------------------
    reg                     sys_we;
    reg  [ADDR_WIDTH-1:0]   sys_waddr, sys_raddr;
    reg  [1:0]              sys_din;
    wire [1:0]              sys_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) u_sys_ram (
        .clk(clk), .we(sys_we), .waddr(sys_waddr), .din(sys_din),
        .raddr(sys_raddr), .dout(sys_dout)
    );

    reg                     par1_we;
    reg  [ADDR_WIDTH-1:0]   par1_waddr, par1_raddr;
    reg  [1:0]              par1_din;
    wire [1:0]              par1_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) par1_ram (
        .clk(clk), .we(par1_we), .waddr(par1_waddr), .din(par1_din),
        .raddr(par1_raddr), .dout(par1_dout)
    );

    reg                     par2_we;
    reg  [ADDR_WIDTH-1:0]   par2_waddr, par2_raddr;
    reg  [1:0]              par2_din;
    wire [1:0]              par2_dout;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(ADDR_WIDTH)) par2_ram (
        .clk(clk), .we(par2_we), .waddr(par2_waddr), .din(par2_din),
        .raddr(par2_raddr), .dout(par2_dout)
    );

    reg         ce_load_init, ce_enable, ce_a, ce_b;
    reg  [3:0]  ce_init_state;
    wire        ce_y, ce_w;
    wire [3:0]  ce_state_out;

    constituent_encoder u_ce (
        .clk(clk), .rst_n(rst_n),
        .load_init(ce_load_init), .init_state(ce_init_state),
        .enable(ce_enable), .a(ce_a), .b(ce_b),
        .y(ce_y), .w(ce_w), .state_out(ce_state_out)
    );

    wire [3:0] rom_circ_state;
    circular_state_rom u_circ_rom (
        .r(R_MOD15), .last_state(ce_state_out), .circ_state(rom_circ_state)
    );

    reg         arp_start, arp_enable;
    wire [ADDR_WIDTH-1:0] arp_int_addr;
    wire        arp_swap_bits, arp_valid, arp_done;

    arp_interleaver #(.ADDR_WIDTH(ADDR_WIDTH), .N(48)) u_arp (
        .clk(clk), .rst_n(rst_n),
        .start(arp_start), .enable(arp_enable),
        .int_addr(arp_int_addr), .swap_bits(arp_swap_bits),
        .valid(arp_valid), .done(arp_done)
    );

    // ------------------------------------------------------------------
    // Core Output Packer Logic
    // ------------------------------------------------------------------
    reg         sym_valid;
    reg  [5:0]  sym_data;
    reg  [63:0] out_acc;
    reg  [5:0]  out_acc_bits;
    reg  [3:0]  out_word_cnt;

    wire        push_sym      = sym_valid;
    wire [63:0] acc_next      = push_sym ? ((out_acc << 6) | {58'd0, sym_data}) : out_acc;
    wire [5:0]  acc_bits_next = push_sym ? (out_acc_bits + 6'd6) : out_acc_bits;
    wire        emit_word     = (acc_bits_next >= 6'd32);
    wire [31:0] emit_data     = acc_next[acc_bits_next - 1 -: 32];
    wire        emit_last     = (out_word_cnt == (WORDS_PER_FRAME - 1));

    assign output_done = (out_word_cnt == 4'd0) && (out_acc_bits == 6'd0) && !sym_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            sym_valid    <= 1'b0;
            sym_data     <= 6'd0;
            out_acc      <= 64'd0;
            out_acc_bits <= 6'd0;
            out_word_cnt <= 4'd0;
        end
        else begin
            sym_valid <= (state_reg == STATE_READOUT) && pipe_valid;
            if ((state_reg == STATE_READOUT) && pipe_valid)
                sym_data <= {sys_dout, par1_dout, par2_dout};

            out_acc      <= acc_next;
            out_acc_bits <= acc_bits_next;

            if (emit_word) begin
                out_acc_bits <= acc_bits_next - 6'd32;
                out_word_cnt <= emit_last ? 4'd0 : (out_word_cnt + 1'b1);
            end
        end
    end

    // ------------------------------------------------------------------
    // 2. XILINX OUTPUT FIFO INSTANTIATION
    // ------------------------------------------------------------------
    assign out_fifo_s_axis_tdata  = emit_data;
    assign out_fifo_s_axis_tvalid = emit_word;
    assign out_fifo_s_axis_tlast  = emit_last;

    axis_data_fifo_1 U_OUTPUT_FIFO (
        .s_axis_aclk        (clk),
        .s_axis_aresetn     (rst_n),

        .s_axis_tdata       (out_fifo_s_axis_tdata),
        .s_axis_tvalid      (out_fifo_s_axis_tvalid),
        .s_axis_tlast       (out_fifo_s_axis_tlast),
        .s_axis_tready      (out_fifo_s_axis_tready),

        .m_axis_tdata       (m_axis_tdata),
        .m_axis_tvalid      (m_axis_tvalid),
        .m_axis_tlast       (m_axis_tlast),
        .m_axis_tready      (m_axis_tready),

        .axis_rd_data_count (out_fifo_count)
    );

    // ------------------------------------------------------------------
    // Core Encoder FSM & Muxes
    // ------------------------------------------------------------------
    always @(*) begin
        // Encoder Input Muxing
        case (state_reg)
            STATE_PASS1, STATE_PASS2, STATE_PASS2_TAIL: begin
                ce_enable = pipe_valid;
                ce_a = sys_dout[1]; // Read from RAM now, not current_couple!
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

    always @(*) begin
        // Sys RAM write logic (Only active during LOAD state)
        sys_we    = couple_valid;
        sys_waddr = count;
        sys_din   = current_couple;

        // Sys RAM read logic
        case (state_reg)
            STATE_PASS1, STATE_PASS2, STATE_PASS2_TAIL,
            STATE_READOUT, STATE_READOUT_TAIL:
                sys_raddr = count; // Natural order read
            STATE_PASS3, STATE_PASS3_TAIL,
            STATE_PASS4, STATE_PASS4_TAIL:
                sys_raddr = arp_int_addr; // Interleaved order read
            default:
                sys_raddr = {ADDR_WIDTH{1'b0}};
        endcase

        // Parity RAM logic
        par1_we    = ((state_reg == STATE_PASS2) || (state_reg == STATE_PASS2_TAIL)) && pipe_valid;
        par1_waddr = par_count;
        par1_din   = {ce_y, ce_w};
        par1_raddr = count;

        par2_we    = ((state_reg == STATE_PASS4) || (state_reg == STATE_PASS4_TAIL)) && pipe_valid;
        par2_waddr = par_count;
        par2_din   = {ce_y, ce_w};
        par2_raddr = count;
    end

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
            
            shift_reg     <= 32'd0;
            word_bit_cnt  <= 4'd0;
            couple_valid  <= 1'b0;
        end
        else begin
            ce_load_init <= 1'b0;
            arp_start    <= 1'b0;

            case (state_reg)
                STATE_IDLE: begin
                    count        <= {ADDR_WIDTH{1'b0}};
                    par_count    <= {ADDR_WIDTH{1'b0}};
                    pipe_valid   <= 1'b0;
                    word_bit_cnt <= 4'd0;

                    // Start LOAD if FIFO has data and output has room
                    if (fifo_m_axis_tvalid && fifo_m_axis_tready) begin
                        shift_reg    <= fifo_m_axis_tdata;
                        couple_valid <= 1'b1;
                        state_reg    <= STATE_LOAD;
                    end else begin
                        couple_valid <= 1'b0;
                    end
                end

                STATE_LOAD: begin
                    couple_valid <= 1'b1;
                    
                    if (count == N_MINUS_1) begin
                        // Done loading frame -> go to Pass 1
                        state_reg    <= STATE_PASS1;
                        couple_valid <= 1'b0;
                        count        <= {ADDR_WIDTH{1'b0}};
                    end
                    else if (word_bit_cnt == 4'd15) begin
                        if (fifo_m_axis_tvalid && fifo_m_axis_tready) begin
                            shift_reg    <= fifo_m_axis_tdata;
                            word_bit_cnt <= 4'd0;
                            count        <= count + 1'b1;
                        end else begin
                            state_reg    <= STATE_LOAD_RELOAD;
                            couple_valid <= 1'b0;
                        end
                    end
                    else begin
                        shift_reg    <= {2'b00, shift_reg[31:2]};
                        word_bit_cnt <= word_bit_cnt + 1'b1;
                        count        <= count + 1'b1;
                    end
                end

                STATE_LOAD_RELOAD: begin
                    if (fifo_m_axis_tvalid && fifo_m_axis_tready) begin
                        shift_reg    <= fifo_m_axis_tdata;
                        word_bit_cnt <= 4'd0;
                        count        <= count + 1'b1;
                        couple_valid <= 1'b1;
                        state_reg    <= STATE_LOAD;
                    end else begin
                        couple_valid <= 1'b0;
                    end
                end

                STATE_PASS1: begin
                    pipe_valid <= 1'b1;
                    count      <= count + 1'b1;
                    if (count == N_VAL) state_reg <= STATE_PASS1_TAIL;
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
                    if (pipe_valid) par_count <= par_count + 1'b1;
                    if (count == N_VAL) state_reg <= STATE_PASS2_TAIL;
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
                    pipe_valid <= 1'b1;
                    count      <= count + 1'b1;
                    if (count == N_VAL) begin
                        ce_load_init  <= 1'b1;
                        ce_init_state <= 4'd0;
                        state_reg     <= STATE_READOUT_TAIL;
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