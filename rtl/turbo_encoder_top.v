`timescale 1ns / 1ps

module turbo_encoder_top #(
    parameter MAX_N = 2396
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [5:0]  cfg_waveform_id,
    input  wire        cfg_valid,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output reg         s_axis_tready,
    input  wire        s_axis_tlast,
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast
);

    localparam STATE_IDLE         = 4'd0;
    localparam STATE_LOAD         = 4'd1;
    localparam STATE_CIRC_STATE1  = 4'd2;
    localparam STATE_ENCODE1      = 4'd3;
    localparam STATE_ARP_RESET2A  = 4'd4;
    localparam STATE_CIRC_STATE2  = 4'd5;
    localparam STATE_ARP_RESET2B  = 4'd6;
    localparam STATE_ENCODE2      = 4'd7;
    localparam STATE_UNLOAD       = 4'd8;

    reg [3:0]  state;
    reg [11:0] enc_cnt;

    wire [11:0] arp_interleaved_addr;
    wire        arp_swap;

    //--------------------------------------------------------------------------
    // Per-waveform profile
    //--------------------------------------------------------------------------
    wire [11:0] rom_N, rom_Np1, rom_Np2, rom_P;
    wire [11:0] rom_qt0, rom_qt1, rom_qt2, rom_qt3;
    wire [3:0]  rom_R15;

    profile_lookup_rom profile_rom_inst (
        .waveform_id (cfg_waveform_id),
        .cfg_N   (rom_N),
        .cfg_P   (rom_P),
        .cfg_Np1 (rom_Np1),
        .cfg_Np2 (rom_Np2),
        .cfg_R15 (rom_R15),
        .cfg_qt0 (rom_qt0),
        .cfg_qt1 (rom_qt1),
        .cfg_qt2 (rom_qt2),
        .cfg_qt3 (rom_qt3)
    );

    //--------------------------------------------------------------------------
    // Active configuration (latched in IDLE when cfg_valid is high)
    //--------------------------------------------------------------------------
    reg [11:0] active_N_reg, active_P_reg, active_Np1_reg, active_Np2_reg;
    reg [11:0] active_qt0_reg, active_qt1_reg, active_qt2_reg, active_qt3_reg;
    reg [3:0]  active_r_reg;

    wire [11:0] active_N   = active_N_reg;
    wire [11:0] active_P   = active_P_reg;
    wire [11:0] active_Np1 = active_Np1_reg;
    wire [11:0] active_Np2 = active_Np2_reg;
    wire [11:0] active_qt0 = active_qt0_reg;
    wire [11:0] active_qt1 = active_qt1_reg;
    wire [11:0] active_qt2 = active_qt2_reg;
    wire [11:0] active_qt3 = active_qt3_reg;
    wire [3:0]  active_r   = active_r_reg;

    //--------------------------------------------------------------------------
    // Memories (registered read, one-cycle latency, BRAM-compatible)
    // sys_raddr is the only combinational address: ARP index in pass 2.
    //--------------------------------------------------------------------------
    wire is_pass2 = (state == STATE_CIRC_STATE2) || (state == STATE_ENCODE2);

    reg  [11:0] sys_addr_a;   wire [1:0] sys_wr_data;  reg        sys_we;
    reg  [11:0] sys_addr_b;   wire [1:0] sys_rd_data;
    wire [11:0] sys_raddr = is_pass2 ? arp_interleaved_addr : sys_addr_b;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(12)) sys_ram (
        .clk(clk), .we(sys_we), .waddr(sys_addr_a), .din(sys_wr_data),
        .raddr(sys_raddr), .dout(sys_rd_data)
    );

    reg  [11:0] par1_addr_a;  wire [1:0] par1_wr_data; reg        par1_we;
    reg  [11:0] par1_addr_b;  wire [1:0] par1_rd_data;
    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(12)) par1_ram (
        .clk(clk), .we(par1_we), .waddr(par1_addr_a), .din(par1_wr_data),
        .raddr(par1_addr_b), .dout(par1_rd_data)
    );

    reg  [11:0] par2_addr_a;  wire [1:0] par2_wr_data; reg        par2_we;
    reg  [11:0] par2_addr_b;  wire [1:0] par2_rd_data;
    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(12)) par2_ram (
        .clk(clk), .we(par2_we), .waddr(par2_addr_a), .din(par2_wr_data),
        .raddr(par2_addr_b), .dout(par2_rd_data)
    );

    //--------------------------------------------------------------------------
    // ARP interleaver
    //--------------------------------------------------------------------------
    reg arp_start, arp_step;

    arp_interleaver arp_inst (
        .clk(clk), .rst_n(rst_n), .start(arp_start), .step(arp_step),
        .cfg_N(active_N), .cfg_P(active_P),
        .cfg_qt0(active_qt0), .cfg_qt1(active_qt1),
        .cfg_qt2(active_qt2), .cfg_qt3(active_qt3),
        .int_addr(arp_interleaved_addr), .swap_bits(arp_swap)
    );

    //--------------------------------------------------------------------------
    // Constituent encoder
    //--------------------------------------------------------------------------
    reg        enc_load_init;
    reg  [3:0] enc_s_init;
    reg        enc_enable;
    wire [1:0] enc_couple_in;
    wire       enc_y, enc_w;
    wire [3:0] enc_s_final;

    // Registered RAM data in both passes. In pass 2 the ARP index runs one
    // cycle ahead of the encoder (see CIRC_STATE2 / ENCODE2), so the data
    // and the swap bit arrive in the same cycle as before.
    wire [1:0] enc_data = sys_rd_data;

    reg arp_swap_d1;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) arp_swap_d1 <= 1'b0;
        else        arp_swap_d1 <= arp_swap;

    wire enc_swap = is_pass2 ? arp_swap_d1 : 1'b0;

    assign enc_couple_in = enc_swap ? {enc_data[0], enc_data[1]} : enc_data;

    constituent_encoder rsc_enc (
        .clk(clk), .rst_n(rst_n),
        .load_init(enc_load_init), .init_state(enc_s_init), .enable(enc_enable),
        .a(enc_couple_in[1]), .b(enc_couple_in[0]),
        .y(enc_y), .w(enc_w), .state_out(enc_s_final)
    );

    reg enc_y_d1, enc_w_d1;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin enc_y_d1 <= 1'b0; enc_w_d1 <= 1'b0; end
        else        begin enc_y_d1 <= enc_y; enc_w_d1 <= enc_w; end

    assign par1_wr_data = {enc_y_d1, enc_w_d1};
    assign par2_wr_data = {enc_y_d1, enc_w_d1};

    //--------------------------------------------------------------------------
    // Circular-state lookup
    //--------------------------------------------------------------------------
    reg  [3:0] s_final_enc1, s_final_enc2;
    wire [3:0] s0_enc1, s0_enc2;

    circular_state_rom circ_rom_1 (.r(active_r), .last_state(s_final_enc1), .circ_state(s0_enc1));
    circular_state_rom circ_rom_2 (.r(active_r), .last_state(s_final_enc2), .circ_state(s0_enc2));

    //--------------------------------------------------------------------------
    // Input shift register
    //--------------------------------------------------------------------------
    reg  [31:0] shift_reg;
    reg  [3:0]  bit_ptr;
    reg  [11:0] in_count;
    reg         load_wait_data;

    wire [1:0] current_in_couple = shift_reg[1:0];
    reg  [1:0] current_in_couple_d1;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) current_in_couple_d1 <= 2'b00;
        else        current_in_couple_d1 <= current_in_couple;
    assign sys_wr_data = current_in_couple_d1;

    //--------------------------------------------------------------------------
    // UNLOAD: issue stage (addresses) and consume stage (packing)
    //--------------------------------------------------------------------------
    reg        unload_issue;     // addresses are being issued
    reg [2:0]  unload_stream;    // 0 sys, 1 par1 Y, 2 par1 W, 3 par2 Y, 4 par2 W
    reg        tag_valid;        // data on RAM outputs belongs to a valid read
    reg [2:0]  tag_stream;
    reg        tag_last;         // this read is the final bit of the frame

    reg [5:0]  pack_count;
    reg [31:0] pack_reg;

    wire [5:0] curr_data_w =
        (tag_stream == 3'd0) ? {4'd0, sys_rd_data}     :
        (tag_stream == 3'd1) ? {5'd0, par1_rd_data[1]} :
        (tag_stream == 3'd2) ? {5'd0, par1_rd_data[0]} :
        (tag_stream == 3'd3) ? {5'd0, par2_rd_data[1]} :
                               {5'd0, par2_rd_data[0]};

    wire [5:0]  curr_bits_w = (tag_stream == 3'd0) ? 6'd2 : 6'd1;
    wire [31:0] cd32       = {26'd0, curr_data_w};
    wire [5:0]  total      = pack_count + curr_bits_w;   // 0..33
    wire [5:0]  n_left     = total - 6'd32;              // valid when total >= 32 (0 or 1)
    wire [31:0] full_word  = pack_reg | (cd32 >> n_left);
    wire [31:0] lo_frag    = cd32 << (6'd32 - n_left);
    wire [5:0]  sh_else    = 6'd32 - total;
    wire [31:0] else_word  = pack_reg | (cd32 << sh_else);

    //--------------------------------------------------------------------------
    // FSM and datapath
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            enc_cnt <= 0;
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tdata  <= 32'd0;
            sys_we <= 0; par1_we <= 0; par2_we <= 0;
            sys_addr_a <= 0; sys_addr_b <= 0;
            par1_addr_a <= 0; par1_addr_b <= 0;
            par2_addr_a <= 0; par2_addr_b <= 0;
            enc_load_init <= 0; enc_s_init <= 0; enc_enable <= 0;
            arp_start <= 0; arp_step <= 0;
            in_count <= 0; bit_ptr <= 0; shift_reg <= 0; load_wait_data <= 0;
            unload_issue <= 0; unload_stream <= 0;
            tag_valid <= 0; tag_stream <= 0; tag_last <= 0;
            pack_reg <= 0; pack_count <= 0;
            s_final_enc1 <= 0; s_final_enc2 <= 0;
            active_N_reg   <= 0; active_P_reg   <= 0;
            active_Np1_reg <= 0; active_Np2_reg <= 0;
            active_qt0_reg <= 0; active_qt1_reg <= 0;
            active_qt2_reg <= 0; active_qt3_reg <= 0;
            active_r_reg   <= 0;
        end else begin
            sys_we <= 0; par1_we <= 0; par2_we <= 0;
            arp_start <= 0; arp_step <= 0;
            enc_load_init <= 0; enc_enable <= 0;

            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
                m_axis_tlast  <= 0;
            end

            case (state)
            STATE_IDLE: begin
                s_axis_tready <= 1; in_count <= 0; bit_ptr <= 0; load_wait_data <= 0;
                enc_cnt <= 0;
                unload_issue <= 0; tag_valid <= 0;
                pack_count <= 0; pack_reg <= 0;
                if (cfg_valid) begin
                    active_N_reg   <= rom_N;    active_P_reg   <= rom_P;
                    active_Np1_reg <= rom_Np1;  active_Np2_reg <= rom_Np2;
                    active_qt0_reg <= rom_qt0;  active_qt1_reg <= rom_qt1;
                    active_qt2_reg <= rom_qt2;  active_qt3_reg <= rom_qt3;
                    active_r_reg   <= rom_R15;
                end
                if (s_axis_tvalid && s_axis_tready) begin
                    shift_reg <= s_axis_tdata; s_axis_tready <= 0;
                    state <= STATE_LOAD;
                end
            end

            STATE_LOAD: begin
                if (load_wait_data) begin
                    if (s_axis_tvalid) begin
                        shift_reg <= s_axis_tdata; s_axis_tready <= 0;
                        load_wait_data <= 0; bit_ptr <= 0;
                    end
                end else if (in_count < active_N) begin
                    sys_addr_a <= in_count; sys_we <= 1; in_count <= in_count + 1;
                    if (bit_ptr == 15) begin
                        if (in_count + 1 < active_N) begin
                            s_axis_tready <= 1; load_wait_data <= 1;
                        end
                    end else begin
                        shift_reg <= {2'b00, shift_reg[31:2]};
                        bit_ptr <= bit_ptr + 1;
                    end
                end else begin
                    s_axis_tready <= 0; enc_cnt <= 0;
                    state <= STATE_CIRC_STATE1;
                end
            end

            // ==================================================================
            // PROBE PASS 1: encode N couples from state 0 to find s_final_enc1
            // ==================================================================
            STATE_CIRC_STATE1: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= 0; sys_addr_b <= 0; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    sys_addr_b <= 0; enc_cnt <= 2;
                end else if (enc_cnt <= active_Np1) begin
                    enc_enable <= 1;
                    if (enc_cnt <= active_N) sys_addr_b <= enc_cnt - 1;
                    enc_cnt <= enc_cnt + 1;
                // FIX A: one idle cycle so the encoder state settles
                end else if (enc_cnt == active_Np2) begin
                    enc_cnt <= enc_cnt + 1;
                end else begin
                    s_final_enc1 <= enc_s_final;
                    enc_cnt <= 0;
                    state <= STATE_ENCODE1;
                end
            end

            // ==================================================================
            // ENCODE PASS 1: from circular state s0_enc1
            // ==================================================================
            STATE_ENCODE1: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= s0_enc1; sys_addr_b <= 0; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    sys_addr_b <= 0; enc_cnt <= 2;
                end else if (enc_cnt <= active_Np2) begin
                    if (enc_cnt <= active_Np1) begin
                        enc_enable <= 1;
                        if (enc_cnt <= active_N) sys_addr_b <= enc_cnt - 1;
                    end
                    if (enc_cnt >= 3) begin
                        par1_addr_a <= enc_cnt - 3;
                        par1_we     <= 1;
                    end
                    enc_cnt <= enc_cnt + 1;
                end else begin
                    arp_start <= 1; enc_cnt <= 0;
                    state <= STATE_ARP_RESET2A;
                end
            end

            STATE_ARP_RESET2A: begin
                enc_cnt <= 0;
                state   <= STATE_CIRC_STATE2;
            end

            // ==================================================================
            // PROBE PASS 2: interleaved order, start state 0
            // ARP steps at enc_cnt 1..N-1 (one cycle earlier than the old
            // comb schedule, to compensate for the registered RAM read).
            // ==================================================================
            STATE_CIRC_STATE2: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= 0; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    enc_cnt  <= 2;
                    arp_step <= 1;
                end else if (enc_cnt <= active_Np1) begin
                    enc_enable <= 1;
                    if (enc_cnt <= active_N - 1) arp_step <= 1;
                    enc_cnt <= enc_cnt + 1;
                // FIX A: same idle cycle as CIRC_STATE1
                end else if (enc_cnt == active_Np2) begin
                    enc_cnt <= enc_cnt + 1;
                end else begin
                    s_final_enc2 <= enc_s_final;
                    arp_start    <= 1;
                    enc_cnt      <= 0;
                    state        <= STATE_ARP_RESET2B;
                end
            end

            STATE_ARP_RESET2B: begin
                enc_cnt <= 0;
                state   <= STATE_ENCODE2;
            end

            // ==================================================================
            // ENCODE PASS 2: from circular state s0_enc2 (same ARP schedule)
            // ==================================================================
            STATE_ENCODE2: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= s0_enc2; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    enc_cnt  <= 2;
                    arp_step <= 1;
                end else if (enc_cnt <= active_Np2) begin
                    if (enc_cnt <= active_Np1) enc_enable <= 1;
                    if (enc_cnt <= active_N - 1) arp_step <= 1;
                    if (enc_cnt >= 3) begin
                        par2_addr_a <= enc_cnt - 3;
                        par2_we     <= 1;
                    end
                    enc_cnt <= enc_cnt + 1;
                end else begin
                    sys_addr_b  <= 0; par1_addr_b <= 0; par2_addr_b <= 0;
                    unload_stream <= 0;
                    unload_issue  <= 1;
                    tag_valid     <= 0;
                    pack_reg <= 0; pack_count <= 0;
                    state <= STATE_UNLOAD;
                end
            end

            // ==================================================================
            // UNLOAD: sys, par1 (Y,W), par2 (Y,W), packed MSB-first to 32 bits
            // ==================================================================
            STATE_UNLOAD: begin
                // ---- Stage 1: issue addresses. sys_addr_b doubles as the index.
                tag_valid  <= unload_issue;
                tag_stream <= unload_stream;
                tag_last   <= unload_issue && (unload_stream == 3'd4) &&
                              (sys_addr_b == active_N - 1);

                if (unload_issue) begin
                    if ((sys_addr_b + 1) < active_N) begin
                        sys_addr_b  <= sys_addr_b + 1;
                        par1_addr_b <= par1_addr_b + 1;
                        par2_addr_b <= par2_addr_b + 1;
                    end else if (unload_stream < 3'd4) begin
                        unload_stream <= unload_stream + 1;
                        sys_addr_b    <= 0;
                        par1_addr_b   <= 0;
                        par2_addr_b   <= 0;
                    end else begin
                        unload_issue <= 0;
                    end
                end

                // ---- Stage 2: consume registered data (one cycle after issue)
                if (tag_valid) begin
                    if (total >= 6'd32) begin
                        m_axis_tdata  <= full_word;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= tag_last && (n_left == 6'd0);
                        if (n_left == 6'd0) begin
                            pack_reg   <= 0;
                            pack_count <= 0;
                        end else begin
                            pack_reg   <= lo_frag;
                            pack_count <= n_left;
                        end
                    end else begin
                        pack_reg   <= else_word;
                        pack_count <= total;
                    end
                end else if (!unload_issue && !m_axis_tvalid) begin
                    // pipeline drained: flush any partial word with tlast
                    if (pack_count > 0) begin
                        m_axis_tdata  <= pack_reg;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                        pack_reg      <= 0;
                        pack_count    <= 0;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end
            end

            default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule