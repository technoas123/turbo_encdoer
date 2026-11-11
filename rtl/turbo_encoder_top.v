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
    wire        arp_swap_unused;

    wire [11:0] rom_N, rom_P, rom_Q0, rom_Q1, rom_Q2, rom_Q3;
    profile_lookup_rom profile_rom_inst (
        .waveform_id (cfg_waveform_id),
        .cfg_N(rom_N), .cfg_P(rom_P),
        .cfg_Q0(rom_Q0), .cfg_Q1(rom_Q1), .cfg_Q2(rom_Q2), .cfg_Q3(rom_Q3)
    );

    reg [11:0] active_N_reg, active_P_reg, active_Q0_reg, active_Q1_reg, active_Q2_reg, active_Q3_reg;
    wire [11:0] active_N  = active_N_reg;
    wire [11:0] active_P  = active_P_reg;
    wire [11:0] active_Q0 = active_Q0_reg;
    wire [11:0] active_Q1 = active_Q1_reg;
    wire [11:0] active_Q2 = active_Q2_reg;
    wire [11:0] active_Q3 = active_Q3_reg;

    reg  [11:0] sys_addr_a;   wire [1:0] sys_wr_data;   reg        sys_we;
    reg  [11:0] sys_addr_b;   wire [1:0] sys_rd_data;  wire [1:0] sys_rd_comb;

    wire is_pass2 = (state == STATE_CIRC_STATE2) || (state == STATE_ENCODE2);
    wire [11:0] sys_raddr = is_pass2 ? arp_interleaved_addr : sys_addr_b;

    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(12)) sys_ram (
        .clk(clk), .we(sys_we), .waddr(sys_addr_a), .din(sys_wr_data),
        .raddr(sys_raddr), .dout(sys_rd_data), .dout_comb(sys_rd_comb)
    );

    reg  [11:0] par1_addr_a;  wire [1:0] par1_wr_data;  reg        par1_we;
    reg  [11:0] par1_addr_b;  wire [1:0] par1_rd_data; wire [1:0] par1_rd_comb;
    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(12)) par1_ram (
        .clk(clk), .we(par1_we), .waddr(par1_addr_a), .din(par1_wr_data),
        .raddr(par1_addr_b), .dout(par1_rd_data), .dout_comb(par1_rd_comb)
    );

    reg  [11:0] par2_addr_a;  wire [1:0] par2_wr_data;  reg        par2_we;
    reg  [11:0] par2_addr_b;  wire [1:0] par2_rd_data; wire [1:0] par2_rd_comb;
    ram_sdp #(.DATA_WIDTH(2), .ADDR_WIDTH(12)) par2_ram (
        .clk(clk), .we(par2_we), .waddr(par2_addr_a), .din(par2_wr_data),
        .raddr(par2_addr_b), .dout(par2_rd_data), .dout_comb(par2_rd_comb)
    );

    reg arp_start, arp_step;

    arp_interleaver arp_inst (
        .clk(clk), .rst_n(rst_n), .start(arp_start), .step(arp_step),
        .cfg_N(active_N), .cfg_P(active_P),
        .cfg_Q0(active_Q0), .cfg_Q1(active_Q1), .cfg_Q2(active_Q2), .cfg_Q3(active_Q3),
        .int_addr(arp_interleaved_addr), .swap_bits(arp_swap_unused)
    );

    reg        enc_load_init;
    reg  [3:0] enc_s_init;
    reg        enc_enable;
    wire [1:0] enc_couple_in;
    wire       enc_y, enc_w;
    wire [3:0] enc_s_final;

    wire [1:0] enc_data = is_pass2 ? sys_rd_comb : sys_rd_data;
    wire       enc_swap = is_pass2 ? ~enc_cnt[0] : 1'b0;

    assign enc_couple_in = is_pass2
                           ? (enc_swap ? {enc_data[0], enc_data[1]} : enc_data)
                           : enc_data;

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

    reg  [3:0] s_final_enc1, s_final_enc2;
    wire [3:0] s0_enc1, s0_enc2;
    wire [3:0] active_r = active_N % 15;

    circular_state_rom circ_rom_1 (.r(active_r), .last_state(s_final_enc1), .circ_state(s0_enc1));
    circular_state_rom circ_rom_2 (.r(active_r), .last_state(s_final_enc2), .circ_state(s0_enc2));

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

    reg [2:0]  unload_stream;
    reg [11:0] unload_idx;
    reg        unload_pipe_valid;
    reg        unload_started;

    reg [5:0]  curr_data;
    reg [5:0]  curr_bits;
    reg [5:0]  n_left_comb;
    reg [31:0] pack_reg;
    reg [5:0]  pack_count;

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
            unload_stream <= 0; unload_idx <= 0; unload_pipe_valid <= 0;
            unload_started <= 0;
            curr_data <= 0; curr_bits <= 0; n_left_comb <= 0;
            pack_reg <= 0; pack_count <= 0;
            s_final_enc1 <= 0; s_final_enc2 <= 0;
            active_N_reg <= 0; active_P_reg <= 0;
            active_Q0_reg <= 0; active_Q1_reg <= 0; active_Q2_reg <= 0; active_Q3_reg <= 0;
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
                enc_cnt <= 0; unload_stream <= 0; unload_idx <= 0;
                unload_started <= 0;
                pack_count <= 0; pack_reg <= 0;
                if (cfg_valid) begin
                    active_N_reg <= rom_N; active_P_reg <= rom_P;
                    active_Q0_reg <= rom_Q0; active_Q1_reg <= rom_Q1;
                    active_Q2_reg <= rom_Q2; active_Q3_reg <= rom_Q3;
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
                end else if (enc_cnt <= active_N + 1) begin
                    enc_enable <= 1;
                    if (enc_cnt <= active_N) sys_addr_b <= enc_cnt - 1;
                    enc_cnt <= enc_cnt + 1;
                // ----------------------------------------------------------
                // FIX A: wait one idle cycle for encoder state_reg to settle
                //        after the last enable (enc_cnt == active_N + 1).
                //        Without this, s_final captures S_{N-1} not S_N.
                // ----------------------------------------------------------
                end else if (enc_cnt == active_N + 2) begin
                    enc_cnt <= enc_cnt + 1;
                end else begin
                    s_final_enc1 <= enc_s_final;
                    enc_cnt <= 0;
                    state <= STATE_ENCODE1;
                end
            end

            // ==================================================================
            // ACTUAL ENCODE PASS 1: from circular state s0_enc1
            // ==================================================================
            STATE_ENCODE1: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= s0_enc1; sys_addr_b <= 0; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    sys_addr_b <= 0; enc_cnt <= 2;
                end else if (enc_cnt <= active_N + 2) begin
                    if (enc_cnt <= active_N + 1) begin
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
            // PROBE PASS 2: encode N interleaved couples from state 0
            // ==================================================================
            STATE_CIRC_STATE2: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= 0; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    enc_cnt <= 2;
                end else if (enc_cnt <= active_N + 1) begin
                    enc_enable <= 1;
                    // ------------------------------------------------------
                    // FIX B: arp_step must start at enc_cnt == 2 (not 3).
                    //        Pass 2 uses combinational BRAM read (sys_rd_comb)
                    //        so address and data are in the same cycle.
                    //        Starting at 3 causes π(0) to be read twice and
                    //        π(N-1) to be skipped.
                    // ------------------------------------------------------
                    if (enc_cnt >= 2 && enc_cnt <= active_N) arp_step <= 1;
                    enc_cnt <= enc_cnt + 1;
                // ----------------------------------------------------------
                // FIX A: same idle cycle as CIRC_STATE1
                // ----------------------------------------------------------
                end else if (enc_cnt == active_N + 2) begin
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
            // ACTUAL ENCODE PASS 2: from circular state s0_enc2
            // ==================================================================
            STATE_ENCODE2: begin
                if (enc_cnt == 0) begin
                    enc_load_init <= 1; enc_s_init <= s0_enc2; enc_cnt <= 1;
                end else if (enc_cnt == 1) begin
                    enc_cnt <= 2;
                end else if (enc_cnt <= active_N + 2) begin
                    if (enc_cnt <= active_N + 1) begin
                        enc_enable <= 1;
                        // --------------------------------------------------
                        // FIX B: same arp_step fix as CIRC_STATE2
                        // --------------------------------------------------
                        if (enc_cnt >= 2 && enc_cnt <= active_N) arp_step <= 1;
                    end
                    if (enc_cnt >= 3) begin
                        par2_addr_a <= enc_cnt - 3;
                        par2_we     <= 1;
                    end
                    enc_cnt <= enc_cnt + 1;
                end else begin
                    sys_addr_b <= 0; par1_addr_b <= 0; par2_addr_b <= 0;
                    unload_stream <= 0; unload_idx <= 0;
                    unload_started <= 0;
                    unload_pipe_valid <= 1;
                    pack_reg <= 0; pack_count <= 0;
                    state <= STATE_UNLOAD;
                end
            end

            STATE_UNLOAD: begin
                if (unload_pipe_valid) begin
                    if (!unload_started) begin
                        unload_started <= 1'b1;
                    end else begin
                        case (unload_stream)
                            3'd0: begin curr_data = {4'd0, sys_rd_comb};      curr_bits = 6'd2; end
                            3'd1: begin curr_data = {5'd0, par1_rd_comb[1]};  curr_bits = 6'd1; end
                            3'd2: begin curr_data = {5'd0, par1_rd_comb[0]};  curr_bits = 6'd1; end
                            3'd3: begin curr_data = {5'd0, par2_rd_comb[1]};  curr_bits = 6'd1; end
                            3'd4: begin curr_data = {5'd0, par2_rd_comb[0]};  curr_bits = 6'd1; end
                            default: begin curr_data = 0; curr_bits = 0; end
                        endcase

                        n_left_comb = pack_count + curr_bits - 32;

                        if (pack_count + curr_bits >= 32) begin
                            m_axis_tdata  <= pack_reg | ({26'd0, curr_data} >> n_left_comb);
                            m_axis_tvalid <= 1;
                            m_axis_tlast  <= (unload_stream == 4) &&
                                             (unload_idx + 1 >= active_N) &&
                                             (n_left_comb == 0);
                            if (n_left_comb == 0) begin
                                pack_reg <= 0; pack_count <= 0;
                            end else begin
                                pack_reg   <= {26'd0, curr_data} << (32 - n_left_comb);
                                pack_count <= n_left_comb;
                            end
                        end else begin
                            pack_reg   <= pack_reg | ({26'd0, curr_data} << (32 - curr_bits - pack_count));
                            pack_count <= pack_count + curr_bits;
                        end

                        sys_addr_b  <= unload_idx + 1;
                        par1_addr_b <= unload_idx + 1;
                        par2_addr_b <= unload_idx + 1;

                        if (unload_idx + 1 < active_N) begin
                            unload_idx <= unload_idx + 1;
                        end else begin
                            if (unload_stream < 4) begin
                                unload_stream  <= unload_stream + 1;
                                unload_idx     <= 0;
                                unload_started <= 1'b0;
                                sys_addr_b     <= 0;
                                par1_addr_b    <= 0;
                                par2_addr_b    <= 0;
                            end else begin
                                unload_pipe_valid <= 0;
                            end
                        end
                    end
                end else if (!m_axis_tvalid) begin
                    if (pack_count > 0) begin
                        m_axis_tdata  <= pack_reg;
                        m_axis_tvalid <= 1;
                        m_axis_tlast  <= 1;
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