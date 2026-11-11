% GenerateGoldenVectors.m
clc; clear;

wfg = WaveformConfig();
test_wfs = [1, 13];

for i = 1:length(test_wfs)
    wfID = test_wfs(i);
    wf   = wfg.getWaveform(wfID);

    inputLen = wf.K;
    N        = inputLen / 2;
    P        = wf.fec.turbo.permP(1);
    Q        = wf.fec.turbo.permP(2:5);

    fprintf('Generating WF%d: K=%d bits, N=%d couples, P=%d, Q=[%s]\n', ...
        wfID, inputLen, N, P, num2str(Q));

    punctConfig = struct('Y1_Period',1,'Y1_Pattern',1, ...
                         'W1_Period',1,'W1_Pattern',1, ...
                         'Y2_Period',1,'Y2_Pattern',1, ...
                         'W2_Period',1,'W2_Pattern',1);

    te = TurboEncoder(wf.fec.turbo.codeRate, P, Q, inputLen, punctConfig);

    rand('seed', 42 + wfID);
    bits = randi([0 1], inputLen, 1);
    bits = bits(:);

    % ------------------------------------------------------------------
    % Encode using the FULL turbo encoder flow (dynamic circulation).
    %   process() performs:
    %     1. Probe pass 1 (state 0 -> lastState1) -> C1 = circ(lastState1, N)
    %     2. Probe pass 2 (state 0 -> lastState2) -> C2 = circ(lastState2, N)
    %     3. Actual encoder 1 from state C1
    %     4. Actual encoder 2 from state C2 on interleaved couples
    % ------------------------------------------------------------------
    [~, info] = te.process(bits);

    Y1 = info.Y1(:);
    W1 = info.W1(:);
    Y2 = info.Y2(:);
    W2 = info.W2(:);

    C1         = info.C1;
    C2         = info.C2;
    lastState1 = info.lastState1;
    lastState2 = info.lastState2;

    fprintf('  --- Dynamic circulation (matches DUT ROM lookup) ---\n');
    fprintf('    N mod 15     = %d\n', mod(N, 15));
    fprintf('    enc1: lastState=%2d (bin=%s)  ->  C1=%2d (bin=%s)\n', ...
        lastState1, dec2bin(lastState1,4), C1, dec2bin(C1,4));
    fprintf('    enc2: lastState=%2d (bin=%s)  ->  C2=%2d (bin=%s)\n', ...
        lastState2, dec2bin(lastState2,4), C2, dec2bin(C2,4));

    % ------------------------------------------------------------------
    % Verify circularity: starting from C1 the encoder must end at C1.
    % ------------------------------------------------------------------
    couples      = reshape(bits, 2, N).';
    interCouples = te.Interleaver.permute(couples);

    te.RSC1.reset(C1);
    te.RSC1.encodeBlock(couples, C1);
    endState1 = te.RSC1.getState();

    te.RSC2.reset(C2);
    te.RSC2.encodeBlock(interCouples, C2);
    endState2 = te.RSC2.getState();

    if endState1 == C1
        fprintf('    enc1 circularity: OK  (end=%d == C1=%d)\n', endState1, C1);
    else
        fprintf(2, '    enc1 circularity: FAIL (end=%d != C1=%d)\n', endState1, C1);
    end

    if endState2 == C2
        fprintf('    enc2 circularity: OK  (end=%d == C2=%d)\n', endState2, C2);
    else
        fprintf(2, '    enc2 circularity: FAIL (end=%d != C2=%d)\n', endState2, C2);
    end

    % ------------------------------------------------------------------
    % Manual cross-check of Y2, W2 using the same formula as Verilog.
    % ------------------------------------------------------------------
    fprintf('  --- Manual verification of pass-2 encoder (first 8 couples) ---\n');
    fprintf('    interCouples(1:4, :) = \n');
    for jj = 1:4
        fprintf('      j=%d: A=%d B=%d\n', jj-1, interCouples(jj,1), interCouples(jj,2));
    end

    trellis = te.RSC2.Trellis;
    manual_state = C2;
    for jj = 1:8
        A = interCouples(jj, 1);
        B = interCouples(jj, 2);
        idx = 2*A + B + 1;
        Y_man = trellis.Y(manual_state+1, idx);
        W_man = trellis.W(manual_state+1, idx);
        next_state = trellis.NextState(manual_state+1, idx) - 1;
        if Y_man == Y2(jj) && W_man == W2(jj)
            tag = 'MATCH';
        else
            tag = 'MISMATCH';
        end
        fprintf('      j=%d: state_in=%2d, A=%d B=%d, Y2_man=%d W2_man=%d, info.Y2=%d info.W2=%d %s\n', ...
            jj-1, manual_state, A, B, Y_man, W_man, Y2(jj), W2(jj), tag);
        manual_state = next_state;
    end

    % ------------------------------------------------------------------
    % Pack systematic couples for input file (LSB-first within word,
    % couple k occupies bits [2k+1 : 2k], A in MSB of the couple).
    % ------------------------------------------------------------------
    sysA = couples(:,1);
    sysB = couples(:,2);
    in_couples = 2*sysA + sysB;

    in_filename = sprintf('input_wf%d.txt', wfID);
    fid_in = fopen(in_filename, 'w');
    n_words_in = ceil(N / 16);
    for w = 1:n_words_in
        word = uint32(0);
        for c = 0:15
            idx = (w-1)*16 + c + 1;
            if idx <= N
                val = uint32(in_couples(idx));
            else
                val = uint32(0);
            end
            word = bitor(word, bitshift(val, 2*c));
        end
        fprintf(fid_in, '%08X\n', word);
    end
    fclose(fid_in);

    % ------------------------------------------------------------------
    % Build output bit stream: SYS (interleaved A/B per couple),
    % then Y1 (N bits), W1 (N bits), Y2 (N bits), W2 (N bits).
    % Pack MSB-first into 32-bit words.
    % ------------------------------------------------------------------
    out_filename = sprintf('output_wf%d.txt', wfID);
    fid_out = fopen(out_filename, 'w');

    bitbuf = zeros(1, 6*N);
    for k = 1:N
        bitbuf((k-1)*2 + 1) = sysA(k);
        bitbuf((k-1)*2 + 2) = sysB(k);
    end
    bitbuf(2*N + (1:N)) = Y1;
    bitbuf(3*N + (1:N)) = W1;
    bitbuf(4*N + (1:N)) = Y2;
    bitbuf(5*N + (1:N)) = W2;

    pad = mod(32 - mod(length(bitbuf), 32), 32);
    if pad > 0
        bitbuf = [bitbuf, zeros(1, pad)];
    end

    for b = 1:32:length(bitbuf)
        word = uint32(0);
        for k = 0:31
            word = bitor(word, bitshift(uint32(bitbuf(b+k)), 31-k));
        end
        fprintf(fid_out, '%08X\n', word);
    end
    fclose(fid_out);

    total_out_words = length(bitbuf) / 32;
    fprintf('  Wrote %s (%d words)\n\n', out_filename, total_out_words);
end
