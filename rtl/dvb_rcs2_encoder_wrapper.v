// dvb_rcs2_encoder_wrapper.v
// Top-Level AXI4-Stream Wrapper for DVB-RCS2 Turbo Encoder

`timescale 1ns / 1ps

module dvb_rcs2_encoder_wrapper (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [5:0]  cfg_wave_id,     // Waveform ID (1..22, 32..49)
    // AXI4-Stream Slave (Input Payload Data)
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tlast,
    // AXI4-Stream Master (Encoded & Punctured Data)
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tlast
);

    // Instantiate Turbo Encoder Top Core
    turbo_encoder_top u_encoder (
        .clk             (aclk),
        .rst_n           (aresetn),
        .cfg_waveform_id (cfg_wave_id),
        .cfg_valid       (1'b1),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tlast    (s_axis_tlast),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tlast    (m_axis_tlast)
    );

endmodule