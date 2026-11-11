classdef WaveformConfig < handle
    % WaveformConfig  Central config for all 49 DVB-RCS2 reference waveforms (ETSI EN 301 545-2 Table A-1)
    %
    % USAGE:
    %   wfg = WaveformConfig();
    %   wf  = wfg.getWaveform(wfID, channelChoice, customChannel);
    %
    % PROFILES:
    %   channelChoice : 'good' | 'medium' | 'bad' | 'custom'
    
    properties (Constant)
        MAX_WF_ID      = 49;
        VALID_PROFILES = {'good', 'medium', 'bad', 'custom'};
    end
    
    properties (Access = private)
        wfTable % Cache of populated waveform configs
    end
    
    methods
        function obj = WaveformConfig()
            obj.buildAllWaveforms();
        end
        
        function wf = getWaveform(obj, wfID, channelChoice, customChannel)
            if nargin < 3, channelChoice = 'medium'; end
            if nargin < 4, customChannel = struct(); end
            
            obj.validateWaveformID(wfID);
            obj.validateChannelChoice(channelChoice);
            
            wf = obj.wfTable{wfID};
            
            if strcmpi(channelChoice, 'custom')
                wf.channel = obj.buildCustomChannel(customChannel);
            else
                wf.channel = obj.getChannelPreset(channelChoice);
            end
            wf.channelName = lower(channelChoice);
        end
        
        function listWaveforms(obj)
            fprintf('\n========================================================================================\n');
            fprintf('  DVB-RCS2 Reference Waveforms (ETSI EN 301 545-2 Annex A Table A-1)\n');
            fprintf('========================================================================================\n');
            fprintf('  %-6s %-22s %-6s %-6s %-6s %-8s %-8s %-8s\n', ...
                'WF ID', 'Name', 'K', 'N', 'Rate', 'Mod', 'Pre/Post', 'Status');
            fprintf('  %s\n', repmat('-', 1, 88));
            for id = 1:obj.MAX_WF_ID
                w = obj.wfTable{id};
                if ~isempty(w)
                    fprintf('  %-6d %-22s %-6d %-6d %-6.3f %-8s %-3d/%-4d %-8s\n', ...
                        id, w.name, w.K, w.N, w.Rate, w.mod.name, ...
                        w.burst.preambleLen, w.burst.postambleLen, 'READY');
                end
            end
            fprintf('  %s\n', repmat('-', 1, 88));
            fprintf('  Channel profiles available: good | medium | bad | custom\n');
            fprintf('========================================================================================\n\n');
        end
        
        function describe(obj, wfID, channelChoice)
            if nargin < 3, channelChoice = 'medium'; end
            wf = obj.getWaveform(wfID, channelChoice);
            
            fprintf('\n============================================================\n');
            fprintf('  WAVEFORM %d — %s\n', wf.id, wf.name);
            fprintf('============================================================\n');
            fprintf('  PHY / Code:\n');
            fprintf('    numBytes   : %d\n',  wf.numBytes);
            fprintf('    K / N      : %d / %d\n', wf.K, wf.N);
            fprintf('    Rate       : %.4f\n', wf.Rate);
            fprintf('    Modulation : %s (order=%d, bits/sym=%d)\n', ...
                wf.mod.name, wf.mod.order, wf.mod.bitsPerSym);
            
            fprintf('\n  FEC:\n');
            fprintf('    default    : %s\n', wf.fec.default);
            fprintf('    turbo      : rate=%s, P=[%s]\n', ...
                wf.fec.turbo.codeRate, num2str(wf.fec.turbo.permP));
            if isfield(wf.fec, 'ldpc') && ~isempty(wf.fec.ldpc)
                fprintf('    ldpc       : z=%d, [%dx%d], decoder=%s\n', ...
                    wf.fec.ldpc.z, size(wf.fec.ldpc.shiftMatrix,1), ...
                    size(wf.fec.ldpc.shiftMatrix,2), wf.fec.ldpc.decoder);
            end
            
            fprintf('\n  Burst:\n');
            fprintf('    preambleLen  : %d\n', wf.burst.preambleLen);
            fprintf('    pilotLen     : %d\n', wf.burst.pilotLen);
            fprintf('    postambleLen : %d\n', wf.burst.postambleLen);
            fprintf('    pilotPeriod  : %d\n', wf.burst.pilotPeriod);
            
            fprintf('\n  Channel (%s):\n', upper(wf.channelName));
            obj.printChannel(wf.channel);
            fprintf('============================================================\n\n');
        end
    end
    
    % =====================================================
    %  BUILD TABLE FOR ALL 49 ETSI REFERENCE WAVEFORMS
    % =====================================================
    methods (Access = private)
        function buildAllWaveforms(obj)
            obj.wfTable = cell(1, obj.MAX_WF_ID);
            
            % Helper shorthand for ETSI Table A-1 entries:
            % makeWf(id, name, bytes, modName, modOrder, rateNum, rateStr, pre, post, pilPeriod, pilBlock, permP, uwHex)
            
            % WF1 - WF12: Standard Linear Modulation Bursts
            obj.wfTable{1}  = obj.makeWf(1,  'WF1 Standard',       38,  'QPSK',  4, 1/3, '1/3', 155, 27, 18, 1, [17 9 5 14 1],  '3300FC0FF3C3CCFFF0300C0FCF300CCCCCF0CFFC3C3F00CFCC0F33FF0CC0F00F030F330CFFF00F030F330CFFF00');
            obj.wfTable{2}  = obj.makeWf(2,  'WF2 Short QPSK',     14,  'QPSK',  4, 1/3, '1/3', 41,  41, 15, 1, [9 2 2 8 0],    '3CF0003F0F30CCCFCFFC03CF0003F0F30CCCFCFFC0');
            obj.wfTable{3}  = obj.makeWf(3,  'WF3 Med QPSK',       38,  'QPSK',  4, 1/3, '1/3', 27,  27, 18, 1, [17 9 5 14 1],  'F030F330CFFF00F030F330CFFF00');
            obj.wfTable{4}  = obj.makeWf(4,  'WF4 QPSK 1/2',       59,  'QPSK',  4, 1/2, '1/2', 22,  22, 24, 1, [23 10 2 11 1], 'C300FCC33FC30C03F30CFF00');
            obj.wfTable{5}  = obj.makeWf(5,  'WF5 QPSK 2/3',       85,  'QPSK',  4, 2/3, '2/3', 13,  13, 0,  1, [23 6 13 10 0], 'F30303FCC0C0F3FCC303FCC');
            obj.wfTable{6}  = obj.makeWf(6,  'WF6 QPSK 3/4',       96,  'QPSK',  4, 3/4, '3/4', 12,  12, 0,  1, [25 1 2 0 1],   'C033CCFC0');
            obj.wfTable{7}  = obj.makeWf(7,  'WF7 QPSK 5/6',       108, 'QPSK',  4, 5/6, '5/6', 9,   8,  0,  1, [29 1 4 1 1],   'DB0C0600600');
            obj.wfTable{8}  = obj.makeWf(8,  'WF8 8PSK 2/3',       115, '8PSK',  8, 2/3, '2/3', 10,  9,  9,  1, [29 6 5 0 0],   '0C36186D80030DB');
            obj.wfTable{9}  = obj.makeWf(9,  'WF9 8PSK 3/4',       130, '8PSK',  8, 3/4, '3/4', 8,   8,  9,  1, [31 0 1 2 0],   'C00186C061B00');
            obj.wfTable{10} = obj.makeWf(10, 'WF10 8PSK 5/6',      144, '8PSK',  8, 5/6, '5/6', 9,   8,  9,  1, [31 0 0 0 0],   'C00186C061B00');
            obj.wfTable{11} = obj.makeWf(11, 'WF11 16QAM 3/4',     175, '16QAM', 16,3/4, '3/4', 9,   9,  10, 1, [37 0 2 0 2],   '4EEEE4E44E4EEEE4E44');
            obj.wfTable{12} = obj.makeWf(12, 'WF12 16QAM 5/6',     194, '16QAM', 16,5/6, '5/6', 10,  9,  10, 1, [39 7 0 0 0],   '444E4EE4EEE4EEEE4E44');
            
            % WF13 - WF22: Long Burst Family
            obj.wfTable{13} = obj.makeWf(13, 'WF13 Long QPSK 1/3', 123, 'QPSK',  4, 1/3, '1/3', 32,  31, 20, 1, [31 0 3 1 0],   '3F00C30F3F3FCCC03CC0F03F3F00333C');
            obj.wfTable{14} = obj.makeWf(14, 'WF14 Long QPSK 1/2', 188, 'QPSK',  4, 1/2, '1/2', 25,  25, 25, 1, [37 1 3 4 2],   'FC033FCC3030CFC033FCC30303');
            obj.wfTable{15} = obj.makeWf(15, 'WF15 Long QPSK 2/3', 264, 'QPSK',  4, 2/3, '2/3', 16,  16, 0,  1, [43 0 0 6 2],   'CCC3F00FCC');
            obj.wfTable{16} = obj.makeWf(16, 'WF16 Long QPSK 3/4', 298, 'QPSK',  4, 3/4, '3/4', 13,  13, 0,  1, [49 0 3 5 0],   'C3F00FF30303FCC0C0F');
            obj.wfTable{17} = obj.makeWf(17, 'WF17 Long QPSK 5/6', 333, 'QPSK',  4, 5/6, '5/6', 9,   8,  0,  1, [49 0 5 0 5],   'C033CCFC0');
            obj.wfTable{18} = obj.makeWf(18, 'WF18 Long 8PSK 2/3', 355, '8PSK',  8, 2/3, '2/3', 10,  9,  9,  1, [53 1 4 6 2],   'DB0C0600600');
            obj.wfTable{19} = obj.makeWf(19, 'WF19 Long 8PSK 3/4', 400, '8PSK',  8, 3/4, '3/4', 8,   8,  9,  1, [53 1 10 7 1],  '0C36186D80030DB');
            obj.wfTable{20} = obj.makeWf(20, 'WF20 Long 8PSK 5/6', 444, '8PSK',  8, 5/6, '5/6', 9,   8,  9,  1, [59 3 8 5 1],   'C00186C061B00');
            obj.wfTable{21} = obj.makeWf(21, 'WF21 Long 16QAM 3/4',539, '16QAM', 16,3/4, '3/4', 10,  9,  10, 1, [65 0 3 7 0],   '444E4EE4EEE4EEEE4E44');
            obj.wfTable{22} = obj.makeWf(22, 'WF22 Long 16QAM 5/6',599, '16QAM', 16,5/6, '5/6', 10,  9,  10, 1, [81 1 2 5 2],   '444E4EE4EEE4EEEE4E44');

            % WF23 - WF31: Reserved / Extended
            for id = 23:31
                obj.wfTable{id} = obj.makeWf(id, sprintf('WF%d Reserved', id), 50, 'QPSK', 4, 1/2, '1/2', 16, 16, 0, 0, [23 10 2 11 1], 'C300FCC33F');
            end

            % WF32 - WF39: Short / CSC / Spread Bursts (Pilotless)
            obj.wfTable{32} = obj.makeWf(32, 'WF32 Short QPSK 1/2',100, 'QPSK',  4, 1/2, '1/2', 32,  0,  0,  0, [23 10 8 2 1],  '0C330C0FF3F3033F');
            obj.wfTable{33} = obj.makeWf(33, 'WF33 Short QPSK 3/4',100, 'QPSK',  4, 3/4, '3/4', 32,  0,  0,  0, [23 10 8 2 1],  '0C330C0FF3F3033F');
            obj.wfTable{34} = obj.makeWf(34, 'WF34 Med QPSK 1/2',  170, 'QPSK',  4, 1/2, '1/2', 32,  0,  0,  0, [33 9 15 3 1],  '0C330C0FF3F3033F');
            obj.wfTable{35} = obj.makeWf(35, 'WF35 Med QPSK 3/4',  170, 'QPSK',  4, 3/4, '3/4', 32,  0,  0,  0, [33 9 15 3 1],  '0C330C0FF3F3033F');
            obj.wfTable{36} = obj.makeWf(36, 'WF36 Med QPSK 7/8',  170, 'QPSK',  4, 7/8, '7/8', 32,  0,  0,  0, [33 9 15 3 1],  '0C330C0FF3F3033F');
            obj.wfTable{37} = obj.makeWf(37, 'WF37 High QPSK 2/3', 438, 'QPSK',  4, 2/3, '2/3', 32,  0,  0,  0, [59 1 1 2 1],   '0C330C0FF3F3033F');
            obj.wfTable{38} = obj.makeWf(38, 'WF38 High QPSK 4/5', 438, 'QPSK',  4, 4/5, '4/5', 32,  0,  0,  0, [59 1 1 2 1],   '0C330C0FF3F3033F');
            obj.wfTable{39} = obj.makeWf(39, 'WF39 High QPSK 6/7', 438, 'QPSK',  4, 6/7, '6/7', 32,  0,  0,  0, [59 1 1 2 1],   '0C330C0FF3F3033F');

            % WF40 - WF43: BPSK Low-Rate Family
            obj.wfTable{40} = obj.makeWf(40, 'WF40 BPSK 1/3 Long', 59,  'BPSK',  2, 1/3, '1/3', 313, 56, 18, 1, [23 10 2 11 1], 'BB8874877B4BB447778B8848747B8844444784774B4B788474487BB77844878837108FD095972F1BA7E7274340AB0');
            obj.wfTable{41} = obj.makeWf(41, 'WF41 BPSK 1/3 Short',59,  'BPSK',  2, 1/3, '1/3', 57,  56, 18, 1, [23 10 2 11 1], '37108FD095972F1BA7E7274340AB0');
            obj.wfTable{42} = obj.makeWf(42, 'WF42 BPSK 1/3 Large',123, 'BPSK',  2, 1/3, '1/3', 65,  64, 20, 1, [31 0 3 1 0],   'C7B6676A0A09D0B7B17D422B7B8E48E44');
            obj.wfTable{43} = obj.makeWf(43, 'WF43 BPSK 1/2 Large',188, 'BPSK',  2, 1/2, '1/2', 52,  51, 25, 1, [37 1 3 4 2],   'DFCCD0A1758493B4728DC5828F');

            % WF44 - WF49: Short High-Rate / High-Mod Family
            obj.wfTable{44} = obj.makeWf(44, 'WF44 Short QPSK 5/6',51,  'QPSK',  4, 5/6, '5/6', 11,  10, 0,  0, [23 10 5 0 0],  'CFCF03F30C0');
            obj.wfTable{45} = obj.makeWf(45, 'WF45 Short 8PSK 2/3',55,  '8PSK',  8, 2/3, '2/3', 10,  9,  9,  1, [23 6 10 4 0],  'DB0C0600600');
            obj.wfTable{46} = obj.makeWf(46, 'WF46 Short 8PSK 3/4',62,  '8PSK',  8, 3/4, '3/4', 9,   9,  9,  1, [23 6 8 1 1],   'C00186C300061B0');
            obj.wfTable{47} = obj.makeWf(47, 'WF47 Short 8PSK 5/6',69,  '8PSK',  8, 5/6, '5/6', 9,   8,  9,  1, [25 1 1 2 0],   'C00186C061B00');
            obj.wfTable{48} = obj.makeWf(48, 'WF48 Short 16QAM 3/4',84, '16QAM', 16,3/4, '3/4', 9,   9,  10, 1, [23 8 1 4 1],   '4EEEE4E44E4EEEE4E44');
            obj.wfTable{49} = obj.makeWf(49, 'WF49 Short 16QAM 5/6',93, '16QAM', 16,5/6, '5/6', 9,   9,  10, 1, [25 1 7 2 1],   '4EEEE4E44E4EEEE4E44');
        end
        
        function wf = makeWf(obj, id, name, bytes, modName, modOrder, rateNum, rateStr, pre, post, pilPeriod, pilBlock, permP, uwHex)
            wf          = obj.defaultBase();
            wf.id       = id;
            wf.name     = name;
            wf.numBytes = bytes;
            wf.K        = bytes * 8;
            wf.Rate     = rateNum;
            wf.N        = round(wf.K / rateNum);
            
            wf.mod.name       = modName;
            wf.mod.order      = modOrder;
            wf.mod.bitsPerSym = log2(modOrder);
            
            wf.fec.default        = 'turbo';
            wf.fec.turbo.codeRate = rateStr;
            wf.fec.turbo.permP    = permP;
            wf.fec.turbo.K        = wf.K;
            
            wf.fec.ldpc = obj.getLdpcConfig(id, wf.K, wf.N, wf.Rate);
            
            wf.burst.uwHex        = uwHex;
            wf.burst.preambleLen  = pre;
            wf.burst.pilotLen     = pilBlock;
            wf.burst.postambleLen = post;
            wf.burst.pilotPeriod  = pilPeriod;
        end
        
        function ldpc = getLdpcConfig(~, id, K, N, Rate)
            ldpc.decoder = 'LayeredOMS';
            ldpc.maxIter = 25;
            ldpc.alpha   = 0.75;
            ldpc.beta    = 0.50;
            
            switch id
                case 1
                    ldpc.z = 152;
                    ldpc.shiftMatrix = [ ...
                         17,  54,   0, -1, -1, -1;
                         89, 131,   0,  0, -1, -1;
                         42,  11,  -1,  0,  0, -1;
                        115,  76,  -1, -1,  0,  0];
                case 13
                    ldpc.z = 492;
                    ldpc.shiftMatrix = [ ...
                         17,  54,   0, -1, -1, -1;
                         89, 131,   0,  0, -1, -1;
                         42,  11,  -1,  0,  0, -1;
                        115,  76,  -1, -1,  0,  0];
                case 32
                    ldpc.z = 200;
                    ldpc.shiftMatrix = [ ...
                         16, 17, 22,  0,  0, -1, -1, -1;
                         40, 10, 18,  0, -1,  0, -1, -1;
                         35, 24,  7, -1, -1, -1,  0, -1;
                         12, 45, 88, -1, -1, -1, -1,  0];
                otherwise
                    if abs(Rate - 1/3) < 0.05
                        mb = 4; nb = 6;
                    elseif abs(Rate - 1/2) < 0.05
                        mb = 4; nb = 8;
                    elseif abs(Rate - 2/3) < 0.05
                        mb = 4; nb = 12;
                    else
                        mb = 4; nb = round(4 / (1 - Rate));
                    end
                    ldpc.z = round(K / (nb - mb));
                    P = -ones(mb, nb);
                    for r = 1:mb
                        for c = 1:(nb - mb)
                            P(r,c) = mod((r-1)*13 + (c-1)*17, ldpc.z);
                        end
                        P(r, nb - mb + r) = 0;
                    end
                    ldpc.shiftMatrix = P;
            end
        end
        
        function wf = defaultBase(~)
            wf.rrc.alpha = 0.20;
            wf.rrc.span  = 10;
            wf.rrc.sps   = 4;
            wf.rrc.Fs    = 4e6;
            wf.rrc.Rs    = wf.rrc.Fs / wf.rrc.sps;
        end
    end
    
    % =====================================================
    %  CHANNEL PRESETS (Updated Default Settings)
    % =====================================================
    methods (Access = private)
        function ch = getChannelPreset(obj, profile)
            switch lower(profile)
                case 'good',   ch = obj.channel_good();
                case 'medium', ch = obj.channel_medium();
                case 'bad',    ch = obj.channel_bad();
            end
            ch.profile = lower(profile);
        end
        
        function ch = channel_good(~)
            % Good: 20dB SNR, 100Hz CFO, 2° PN
            ch.awgn.enable   = true;   ch.awgn.EbN0_dB = 20;
            ch.cfo.enable    = true;   ch.cfo.Hz       = 100;
            ch.pn.enable     = true;   ch.pn.rms_deg   = 2;
            ch.timing.enable = true;   ch.timing.offset = 0.5;
            ch.junk.frontLen = 100;    ch.junk.backLen = 100;
        end

        function ch = channel_medium(~)
            % Medium: 10dB SNR, 1000Hz CFO, 15° PN
            ch.awgn.enable   = true;   ch.awgn.EbN0_dB = 10;
            ch.cfo.enable    = true;   ch.cfo.Hz       = 1000;
            ch.pn.enable     = true;   ch.pn.rms_deg   = 15;
            ch.timing.enable = true;   ch.timing.offset = 18.8;
            ch.junk.frontLen = 100;    ch.junk.backLen = 100;
        end

        function ch = channel_bad(~)
            % Bad: 2dB SNR, 5000Hz CFO, 30° PN
            ch.awgn.enable   = true;   ch.awgn.EbN0_dB = 2;
            ch.cfo.enable    = true;   ch.cfo.Hz       = 5000;
            ch.pn.enable     = true;   ch.pn.rms_deg   = 30;
            ch.timing.enable = true;   ch.timing.offset = 22.3;
            ch.junk.frontLen = 200;    ch.junk.backLen = 200;
        end
        
        function ch = buildCustomChannel(obj, override)
            ch = obj.channel_medium();
            ch.profile = 'custom';
            fnTop = fieldnames(override);
            for i = 1:numel(fnTop)
                if isstruct(override.(fnTop{i})) && isfield(ch, fnTop{i})
                    fnSub = fieldnames(override.(fnTop{i}));
                    for j = 1:numel(fnSub)
                        ch.(fnTop{i}).(fnSub{j}) = override.(fnTop{i}).(fnSub{j});
                    end
                else
                    ch.(fnTop{i}) = override.(fnTop{i});
                end
            end
        end
        
        function printChannel(~, ch)
            fprintf('    AWGN    : enable=%d  Eb/N0=%.1f dB\n', ...
                ch.awgn.enable, ch.awgn.EbN0_dB);
            fprintf('    CFO     : enable=%d  offset=%+.1f Hz\n', ...
                ch.cfo.enable, ch.cfo.Hz);
            fprintf('    PN      : enable=%d  rms=%.1f deg\n', ...
                ch.pn.enable, ch.pn.rms_deg);
            fprintf('    Timing  : enable=%d  offset=%+.4f samples\n', ...
                ch.timing.enable, ch.timing.offset);
            fprintf('    Junk    : front=%d  back=%d samples\n', ...
                ch.junk.frontLen, ch.junk.backLen);
        end
        
        function validateWaveformID(obj, wfID)
            if ~isnumeric(wfID) || ~isscalar(wfID) || wfID < 1 || wfID > obj.MAX_WF_ID
                error('WaveformConfig:BadID', ...
                    'wfID must be integer in [1, %d], got %g', obj.MAX_WF_ID, wfID);
            end
        end
        
        function validateChannelChoice(obj, choice)
            if ~ischar(choice) && ~isstring(choice)
                error('WaveformConfig:BadProfile', 'channelChoice must be a string');
            end
            if ~ismember(lower(choice), obj.VALID_PROFILES)
                error('WaveformConfig:BadProfile', ...
                    'channelChoice must be one of: %s (got "%s")', ...
                    strjoin(obj.VALID_PROFILES, ' | '), choice);
            end
        end
    end
end