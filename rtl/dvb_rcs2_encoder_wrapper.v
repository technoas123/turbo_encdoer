`timescale 1ns / 1ps

module dvb_rcs2_encoder_wrapper (
    input  wire        aclk,
    input  wire        aresetn,

    // Configuration Interface
    input  wire [5:0]  cfg_waveform_id,
    input  wire        cfg_valid,

    // AXI4-Stream Slave Interface (Input)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // AXI4-Stream Master Interface (Output)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // Internal signals between Input FIFO and Encoder
    wire [31:0] enc_s_axis_tdata;
    wire        enc_s_axis_tvalid;
    wire        enc_s_axis_tready;
    wire        enc_s_axis_tlast;

    // Internal signals between Encoder and Output FIFO
    wire [31:0] enc_m_axis_tdata;
    wire        enc_m_axis_tvalid;
    wire        enc_m_axis_tready;
    wire        enc_m_axis_tlast;

    // Input FIFO (AXI4-Stream Data FIFO IP)
    axis_data_fifo_0 input_fifo (
        .s_axis_aresetn (aresetn),
        .s_axis_aclk    (aclk),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tlast   (s_axis_tlast),
        
        .m_axis_tvalid  (enc_s_axis_tvalid),
        .m_axis_tready  (enc_s_axis_tready),
        .m_axis_tdata   (enc_s_axis_tdata),
        .m_axis_tlast   (enc_s_axis_tlast)
    );

    // Core Turbo Encoder Top
    turbo_encoder_top encoder_core (
        .clk             (aclk),
        .rst_n           (aresetn),
        
        .cfg_waveform_id (cfg_waveform_id),
        .cfg_valid       (cfg_valid),

        .s_axis_tdata    (enc_s_axis_tdata),
        .s_axis_tvalid   (enc_s_axis_tvalid),
        .s_axis_tready   (enc_s_axis_tready),
        .s_axis_tlast    (enc_s_axis_tlast),

        .m_axis_tdata    (enc_m_axis_tdata),
        .m_axis_tvalid   (enc_m_axis_tvalid),
        .m_axis_tready   (enc_m_axis_tready),
        .m_axis_tlast    (enc_m_axis_tlast)
    );

    // Output FIFO (AXI4-Stream Data FIFO IP)
    axis_data_fifo_1 output_fifo (
        .s_axis_aresetn (aresetn),
        .s_axis_aclk    (aclk),
        .s_axis_tvalid  (enc_m_axis_tvalid),
        .s_axis_tready  (enc_m_axis_tready),
        .s_axis_tdata   (enc_m_axis_tdata),
        .s_axis_tlast   (enc_m_axis_tlast),
        
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tlast   (m_axis_tlast)
    );

endmodule