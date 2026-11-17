// profile_lookup_rom.v
// ETSI EN 301 545-2 Table A-1 Reference Waveform Lookup ROM
// N is the number of 2-bit couples (N_couples = Payload_Bytes * 4)

`timescale 1ns / 1ps

module profile_lookup_rom (
    input  wire [5:0]  waveform_id,
    output reg  [11:0] cfg_N,
    output reg  [11:0] cfg_P,
    output reg  [11:0] cfg_Np1,
    output reg  [11:0] cfg_Np2,
    output reg  [3:0]  cfg_R15,
    output reg  [11:0] cfg_qt0,
    output reg  [11:0] cfg_qt1,
    output reg  [11:0] cfg_qt2,
    output reg  [11:0] cfg_qt3,
    output reg  [2:0]  cfg_rate_code    // 0:1/3, 1:1/2, 2:2/3, 3:3/4, 4:4/5, 5:5/6, 6:6/7, 7:7/8
);

    always @(*) begin
        case (waveform_id)
            // Page 241
            6'd1:  begin cfg_N=12'd152;  cfg_P=12'd17; cfg_Np1=12'd153; cfg_Np2=12'd154; cfg_R15=4'd2;  cfg_qt0=12'd9;  cfg_qt1=12'd5;  cfg_qt2=12'd14; cfg_qt3=12'd1; cfg_rate_code=3'd0; end
            6'd2:  begin cfg_N=12'd56;   cfg_P=12'd9;  cfg_Np1=12'd57;  cfg_Np2=12'd58;  cfg_R15=4'd11; cfg_qt0=12'd2;  cfg_qt1=12'd2;  cfg_qt2=12'd8;  cfg_qt3=12'd0; cfg_rate_code=3'd0; end
            6'd3:  begin cfg_N=12'd152;  cfg_P=12'd17; cfg_Np1=12'd153; cfg_Np2=12'd154; cfg_R15=4'd2;  cfg_qt0=12'd9;  cfg_qt1=12'd5;  cfg_qt2=12'd14; cfg_qt3=12'd1; cfg_rate_code=3'd0; end
            6'd4:  begin cfg_N=12'd236;  cfg_P=12'd23; cfg_Np1=12'd237; cfg_Np2=12'd238; cfg_R15=4'd11; cfg_qt0=12'd10; cfg_qt1=12'd2;  cfg_qt2=12'd11; cfg_qt3=12'd1; cfg_rate_code=3'd1; end
            6'd5:  begin cfg_N=12'd340;  cfg_P=12'd23; cfg_Np1=12'd341; cfg_Np2=12'd342; cfg_R15=4'd10; cfg_qt0=12'd6;  cfg_qt1=12'd13; cfg_qt2=12'd10; cfg_qt3=12'd0; cfg_rate_code=3'd2; end
            6'd6:  begin cfg_N=12'd384;  cfg_P=12'd25; cfg_Np1=12'd385; cfg_Np2=12'd386; cfg_R15=4'd9;  cfg_qt0=12'd1;  cfg_qt1=12'd2;  cfg_qt2=12'd0;  cfg_qt3=12'd1; cfg_rate_code=3'd3; end
            6'd7:  begin cfg_N=12'd432;  cfg_P=12'd29; cfg_Np1=12'd433; cfg_Np2=12'd434; cfg_R15=4'd12; cfg_qt0=12'd1;  cfg_qt1=12'd4;  cfg_qt2=12'd1;  cfg_qt3=12'd1; cfg_rate_code=3'd5; end
            6'd8:  begin cfg_N=12'd460;  cfg_P=12'd29; cfg_Np1=12'd461; cfg_Np2=12'd462; cfg_R15=4'd10; cfg_qt0=12'd6;  cfg_qt1=12'd5;  cfg_qt2=12'd0;  cfg_qt3=12'd0; cfg_rate_code=3'd2; end
            6'd9:  begin cfg_N=12'd520;  cfg_P=12'd31; cfg_Np1=12'd521; cfg_Np2=12'd522; cfg_R15=4'd10; cfg_qt0=12'd0;  cfg_qt1=12'd1;  cfg_qt2=12'd2;  cfg_qt3=12'd0; cfg_rate_code=3'd3; end
            6'd10: begin cfg_N=12'd576;  cfg_P=12'd31; cfg_Np1=12'd577; cfg_Np2=12'd578; cfg_R15=4'd6;  cfg_qt0=12'd0;  cfg_qt1=12'd0;  cfg_qt2=12'd0;  cfg_qt3=12'd0; cfg_rate_code=3'd5; end
            6'd11: begin cfg_N=12'd700;  cfg_P=12'd37; cfg_Np1=12'd701; cfg_Np2=12'd702; cfg_R15=4'd10; cfg_qt0=12'd0;  cfg_qt1=12'd2;  cfg_qt2=12'd0;  cfg_qt3=12'd2; cfg_rate_code=3'd3; end
            6'd12: begin cfg_N=12'd776;  cfg_P=12'd39; cfg_Np1=12'd777; cfg_Np2=12'd778; cfg_R15=4'd11; cfg_qt0=12'd7;  cfg_qt1=12'd0;  cfg_qt2=12'd0;  cfg_qt3=12'd0; cfg_rate_code=3'd5; end
            6'd13: begin cfg_N=12'd492;  cfg_P=12'd31; cfg_Np1=12'd493; cfg_Np2=12'd494; cfg_R15=4'd12; cfg_qt0=12'd0;  cfg_qt1=12'd3;  cfg_qt2=12'd1;  cfg_qt3=12'd0; cfg_rate_code=3'd0; end
            6'd14: begin cfg_N=12'd752;  cfg_P=12'd37; cfg_Np1=12'd753; cfg_Np2=12'd754; cfg_R15=4'd2;  cfg_qt0=12'd1;  cfg_qt1=12'd3;  cfg_qt2=12'd4;  cfg_qt3=12'd2; cfg_rate_code=3'd1; end
            6'd15: begin cfg_N=12'd1056; cfg_P=12'd43; cfg_Np1=12'd1057;cfg_Np2=12'd1058;cfg_R15=4'd6;  cfg_qt0=12'd0;  cfg_qt1=12'd0;  cfg_qt2=12'd6;  cfg_qt3=12'd2; cfg_rate_code=3'd2; end
            6'd16: begin cfg_N=12'd1192; cfg_P=12'd49; cfg_Np1=12'd1193;cfg_Np2=12'd1194;cfg_R15=4'd7;  cfg_qt0=12'd0;  cfg_qt1=12'd3;  cfg_qt2=12'd5;  cfg_qt3=12'd0; cfg_rate_code=3'd3; end

            // Page 242
            6'd17: begin cfg_N=12'd1332; cfg_P=12'd49; cfg_Np1=12'd1333;cfg_Np2=12'd1334;cfg_R15=4'd12; cfg_qt0=12'd0;  cfg_qt1=12'd5;  cfg_qt2=12'd0;  cfg_qt3=12'd5; cfg_rate_code=3'd5; end
            6'd18: begin cfg_N=12'd1420; cfg_P=12'd53; cfg_Np1=12'd1421;cfg_Np2=12'd1422;cfg_R15=4'd10; cfg_qt0=12'd1;  cfg_qt1=12'd4;  cfg_qt2=12'd6;  cfg_qt3=12'd2; cfg_rate_code=3'd2; end
            6'd19: begin cfg_N=12'd1600; cfg_P=12'd53; cfg_Np1=12'd1601;cfg_Np2=12'd1602;cfg_R15=4'd10; cfg_qt0=12'd1;  cfg_qt1=12'd10; cfg_qt2=12'd7;  cfg_qt3=12'd1; cfg_rate_code=3'd3; end
            6'd20: begin cfg_N=12'd1776; cfg_P=12'd59; cfg_Np1=12'd1777;cfg_Np2=12'd1778;cfg_R15=4'd6;  cfg_qt0=12'd3;  cfg_qt1=12'd8;  cfg_qt2=12'd5;  cfg_qt3=12'd1; cfg_rate_code=3'd5; end
            6'd21: begin cfg_N=12'd2156; cfg_P=12'd65; cfg_Np1=12'd2157;cfg_Np2=12'd2158;cfg_R15=4'd11; cfg_qt0=12'd0;  cfg_qt1=12'd3;  cfg_qt2=12'd7;  cfg_qt3=12'd0; cfg_rate_code=3'd3; end
            6'd22: begin cfg_N=12'd2396; cfg_P=12'd81; cfg_Np1=12'd2397;cfg_Np2=12'd2398;cfg_R15=4'd11; cfg_qt0=12'd1;  cfg_qt1=12'd2;  cfg_qt2=12'd5;  cfg_qt3=12'd2; cfg_rate_code=3'd5; end

            6'd32: begin cfg_N=12'd400;  cfg_P=12'd23; cfg_Np1=12'd401; cfg_Np2=12'd402; cfg_R15=4'd10; cfg_qt0=12'd10; cfg_qt1=12'd8;  cfg_qt2=12'd2;  cfg_qt3=12'd1; cfg_rate_code=3'd1; end
            6'd33: begin cfg_N=12'd400;  cfg_P=12'd23; cfg_Np1=12'd401; cfg_Np2=12'd402; cfg_R15=4'd10; cfg_qt0=12'd10; cfg_qt1=12'd8;  cfg_qt2=12'd2;  cfg_qt3=12'd1; cfg_rate_code=3'd3; end
            6'd34: begin cfg_N=12'd680;  cfg_P=12'd33; cfg_Np1=12'd681; cfg_Np2=12'd682; cfg_R15=4'd5;  cfg_qt0=12'd9;  cfg_qt1=12'd15; cfg_qt2=12'd3;  cfg_qt3=12'd1; cfg_rate_code=3'd1; end
            6'd35: begin cfg_N=12'd680;  cfg_P=12'd33; cfg_Np1=12'd681; cfg_Np2=12'd682; cfg_R15=4'd5;  cfg_qt0=12'd9;  cfg_qt1=12'd15; cfg_qt2=12'd3;  cfg_qt3=12'd1; cfg_rate_code=3'd3; end
            6'd36: begin cfg_N=12'd680;  cfg_P=12'd33; cfg_Np1=12'd681; cfg_Np2=12'd682; cfg_R15=4'd5;  cfg_qt0=12'd9;  cfg_qt1=12'd15; cfg_qt2=12'd3;  cfg_qt3=12'd1; cfg_rate_code=3'd7; end
            6'd37: begin cfg_N=12'd1752; cfg_P=12'd59; cfg_Np1=12'd1753;cfg_Np2=12'd1754;cfg_R15=4'd12; cfg_qt0=12'd1;  cfg_qt1=12'd1;  cfg_qt2=12'd2;  cfg_qt3=12'd1; cfg_rate_code=3'd2; end
            6'd38: begin cfg_N=12'd1752; cfg_P=12'd59; cfg_Np1=12'd1753;cfg_Np2=12'd1754;cfg_R15=4'd12; cfg_qt0=12'd1;  cfg_qt1=12'd1;  cfg_qt2=12'd2;  cfg_qt3=12'd1; cfg_rate_code=3'd4; end
            6'd39: begin cfg_N=12'd1752; cfg_P=12'd59; cfg_Np1=12'd1753;cfg_Np2=12'd1754;cfg_R15=4'd12; cfg_qt0=12'd1;  cfg_qt1=12'd1;  cfg_qt2=12'd2;  cfg_qt3=12'd1; cfg_rate_code=3'd6; end

            // Page 243
            6'd40: begin cfg_N=12'd236;  cfg_P=12'd23; cfg_Np1=12'd237; cfg_Np2=12'd238; cfg_R15=4'd11; cfg_qt0=12'd10; cfg_qt1=12'd2;  cfg_qt2=12'd11; cfg_qt3=12'd1; cfg_rate_code=3'd0; end
            6'd41: begin cfg_N=12'd236;  cfg_P=12'd23; cfg_Np1=12'd237; cfg_Np2=12'd238; cfg_R15=4'd11; cfg_qt0=12'd10; cfg_qt1=12'd2;  cfg_qt2=12'd11; cfg_qt3=12'd1; cfg_rate_code=3'd0; end
            6'd42: begin cfg_N=12'd492;  cfg_P=12'd31; cfg_Np1=12'd493; cfg_Np2=12'd494; cfg_R15=4'd12; cfg_qt0=12'd0;  cfg_qt1=12'd3;  cfg_qt2=12'd1;  cfg_qt3=12'd0; cfg_rate_code=3'd0; end
            6'd43: begin cfg_N=12'd752;  cfg_P=12'd37; cfg_Np1=12'd753; cfg_Np2=12'd754; cfg_R15=4'd2;  cfg_qt0=12'd1;  cfg_qt1=12'd3;  cfg_qt2=12'd4;  cfg_qt3=12'd2; cfg_rate_code=3'd1; end
            6'd44: begin cfg_N=12'd204;  cfg_P=12'd23; cfg_Np1=12'd205; cfg_Np2=12'd206; cfg_R15=4'd9;  cfg_qt0=12'd10; cfg_qt1=12'd5;  cfg_qt2=12'd0;  cfg_qt3=12'd0; cfg_rate_code=3'd5; end
            6'd45: begin cfg_N=12'd220;  cfg_P=12'd23; cfg_Np1=12'd221; cfg_Np2=12'd222; cfg_R15=4'd10; cfg_qt0=12'd6;  cfg_qt1=12'd10; cfg_qt2=12'd4;  cfg_qt3=12'd0; cfg_rate_code=3'd2; end
            6'd46: begin cfg_N=12'd248;  cfg_P=12'd23; cfg_Np1=12'd249; cfg_Np2=12'd250; cfg_R15=4'd8;  cfg_qt0=12'd6;  cfg_qt1=12'd8;  cfg_qt2=12'd1;  cfg_qt3=12'd1; cfg_rate_code=3'd3; end
            6'd47: begin cfg_N=12'd276;  cfg_P=12'd25; cfg_Np1=12'd277; cfg_Np2=12'd278; cfg_R15=4'd6;  cfg_qt0=12'd1;  cfg_qt1=12'd1;  cfg_qt2=12'd2;  cfg_qt3=12'd0; cfg_rate_code=3'd5; end
            6'd48: begin cfg_N=12'd336;  cfg_P=12'd23; cfg_Np1=12'd337; cfg_Np2=12'd338; cfg_R15=4'd6;  cfg_qt0=12'd8;  cfg_qt1=12'd1;  cfg_qt2=12'd4;  cfg_qt3=12'd1; cfg_rate_code=3'd3; end
            6'd49: begin cfg_N=12'd372;  cfg_P=12'd25; cfg_Np1=12'd373; cfg_Np2=12'd374; cfg_R15=4'd12; cfg_qt0=12'd1;  cfg_qt1=12'd7;  cfg_qt2=12'd2;  cfg_qt3=12'd1; cfg_rate_code=3'd5; end

            default: begin cfg_N=12'd152; cfg_P=12'd17; cfg_Np1=12'd153; cfg_Np2=12'd154; cfg_R15=4'd2; cfg_qt0=12'd9; cfg_qt1=12'd5; cfg_qt2=12'd14; cfg_qt3=12'd1; cfg_rate_code=3'd0; end
        endcase
    end
endmodule