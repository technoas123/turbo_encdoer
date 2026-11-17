`timescale 1ns / 1ps

module tb_turbo_encoder_top;

    reg          aclk;
    reg          aresetn;
    reg  [5:0]   cfg_wave_id;
    reg          s_axis_tvalid;
    wire         s_axis_tready;
    reg  [31:0]  s_axis_tdata;
    reg          s_axis_tlast;
    wire         m_axis_tvalid;
    reg          m_axis_tready;
    wire [31:0]  m_axis_tdata;
    wire         m_axis_tlast;

    // Unit Under Test (Wrapper)
    dvb_rcs2_encoder_wrapper uut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .cfg_wave_id   (cfg_wave_id),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tlast  (s_axis_tlast),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tlast  (m_axis_tlast)
    );

    // 61.44 MHz Clock (16.276 ns)
    always #8.138 aclk = ~aclk;

    // Word Buffers
    reg [31:0] golden_in  [0:511];
    reg [31:0] golden_out [0:511];

    integer active_wfs [0:39];
    integer idx, wave_idx, w_in, w_out;
    integer total_words_in, total_words_out;
    integer match_cnt, mismatch_cnt, framing_err_cnt;
    integer pass_count, fail_count;
    reg [256:0] in_file, out_file;

    initial begin
        // Table A-1 Active Waveforms (skipping 23..31)
        active_wfs[0]=1;   active_wfs[1]=2;   active_wfs[2]=3;   active_wfs[3]=4;
        active_wfs[4]=5;   active_wfs[5]=6;   active_wfs[6]=7;   active_wfs[7]=8;
        active_wfs[8]=9;   active_wfs[9]=10;  active_wfs[10]=11; active_wfs[11]=12;
        active_wfs[12]=13; active_wfs[13]=14; active_wfs[14]=15; active_wfs[15]=16;
        active_wfs[16]=17; active_wfs[17]=18; active_wfs[18]=19; active_wfs[19]=20;
        active_wfs[20]=21; active_wfs[21]=22;
        active_wfs[22]=32; active_wfs[23]=33; active_wfs[24]=34; active_wfs[25]=35;
        active_wfs[26]=36; active_wfs[27]=37; active_wfs[28]=38; active_wfs[29]=39;
        active_wfs[30]=40; active_wfs[31]=41; active_wfs[32]=42; active_wfs[33]=43;
        active_wfs[34]=44; active_wfs[35]=45; active_wfs[36]=46; active_wfs[37]=47;
        active_wfs[38]=48; active_wfs[39]=49;

        aclk          = 0;
        aresetn       = 0;
        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1;
        pass_count    = 0;
        fail_count    = 0;

        #100;
        aresetn = 1;
        #50;

        $display("==========================================================================================");
        $display("   DVB-RCS2 TURBO ENCODER - TABLE A-1 ACTIVE 40 WAVEFORMS VERIFICATION");
        $display("==========================================================================================");

        for (idx = 0; idx < 40; idx = idx + 1) begin
            wave_idx        = active_wfs[idx];
            cfg_wave_id     = wave_idx[5:0];
            match_cnt       = 0;
            mismatch_cnt    = 0;
            framing_err_cnt = 0;

            for (w_in = 0; w_in < 512; w_in = w_in + 1) begin
                golden_in[w_in]  = 32'hXXXXXXXX;
                golden_out[w_in] = 32'hXXXXXXXX;
            end

            $sformat(in_file,  "wf%0d_in.hex",  wave_idx);
            $sformat(out_file, "wf%0d_out.hex", wave_idx);
            
            $readmemh(in_file,  golden_in);
            $readmemh(out_file, golden_out);

            total_words_in = 0;
            while (golden_in[total_words_in] !== 32'hXXXXXXXX && total_words_in < 512)
                total_words_in = total_words_in + 1;
            
            total_words_out = 0;
            while (golden_out[total_words_out] !== 32'hXXXXXXXX && total_words_out < 512)
                total_words_out = total_words_out + 1;

            #20;

            // Stream input words
            for (w_in = 0; w_in < total_words_in; w_in = w_in + 1) begin
                @(posedge aclk);
                s_axis_tvalid <= 1'b1;
                s_axis_tdata  <= golden_in[w_in];
                s_axis_tlast  <= (w_in == total_words_in - 1);
                
                @(posedge aclk);
                while (!s_axis_tready) @(posedge aclk);
            end
            
            @(posedge aclk);
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;

            // Collect output words
            w_out = 0;
            while (w_out < total_words_out) begin
                @(posedge aclk);
                if (m_axis_tvalid && m_axis_tready) begin
                    if (m_axis_tdata === golden_out[w_out]) begin
                        match_cnt = match_cnt + 1;
                    end else begin
                        $display("[ERROR] WF%0d Word %0d Mismatch: RTL=%08X Golden=%08X", wave_idx, w_out, m_axis_tdata, golden_out[w_out]);
                        mismatch_cnt = mismatch_cnt + 1;
                    end

                    if (w_out == total_words_out - 1) begin
                        if (!m_axis_tlast) begin
                            $display("[ERROR] WF%0d missing TLAST on final output word!", wave_idx);
                            framing_err_cnt = framing_err_cnt + 1;
                        end
                    end else begin
                        if (m_axis_tlast) begin
                            $display("[ERROR] WF%0d premature TLAST on word %0d!", wave_idx, w_out);
                            framing_err_cnt = framing_err_cnt + 1;
                        end
                    end
                    w_out = w_out + 1;
                end
            end

            if (mismatch_cnt == 0 && framing_err_cnt == 0 && match_cnt == total_words_out) begin
                $display("WF %2d | In Words: %3d | Out Words: %3d | Matches: %3d | Status: [ PASS ]", 
                         wave_idx, total_words_in, total_words_out, match_cnt);
                pass_count = pass_count + 1;
            end else begin
                $display("WF %2d | In Words: %3d | Out Words: %3d | Mismatches: %0d | Status: [ FAIL ]", 
                         wave_idx, total_words_in, total_words_out, mismatch_cnt);
                fail_count = fail_count + 1;
            end

            #100;
        end

        $display("==========================================================================================");
        $display("   FINAL RESULT: %0d / 40 WAVEFORMS PASSED WITH ZERO MISMATCHES AND ZERO FRAMING ERRORS", pass_count);
        $display("==========================================================================================");

        $finish;
    end

endmodule