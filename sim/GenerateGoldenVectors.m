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

    if wfID == 1
        hardcoded_C1 = 11;
        hardcoded_C2 = 12;
    elseif wfID == 13
        hardcoded_C1 = 9;
        hardcoded_C2 = 15;
    else
        error('No hardcoded C1/C2 for WF%d', wfID);
    end

    couples      = reshape(bits, 2, N).';
    interCouples = te.Interleaver.permute(couples);

    te.RSC1.reset(hardcoded_C1);
    [Y1, W1] = te.RSC1.encodeBlock(couples, hardcoded_C1);

    te.RSC2.reset(hardcoded_C2);
    [Y2, W2] = te.RSC2.encodeBlock(interCouples, hardcoded_C2);

    sysA = couples(:,1);
    sysB = couples(:,2);
    Y1 = Y1(:); W1 = W1(:);
    Y2 = Y2(:); W2 = W2(:);

    % ------------------------------------------------------------------
    % Manual cross-check of Y2, W2 using the same formula as Verilog.
    % ------------------------------------------------------------------
    fprintf('  --- Manual verification of pass-2 encoder ---\n');
    fprintf('  hardcoded_C2 = %d\n', hardcoded_C2);
    fprintf('  interCouples(1:4, :) = \n');
    for jj = 1:4
        fprintf('    j=%d: A=%d B=%d\n', jj-1, interCouples(jj,1), interCouples(jj,2));
    end

    % Simulate RSC2 manually
    trellis = te.RSC2.Trellis;
    manual_state = hardcoded_C2;
    for jj = 1:8
        A = interCouples(jj, 1);
        B = interCouples(jj, 2);
        idx = 2*A + B + 1;
        Y_man = trellis.Y(manual_state+1, idx);
        W_man = trellis.W(manual_state+1, idx);
        next_state = trellis.NextState(manual_state+1, idx) - 1;
        fprintf('    j=%d: state_in=%2d, A=%d B=%d, Y2_man=%d W2_man=%d, info.Y2=%d info.W2=%d %s\n', ...
            jj-1, manual_state, A, B, Y_man, W_man, Y2(jj), W2(jj), ...
            iif_ternary(Y_man==Y2(jj) && W_man==W2(jj), 'MATCH', 'MISMATCH'));
        manual_state = next_state;
    end

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

function s = iif_ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
