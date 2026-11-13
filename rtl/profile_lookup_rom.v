`timescale 1ns / 1ps
//==============================================================================
// Per-waveform profile table, ETSI EN 301 545-2 Table A-1
//
// Outputs for each waveform ID:
//   cfg_N    block length in couples
//   cfg_P    ARP step
//   cfg_Np1  N + 1          (FSM comparisons)
//   cfg_Np2  N + 2          (FSM comparisons)
//   cfg_R15  N mod 15       (index for circular_state_rom)
//   cfg_qt0  3 mod N
//   cfg_qt1  (4*Q1 + 3) mod N
//   cfg_qt2  (4*Q0*P + 4*Q2 + 3) mod N
//   cfg_qt3  (4*Q0*P + 4*Q3 + 3) mod N
//
// The derived fields are written as constant expressions. Synthesis folds
// them to constants, so there is no run-time multiplier or divider.
//==============================================================================

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
    output reg  [11:0] cfg_qt3
);

    always @(*) begin
        case (waveform_id)
            // 0: Legacy / Debug (N=48, P=13, Q0=0, Q1=2, Q2=4, Q3=6)
            6'd0:  begin
                cfg_N = 48; cfg_P = 13; cfg_Np1 = 48+1; cfg_Np2 = 48+2; cfg_R15 = 48 % 15;
                cfg_qt0 = 3 % 48; cfg_qt1 = (4*2+3) % 48;
                cfg_qt2 = (4*0*13 + 4*4 + 3) % 48; cfg_qt3 = (4*0*13 + 4*6 + 3) % 48;
            end

            // WF1 - WF12: Standard Linear Modulation Bursts
            6'd1:  begin
                cfg_N = 152; cfg_P = 17; cfg_Np1 = 152+1; cfg_Np2 = 152+2; cfg_R15 = 152 % 15;
                cfg_qt0 = 3 % 152; cfg_qt1 = (4*5+3) % 152;
                cfg_qt2 = (4*9*17 + 4*14 + 3) % 152; cfg_qt3 = (4*9*17 + 4*1 + 3) % 152;
            end
            6'd2:  begin
                cfg_N = 56; cfg_P = 9; cfg_Np1 = 56+1; cfg_Np2 = 56+2; cfg_R15 = 56 % 15;
                cfg_qt0 = 3 % 56; cfg_qt1 = (4*2+3) % 56;
                cfg_qt2 = (4*2*9 + 4*8 + 3) % 56; cfg_qt3 = (4*2*9 + 4*0 + 3) % 56;
            end
            6'd3:  begin
                cfg_N = 152; cfg_P = 17; cfg_Np1 = 152+1; cfg_Np2 = 152+2; cfg_R15 = 152 % 15;
                cfg_qt0 = 3 % 152; cfg_qt1 = (4*5+3) % 152;
                cfg_qt2 = (4*9*17 + 4*14 + 3) % 152; cfg_qt3 = (4*9*17 + 4*1 + 3) % 152;
            end
            6'd4:  begin
                cfg_N = 236; cfg_P = 23; cfg_Np1 = 236+1; cfg_Np2 = 236+2; cfg_R15 = 236 % 15;
                cfg_qt0 = 3 % 236; cfg_qt1 = (4*2+3) % 236;
                cfg_qt2 = (4*10*23 + 4*11 + 3) % 236; cfg_qt3 = (4*10*23 + 4*1 + 3) % 236;
            end
            6'd5:  begin
                cfg_N = 340; cfg_P = 23; cfg_Np1 = 340+1; cfg_Np2 = 340+2; cfg_R15 = 340 % 15;
                cfg_qt0 = 3 % 340; cfg_qt1 = (4*13+3) % 340;
                cfg_qt2 = (4*6*23 + 4*10 + 3) % 340; cfg_qt3 = (4*6*23 + 4*0 + 3) % 340;
            end
            6'd6:  begin
                cfg_N = 384; cfg_P = 25; cfg_Np1 = 384+1; cfg_Np2 = 384+2; cfg_R15 = 384 % 15;
                cfg_qt0 = 3 % 384; cfg_qt1 = (4*2+3) % 384;
                cfg_qt2 = (4*1*25 + 4*0 + 3) % 384; cfg_qt3 = (4*1*25 + 4*1 + 3) % 384;
            end
            6'd7:  begin
                cfg_N = 432; cfg_P = 29; cfg_Np1 = 432+1; cfg_Np2 = 432+2; cfg_R15 = 432 % 15;
                cfg_qt0 = 3 % 432; cfg_qt1 = (4*4+3) % 432;
                cfg_qt2 = (4*1*29 + 4*1 + 3) % 432; cfg_qt3 = (4*1*29 + 4*1 + 3) % 432;
            end
            6'd8:  begin
                cfg_N = 460; cfg_P = 29; cfg_Np1 = 460+1; cfg_Np2 = 460+2; cfg_R15 = 460 % 15;
                cfg_qt0 = 3 % 460; cfg_qt1 = (4*5+3) % 460;
                cfg_qt2 = (4*6*29 + 4*0 + 3) % 460; cfg_qt3 = (4*6*29 + 4*0 + 3) % 460;
            end
            6'd9:  begin
                cfg_N = 520; cfg_P = 31; cfg_Np1 = 520+1; cfg_Np2 = 520+2; cfg_R15 = 520 % 15;
                cfg_qt0 = 3 % 520; cfg_qt1 = (4*1+3) % 520;
                cfg_qt2 = (4*0*31 + 4*2 + 3) % 520; cfg_qt3 = (4*0*31 + 4*0 + 3) % 520;
            end
            6'd10: begin
                cfg_N = 576; cfg_P = 31; cfg_Np1 = 576+1; cfg_Np2 = 576+2; cfg_R15 = 576 % 15;
                cfg_qt0 = 3 % 576; cfg_qt1 = (4*0+3) % 576;
                cfg_qt2 = (4*0*31 + 4*0 + 3) % 576; cfg_qt3 = (4*0*31 + 4*0 + 3) % 576;
            end
            6'd11: begin
                cfg_N = 700; cfg_P = 37; cfg_Np1 = 700+1; cfg_Np2 = 700+2; cfg_R15 = 700 % 15;
                cfg_qt0 = 3 % 700; cfg_qt1 = (4*2+3) % 700;
                cfg_qt2 = (4*0*37 + 4*0 + 3) % 700; cfg_qt3 = (4*0*37 + 4*2 + 3) % 700;
            end
            6'd12: begin
                cfg_N = 776; cfg_P = 39; cfg_Np1 = 776+1; cfg_Np2 = 776+2; cfg_R15 = 776 % 15;
                cfg_qt0 = 3 % 776; cfg_qt1 = (4*0+3) % 776;
                cfg_qt2 = (4*7*39 + 4*0 + 3) % 776; cfg_qt3 = (4*7*39 + 4*0 + 3) % 776;
            end

            // WF13 - WF22: Long Burst Family
            6'd13: begin
                cfg_N = 492; cfg_P = 31; cfg_Np1 = 492+1; cfg_Np2 = 492+2; cfg_R15 = 492 % 15;
                cfg_qt0 = 3 % 492; cfg_qt1 = (4*3+3) % 492;
                cfg_qt2 = (4*0*31 + 4*1 + 3) % 492; cfg_qt3 = (4*0*31 + 4*0 + 3) % 492;
            end
            6'd14: begin
                cfg_N = 752; cfg_P = 37; cfg_Np1 = 752+1; cfg_Np2 = 752+2; cfg_R15 = 752 % 15;
                cfg_qt0 = 3 % 752; cfg_qt1 = (4*3+3) % 752;
                cfg_qt2 = (4*1*37 + 4*4 + 3) % 752; cfg_qt3 = (4*1*37 + 4*2 + 3) % 752;
            end
            6'd15: begin
                cfg_N = 1056; cfg_P = 43; cfg_Np1 = 1056+1; cfg_Np2 = 1056+2; cfg_R15 = 1056 % 15;
                cfg_qt0 = 3 % 1056; cfg_qt1 = (4*0+3) % 1056;
                cfg_qt2 = (4*0*43 + 4*6 + 3) % 1056; cfg_qt3 = (4*0*43 + 4*2 + 3) % 1056;
            end
            6'd16: begin
                cfg_N = 1192; cfg_P = 49; cfg_Np1 = 1192+1; cfg_Np2 = 1192+2; cfg_R15 = 1192 % 15;
                cfg_qt0 = 3 % 1192; cfg_qt1 = (4*3+3) % 1192;
                cfg_qt2 = (4*0*49 + 4*5 + 3) % 1192; cfg_qt3 = (4*0*49 + 4*0 + 3) % 1192;
            end
            6'd17: begin
                cfg_N = 1332; cfg_P = 49; cfg_Np1 = 1332+1; cfg_Np2 = 1332+2; cfg_R15 = 1332 % 15;
                cfg_qt0 = 3 % 1332; cfg_qt1 = (4*5+3) % 1332;
                cfg_qt2 = (4*0*49 + 4*0 + 3) % 1332; cfg_qt3 = (4*0*49 + 4*5 + 3) % 1332;
            end
            6'd18: begin
                cfg_N = 1420; cfg_P = 53; cfg_Np1 = 1420+1; cfg_Np2 = 1420+2; cfg_R15 = 1420 % 15;
                cfg_qt0 = 3 % 1420; cfg_qt1 = (4*4+3) % 1420;
                cfg_qt2 = (4*1*53 + 4*6 + 3) % 1420; cfg_qt3 = (4*1*53 + 4*2 + 3) % 1420;
            end
            6'd19: begin
                cfg_N = 1600; cfg_P = 53; cfg_Np1 = 1600+1; cfg_Np2 = 1600+2; cfg_R15 = 1600 % 15;
                cfg_qt0 = 3 % 1600; cfg_qt1 = (4*10+3) % 1600;
                cfg_qt2 = (4*1*53 + 4*7 + 3) % 1600; cfg_qt3 = (4*1*53 + 4*1 + 3) % 1600;
            end
            6'd20: begin
                cfg_N = 1776; cfg_P = 59; cfg_Np1 = 1776+1; cfg_Np2 = 1776+2; cfg_R15 = 1776 % 15;
                cfg_qt0 = 3 % 1776; cfg_qt1 = (4*8+3) % 1776;
                cfg_qt2 = (4*3*59 + 4*5 + 3) % 1776; cfg_qt3 = (4*3*59 + 4*1 + 3) % 1776;
            end
            6'd21: begin
                cfg_N = 2156; cfg_P = 65; cfg_Np1 = 2156+1; cfg_Np2 = 2156+2; cfg_R15 = 2156 % 15;
                cfg_qt0 = 3 % 2156; cfg_qt1 = (4*3+3) % 2156;
                cfg_qt2 = (4*0*65 + 4*7 + 3) % 2156; cfg_qt3 = (4*0*65 + 4*0 + 3) % 2156;
            end
            6'd22: begin
                cfg_N = 2396; cfg_P = 81; cfg_Np1 = 2396+1; cfg_Np2 = 2396+2; cfg_R15 = 2396 % 15;
                cfg_qt0 = 3 % 2396; cfg_qt1 = (4*2+3) % 2396;
                cfg_qt2 = (4*1*81 + 4*5 + 3) % 2396; cfg_qt3 = (4*1*81 + 4*2 + 3) % 2396;
            end

            // WF23 - WF31: Reserved / Extended (N=200, P=23, Q=10,2,11,1)
            6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29, 6'd30, 6'd31: begin
                cfg_N = 200; cfg_P = 23; cfg_Np1 = 200+1; cfg_Np2 = 200+2; cfg_R15 = 200 % 15;
                cfg_qt0 = 3 % 200; cfg_qt1 = (4*2+3) % 200;
                cfg_qt2 = (4*10*23 + 4*11 + 3) % 200; cfg_qt3 = (4*10*23 + 4*1 + 3) % 200;
            end

            // WF32 - WF39: Short / CSC / Spread Bursts (Pilotless)
            6'd32, 6'd33: begin
                cfg_N = 400; cfg_P = 23; cfg_Np1 = 400+1; cfg_Np2 = 400+2; cfg_R15 = 400 % 15;
                cfg_qt0 = 3 % 400; cfg_qt1 = (4*8+3) % 400;
                cfg_qt2 = (4*10*23 + 4*2 + 3) % 400; cfg_qt3 = (4*10*23 + 4*1 + 3) % 400;
            end
            6'd34, 6'd35, 6'd36: begin
                cfg_N = 680; cfg_P = 33; cfg_Np1 = 680+1; cfg_Np2 = 680+2; cfg_R15 = 680 % 15;
                cfg_qt0 = 3 % 680; cfg_qt1 = (4*15+3) % 680;
                cfg_qt2 = (4*9*33 + 4*3 + 3) % 680; cfg_qt3 = (4*9*33 + 4*1 + 3) % 680;
            end
            6'd37, 6'd38, 6'd39: begin
                cfg_N = 1752; cfg_P = 59; cfg_Np1 = 1752+1; cfg_Np2 = 1752+2; cfg_R15 = 1752 % 15;
                cfg_qt0 = 3 % 1752; cfg_qt1 = (4*1+3) % 1752;
                cfg_qt2 = (4*1*59 + 4*2 + 3) % 1752; cfg_qt3 = (4*1*59 + 4*1 + 3) % 1752;
            end

            // WF40 - WF43: BPSK Low-Rate Family
            6'd40, 6'd41: begin
                cfg_N = 236; cfg_P = 23; cfg_Np1 = 236+1; cfg_Np2 = 236+2; cfg_R15 = 236 % 15;
                cfg_qt0 = 3 % 236; cfg_qt1 = (4*2+3) % 236;
                cfg_qt2 = (4*10*23 + 4*11 + 3) % 236; cfg_qt3 = (4*10*23 + 4*1 + 3) % 236;
            end
            6'd42: begin
                cfg_N = 492; cfg_P = 31; cfg_Np1 = 492+1; cfg_Np2 = 492+2; cfg_R15 = 492 % 15;
                cfg_qt0 = 3 % 492; cfg_qt1 = (4*3+3) % 492;
                cfg_qt2 = (4*0*31 + 4*1 + 3) % 492; cfg_qt3 = (4*0*31 + 4*0 + 3) % 492;
            end
            6'd43: begin
                cfg_N = 752; cfg_P = 37; cfg_Np1 = 752+1; cfg_Np2 = 752+2; cfg_R15 = 752 % 15;
                cfg_qt0 = 3 % 752; cfg_qt1 = (4*3+3) % 752;
                cfg_qt2 = (4*1*37 + 4*4 + 3) % 752; cfg_qt3 = (4*1*37 + 4*2 + 3) % 752;
            end

            // WF44 - WF49: Short High-Rate / High-Mod Family
            6'd44: begin
                cfg_N = 204; cfg_P = 23; cfg_Np1 = 204+1; cfg_Np2 = 204+2; cfg_R15 = 204 % 15;
                cfg_qt0 = 3 % 204; cfg_qt1 = (4*5+3) % 204;
                cfg_qt2 = (4*10*23 + 4*0 + 3) % 204; cfg_qt3 = (4*10*23 + 4*0 + 3) % 204;
            end
            6'd45: begin
                cfg_N = 220; cfg_P = 23; cfg_Np1 = 220+1; cfg_Np2 = 220+2; cfg_R15 = 220 % 15;
                cfg_qt0 = 3 % 220; cfg_qt1 = (4*10+3) % 220;
                cfg_qt2 = (4*6*23 + 4*4 + 3) % 220; cfg_qt3 = (4*6*23 + 4*0 + 3) % 220;
            end
            6'd46: begin
                cfg_N = 248; cfg_P = 23; cfg_Np1 = 248+1; cfg_Np2 = 248+2; cfg_R15 = 248 % 15;
                cfg_qt0 = 3 % 248; cfg_qt1 = (4*8+3) % 248;
                cfg_qt2 = (4*6*23 + 4*1 + 3) % 248; cfg_qt3 = (4*6*23 + 4*1 + 3) % 248;
            end
            6'd47: begin
                cfg_N = 276; cfg_P = 25; cfg_Np1 = 276+1; cfg_Np2 = 276+2; cfg_R15 = 276 % 15;
                cfg_qt0 = 3 % 276; cfg_qt1 = (4*1+3) % 276;
                cfg_qt2 = (4*1*25 + 4*2 + 3) % 276; cfg_qt3 = (4*1*25 + 4*0 + 3) % 276;
            end
            6'd48: begin
                cfg_N = 336; cfg_P = 23; cfg_Np1 = 336+1; cfg_Np2 = 336+2; cfg_R15 = 336 % 15;
                cfg_qt0 = 3 % 336; cfg_qt1 = (4*1+3) % 336;
                cfg_qt2 = (4*8*23 + 4*4 + 3) % 336; cfg_qt3 = (4*8*23 + 4*1 + 3) % 336;
            end
            6'd49: begin
                cfg_N = 372; cfg_P = 25; cfg_Np1 = 372+1; cfg_Np2 = 372+2; cfg_R15 = 372 % 15;
                cfg_qt0 = 3 % 372; cfg_qt1 = (4*7+3) % 372;
                cfg_qt2 = (4*1*25 + 4*2 + 3) % 372; cfg_qt3 = (4*1*25 + 4*1 + 3) % 372;
            end

            // Fallback = WF0
            default: begin
                cfg_N = 48; cfg_P = 13; cfg_Np1 = 48+1; cfg_Np2 = 48+2; cfg_R15 = 48 % 15;
                cfg_qt0 = 3 % 48; cfg_qt1 = (4*2+3) % 48;
                cfg_qt2 = (4*0*13 + 4*4 + 3) % 48; cfg_qt3 = (4*0*13 + 4*6 + 3) % 48;
            end
        endcase
    end

endmodule