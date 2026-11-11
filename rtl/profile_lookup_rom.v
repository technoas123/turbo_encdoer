`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: profile_lookup_rom
// Description: Pure combinational Lookup Table for ETSI EN 301 545-2 Table A-1.
//              Maps waveform_id (0..49) to dynamic configuration parameters.
//              N is in couples (bytes * 4).
//////////////////////////////////////////////////////////////////////////////////

module profile_lookup_rom (
    input  wire [5:0]  waveform_id,
    
    output reg  [11:0] cfg_N,
    output reg  [11:0] cfg_P,
    output reg  [11:0] cfg_Q0,
    output reg  [11:0] cfg_Q1,
    output reg  [11:0] cfg_Q2,
    output reg  [11:0] cfg_Q3
);

    always @(*) begin
        case (waveform_id)
            // -------------------------------------------------------------
            // 0: Legacy / Debug Case (N=48)
            // -------------------------------------------------------------
            6'd0:  begin cfg_N = 12'd48;   cfg_P = 12'd13; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd2;  cfg_Q2 = 12'd4;  cfg_Q3 = 12'd6; end

            // -------------------------------------------------------------
            // WF1 - WF12: Standard Linear Modulation Bursts
            // -------------------------------------------------------------
            6'd1:  begin cfg_N = 12'd152;  cfg_P = 12'd17; cfg_Q0 = 12'd9;  cfg_Q1 = 12'd5;  cfg_Q2 = 12'd14; cfg_Q3 = 12'd1; end
            6'd2:  begin cfg_N = 12'd56;   cfg_P = 12'd9;  cfg_Q0 = 12'd2;  cfg_Q1 = 12'd2;  cfg_Q2 = 12'd8;  cfg_Q3 = 12'd0; end
            6'd3:  begin cfg_N = 12'd152;  cfg_P = 12'd17; cfg_Q0 = 12'd9;  cfg_Q1 = 12'd5;  cfg_Q2 = 12'd14; cfg_Q3 = 12'd1; end
            6'd4:  begin cfg_N = 12'd236;  cfg_P = 12'd23; cfg_Q0 = 12'd10; cfg_Q1 = 12'd2;  cfg_Q2 = 12'd11; cfg_Q3 = 12'd1; end
            6'd5:  begin cfg_N = 12'd340;  cfg_P = 12'd23; cfg_Q0 = 12'd6;  cfg_Q1 = 12'd13; cfg_Q2 = 12'd10; cfg_Q3 = 12'd0; end
            6'd6:  begin cfg_N = 12'd384;  cfg_P = 12'd25; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd2;  cfg_Q2 = 12'd0;  cfg_Q3 = 12'd1; end
            6'd7:  begin cfg_N = 12'd432;  cfg_P = 12'd29; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd4;  cfg_Q2 = 12'd1;  cfg_Q3 = 12'd1; end
            6'd8:  begin cfg_N = 12'd460;  cfg_P = 12'd29; cfg_Q0 = 12'd6;  cfg_Q1 = 12'd5;  cfg_Q2 = 12'd0;  cfg_Q3 = 12'd0; end
            6'd9:  begin cfg_N = 12'd520;  cfg_P = 12'd31; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd1;  cfg_Q2 = 12'd2;  cfg_Q3 = 12'd0; end
            6'd10: begin cfg_N = 12'd576;  cfg_P = 12'd31; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd0;  cfg_Q2 = 12'd0;  cfg_Q3 = 12'd0; end
            6'd11: begin cfg_N = 12'd700;  cfg_P = 12'd37; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd2;  cfg_Q2 = 12'd0;  cfg_Q3 = 12'd2; end
            6'd12: begin cfg_N = 12'd776;  cfg_P = 12'd39; cfg_Q0 = 12'd7;  cfg_Q1 = 12'd0;  cfg_Q2 = 12'd0;  cfg_Q3 = 12'd0; end

            // -------------------------------------------------------------
            // WF13 - WF22: Long Burst Family
            // -------------------------------------------------------------
            6'd13: begin cfg_N = 12'd492;  cfg_P = 12'd31; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd3;  cfg_Q2 = 12'd1;  cfg_Q3 = 12'd0; end
            6'd14: begin cfg_N = 12'd752;  cfg_P = 12'd37; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd3;  cfg_Q2 = 12'd4;  cfg_Q3 = 12'd2; end
            6'd15: begin cfg_N = 12'd1056; cfg_P = 12'd43; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd0;  cfg_Q2 = 12'd6;  cfg_Q3 = 12'd2; end
            6'd16: begin cfg_N = 12'd1192; cfg_P = 12'd49; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd3;  cfg_Q2 = 12'd5;  cfg_Q3 = 12'd0; end
            6'd17: begin cfg_N = 12'd1332; cfg_P = 12'd49; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd5;  cfg_Q2 = 12'd0;  cfg_Q3 = 12'd5; end
            6'd18: begin cfg_N = 12'd1420; cfg_P = 12'd53; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd4;  cfg_Q2 = 12'd6;  cfg_Q3 = 12'd2; end
            6'd19: begin cfg_N = 12'd1600; cfg_P = 12'd53; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd10; cfg_Q2 = 12'd7;  cfg_Q3 = 12'd1; end
            6'd20: begin cfg_N = 12'd1776; cfg_P = 12'd59; cfg_Q0 = 12'd3;  cfg_Q1 = 12'd8;  cfg_Q2 = 12'd5;  cfg_Q3 = 12'd1; end
            6'd21: begin cfg_N = 12'd2156; cfg_P = 12'd65; cfg_Q0 = 12'd0;  cfg_Q1 = 12'd3;  cfg_Q2 = 12'd7;  cfg_Q3 = 12'd0; end
            6'd22: begin cfg_N = 12'd2396; cfg_P = 12'd81; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd2;  cfg_Q2 = 12'd5;  cfg_Q3 = 12'd2; end

            // -------------------------------------------------------------
            // WF23 - WF31: Reserved / Extended
            // -------------------------------------------------------------
            6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29, 6'd30, 6'd31: begin 
                cfg_N = 12'd200; cfg_P = 12'd23; cfg_Q0 = 12'd10; cfg_Q1 = 12'd2; cfg_Q2 = 12'd11; cfg_Q3 = 12'd1; 
            end

            // -------------------------------------------------------------
            // WF32 - WF39: Short / CSC / Spread Bursts (Pilotless)
            // -------------------------------------------------------------
            6'd32, 6'd33: begin 
                cfg_N = 12'd400; cfg_P = 12'd23; cfg_Q0 = 12'd10; cfg_Q1 = 12'd8; cfg_Q2 = 12'd2; cfg_Q3 = 12'd1; 
            end
            6'd34, 6'd35, 6'd36: begin 
                cfg_N = 12'd680; cfg_P = 12'd33; cfg_Q0 = 12'd9; cfg_Q1 = 12'd15; cfg_Q2 = 12'd3; cfg_Q3 = 12'd1; 
            end
            6'd37, 6'd38, 6'd39: begin 
                cfg_N = 12'd1752; cfg_P = 12'd59; cfg_Q0 = 12'd1; cfg_Q1 = 12'd1; cfg_Q2 = 12'd2; cfg_Q3 = 12'd1; 
            end

            // -------------------------------------------------------------
            // WF40 - WF43: BPSK Low-Rate Family
            // -------------------------------------------------------------
            6'd40, 6'd41: begin 
                cfg_N = 12'd236; cfg_P = 12'd23; cfg_Q0 = 12'd10; cfg_Q1 = 12'd2; cfg_Q2 = 12'd11; cfg_Q3 = 12'd1; 
            end
            6'd42: begin cfg_N = 12'd492; cfg_P = 12'd31; cfg_Q0 = 12'd0; cfg_Q1 = 12'd3; cfg_Q2 = 12'd1; cfg_Q3 = 12'd0; end
            6'd43: begin cfg_N = 12'd752; cfg_P = 12'd37; cfg_Q0 = 12'd1; cfg_Q1 = 12'd3; cfg_Q2 = 12'd4; cfg_Q3 = 12'd2; end

            // -------------------------------------------------------------
            // WF44 - WF49: Short High-Rate / High-Mod Family
            // -------------------------------------------------------------
            6'd44: begin cfg_N = 12'd204; cfg_P = 12'd23; cfg_Q0 = 12'd10; cfg_Q1 = 12'd5;  cfg_Q2 = 12'd0; cfg_Q3 = 12'd0; end
            6'd45: begin cfg_N = 12'd220; cfg_P = 12'd23; cfg_Q0 = 12'd6;  cfg_Q1 = 12'd10; cfg_Q2 = 12'd4; cfg_Q3 = 12'd0; end
            6'd46: begin cfg_N = 12'd248; cfg_P = 12'd23; cfg_Q0 = 12'd6;  cfg_Q1 = 12'd8;  cfg_Q2 = 12'd1; cfg_Q3 = 12'd1; end
            6'd47: begin cfg_N = 12'd276; cfg_P = 12'd25; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd1;  cfg_Q2 = 12'd2; cfg_Q3 = 12'd0; end
            6'd48: begin cfg_N = 12'd336; cfg_P = 12'd23; cfg_Q0 = 12'd8;  cfg_Q1 = 12'd1;  cfg_Q2 = 12'd4; cfg_Q3 = 12'd1; end
            6'd49: begin cfg_N = 12'd372; cfg_P = 12'd25; cfg_Q0 = 12'd1;  cfg_Q1 = 12'd7;  cfg_Q2 = 12'd2; cfg_Q3 = 12'd1; end

            // Fallback
            default: begin cfg_N = 12'd48; cfg_P = 12'd13; cfg_Q0 = 12'd0; cfg_Q1 = 12'd2; cfg_Q2 = 12'd4; cfg_Q3 = 12'd6; end
        endcase
    end

endmodule