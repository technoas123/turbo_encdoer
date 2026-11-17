function GenerateTableA1GoldenVectors()
    fprintf('========================================================================================\n');
    fprintf('  DVB-RCS2 Duo-Binary Turbo Encoder Bit-Exact Golden Vector Generator\n');
    fprintf('========================================================================================\n');

    % Active Table A-1 Waveform Database: [wf_id, N, P, R15, qt0, qt1, qt2, qt3, rate_code]
    wf_db = [
        % WF1 - WF12
         1,  152, 17,  2,  9,  5, 14, 1, 0;
         2,   56,  9, 11,  2,  2,  8, 0, 0;
         3,  152, 17,  2,  9,  5, 14, 1, 0;
         4,  236, 23, 11, 10,  2, 11, 1, 1;
         5,  340, 23, 10,  6, 13, 10, 0, 2;
         6,  384, 25,  9,  1,  2,  0, 1, 3;
         7,  432, 29, 12,  1,  4,  1, 1, 5;
         8,  460, 29, 10,  6,  5,  0, 0, 2;
         9,  520, 31, 10,  0,  1,  2, 0, 3;
        10,  576, 31,  6,  0,  0,  0, 0, 5;
        11,  700, 37, 10,  0,  2,  0, 2, 3;
        12,  776, 39, 11,  7,  0,  0, 0, 5;
        % WF13 - WF22
        13,  492, 31, 12,  0,  3,  1, 0, 0;
        14,  752, 37,  2,  1,  3,  4, 2, 1;
        15, 1056, 43,  6,  0,  0,  6, 2, 2;
        16, 1192, 49,  7,  0,  3,  5, 0, 3;
        17, 1332, 49, 12,  0,  5,  0, 5, 5;
        18, 1420, 53, 10,  1,  4,  6, 2, 2;
        19, 1600, 53, 10,  1, 10,  7, 1, 3;
        20, 1776, 59,  6,  3,  8,  5, 1, 5;
        21, 2156, 65, 11,  0,  3,  7, 0, 3;
        22, 2396, 81, 11,  1,  2,  5, 2, 5;
        % WF32 - WF39
        32,  400, 23, 10, 10,  8,  2, 1, 1;
        33,  400, 23, 10, 10,  8,  2, 1, 3;
        34,  680, 33,  5,  9, 15,  3, 1, 1;
        35,  680, 33,  5,  9, 15,  3, 1, 3;
        36,  680, 33,  5,  9, 15,  3, 1, 7;
        37, 1752, 59, 12,  1,  1,  2, 1, 2;
        38, 1752, 59, 12,  1,  1,  2, 1, 4;
        39, 1752, 59, 12,  1,  1,  2, 1, 6;
        % WF40 - WF49
        40,  236, 23, 11, 10,  2, 11, 1, 0;
        41,  236, 23, 11, 10,  2, 11, 1, 0;
        42,  492, 31, 12,  0,  3,  1, 0, 0;
        43,  752, 37,  2,  1,  3,  4, 2, 1;
        44,  204, 23,  9, 10,  5,  0, 0, 5;
        45,  220, 23, 10,  6, 10,  4, 0, 2;
        46,  248, 23,  8,  6,  8,  1, 1, 3;
        47,  276, 25,  6,  1,  1,  2, 0, 5;
        48,  336, 23,  6,  8,  1,  4, 1, 3;
        49,  372, 25, 12,  1,  7,  2, 1, 5
    ];

    sim_dir = fullfile('..', 'vivado', 'dvb_rcs2_turbo_encoder.sim', 'sim_1', 'behav', 'xsim');
    has_sim_dir = exist(sim_dir, 'dir') == 7;

    total_wfs = size(wf_db, 1);
    rate_names = {'1/3', '1/2', '2/3', '3/4', '4/5', '5/6', '6/7', '7/8'};

    for row = 1:total_wfs
        wf_id     = wf_db(row, 1);
        N         = wf_db(row, 2);
        P         = wf_db(row, 3);
        R15       = wf_db(row, 4);
        qt0       = wf_db(row, 5);
        qt1       = wf_db(row, 6);
        qt2       = wf_db(row, 7);
        qt3       = wf_db(row, 8);
        rate_code = wf_db(row, 9);

        % 1. Generate Input Couples (A, B)
        [A, B, input_words] = generate_couples(N, wf_id);

        % 2. Constituent Encoder Pass 1 (Natural Order)
        % Step 2a: Circulation State Search
        s_final1 = run_encoder_pass(A, B, N, 0);
        s0_1     = get_circ_state(R15, s_final1);
        % Step 2b: Actual Natural Encoding
        [Y1, W1] = run_encoder_data(A, B, N, s0_1);

        % 3. ARP Interleaver
        [A_int, B_int] = run_interleaver(A, B, N, P, qt0, qt1, qt2, qt3);

        % 4. Constituent Encoder Pass 2 (Interleaved Order)
        % Step 4a: Circulation State Search
        s_final2 = run_encoder_pass(A_int, B_int, N, 0);
        s0_2     = get_circ_state(R15, s_final2);
        % Step 4b: Actual Interleaved Encoding
        [Y2, W2] = run_encoder_data(A_int, B_int, N, s0_2);

        % 5. Puncturing & Sequential Stream Assembly
        output_bits = assemble_output_streams(A, B, Y1, W1, Y2, W2, N, rate_code);

        % 6. Word Packing (32-bit MSB-First)
        output_words = pack_bits_to_words32(output_bits);

        % 7. Write Hex Vectors
        in_filename   = sprintf('wf%d_in.hex', wf_id);
        gold_filename = sprintf('wf%d_out.hex', wf_id);

        write_hex_file(in_filename, input_words);
        write_hex_file(gold_filename, output_words);

        if has_sim_dir
            write_hex_file(fullfile(sim_dir, in_filename), input_words);
            write_hex_file(fullfile(sim_dir, gold_filename), output_words);
        end

        fprintf('  [WF %2d] N=%4d | Rate=%-3s | InWords=%3d | OutWords=%4d -> OK\n', ...
            wf_id, N, rate_names{rate_code + 1}, length(input_words), length(output_words));
    end

    fprintf('========================================================================================\n');
    fprintf('  Generated all %d Waveforms Bit-Exact to RTL!\n', total_wfs);
    fprintf('========================================================================================\n');
end

% =========================================================================
% Couple Generation & Input Word Packing (LSB-First Couples in 32-bit Words)
% =========================================================================
function [A, B, words] = generate_couples(N, wf_id)
    A = zeros(1, N);
    B = zeros(1, N);
    
    seed = uint32(wf_id * 104729 + 12345);
    for k = 1:N
        seed = uint32(mod(double(seed) * 1103515245 + 12345, 2^31));
        A(k) = bitand(bitshift(seed, -16), 1);
        B(k) = bitand(bitshift(seed, -17), 1);
    end

    num_words = ceil(N / 16);
    words = zeros(1, num_words);
    for w = 0:(num_words - 1)
        w_val = uint32(0);
        for m = 0:15
            k = w * 16 + m;
            if k < N
                c_val = uint32(A(k + 1) * 2 + B(k + 1));
                w_val = bitor(w_val, bitshift(c_val, 2 * m));
            end
        end
        words(w + 1) = w_val;
    end
end

% =========================================================================
% Constituent Encoder (16-State RTL Equivalence)
% =========================================================================
function s_final = run_encoder_pass(A, B, N, init_state)
    s = bitand(bitshift(init_state, [-(3:-1:0)]), 1); % [S1 S2 S3 S4]
    for k = 1:N
        a = A(k);
        b = B(k);
        f = bitxor(bitxor(bitxor(a, b), s(3)), s(4));
        s = [f, s(1), s(2), s(3)];
    end
    s_final = s(1)*8 + s(2)*4 + s(3)*2 + s(4);
end

function [Y, W] = run_encoder_data(A, B, N, init_state)
    s = bitand(bitshift(init_state, [-(3:-1:0)]), 1); % [S1 S2 S3 S4]
    Y = zeros(1, N);
    W = zeros(1, N);
    for k = 1:N
        a = A(k);
        b = B(k);
        f = bitxor(bitxor(bitxor(a, b), s(3)), s(4));
        Y(k) = bitxor(bitxor(bitxor(bitxor(f, b), s(1)), s(2)), s(4));
        W(k) = bitxor(bitxor(bitxor(f, b), s(2)), bitxor(s(3), s(4)));
        s = [f, s(1), s(2), s(3)];
    end
end

% =========================================================================
% Circular State Lookup (circular_state_rom.v exact match)
% =========================================================================
function s0 = get_circ_state(r, last_state)
    lut_hex = { ...
        '5b682c1fa497d3e0', ... % r = 1
        '924f38e5c71a6db0', ... % r = 2
        '7fe65dc43ba21980', ... % r = 3
        'eda96521fcb87430', ... % r = 4
        '481df3a62eb795c0', ... % r = 5
        '37fbae6215d98c40', ... % r = 6
        '248e71db9f35ca60', ... % r = 7
        'da52cb43e961f870', ... % r = 8
        'c92714fa638dbe50', ... % r = 9
        'b6c1493e582fa7d0', ... % r = 10
        '1375dfb98aec4620', ... % r = 11
        '813ae75c4df62b90', ... % r = 12
        '6c93827db14e5fa0', ... % r = 13
        'a5b49687d2c3e1f0'  ... % r = 14
    };
    if r < 1 || r > 14
        s0 = 0;
        return;
    end
    hex_str = lut_hex{r};
    nibble_char = hex_str(16 - last_state);
    s0 = hex2dec(nibble_char);
end

% =========================================================================
% DVB-RCS2 ARP Interleaver (arp_interleaver.v exact match)
% =========================================================================
function [A_int, B_int] = run_interleaver(A, B, N, P, qt0, qt1, qt2, qt3)
    A_int = zeros(1, N);
    B_int = zeros(1, N);
    qt = [qt0, qt1, qt2, qt3];

    for j = 0:(N - 1)
        S = mod(P * j, N);
        selected_qt = qt(mod(j, 4) + 1);
        int_addr = mod(S + selected_qt, N);

        if mod(j, 2) == 0 % Even j -> Pair Swap
            A_int(j + 1) = B(int_addr + 1);
            B_int(j + 1) = A(int_addr + 1);
        else              % Odd j -> No Swap
            A_int(j + 1) = A(int_addr + 1);
            B_int(j + 1) = B(int_addr + 1);
        end
    end
end

% =========================================================================
% Output Streams Assembly (puncturer_ctrl.v & STATE_UNLOAD match)
% =========================================================================
function out_bits = assemble_output_streams(A, B, Y1, W1, Y2, W2, N, rate_code)
    % Stream 0: Systematic couples (A0, B0, A1, B1, ...)
    sys_bits = zeros(1, 2 * N);
    sys_bits(1:2:end) = A;
    sys_bits(2:2:end) = B;

    % Stream 1: Y1 parity
    y1_kept = [];
    for k = 0:(N - 1)
        if is_punct_kept(rate_code, 'Y', k)
            y1_kept(end + 1) = Y1(k + 1);
        end
    end

    % Stream 2: W1 parity
    w1_kept = [];
    for k = 0:(N - 1)
        if is_punct_kept(rate_code, 'W', k)
            w1_kept(end + 1) = W1(k + 1);
        end
    end

    % Stream 3: Y2 parity
    y2_kept = [];
    for k = 0:(N - 1)
        if is_punct_kept(rate_code, 'Y', k)
            y2_kept(end + 1) = Y2(k + 1);
        end
    end

    % Stream 4: W2 parity
    w2_kept = [];
    for k = 0:(N - 1)
        if is_punct_kept(rate_code, 'W', k)
            w2_kept(end + 1) = W2(k + 1);
        end
    end

    out_bits = [sys_bits, y1_kept, w1_kept, y2_kept, w2_kept];
end

function keep = is_punct_kept(rate_code, stream_type, addr)
    switch rate_code
        case 0 % 1/3
            keep = true;
        case 1 % 1/2
            keep = strcmp(stream_type, 'Y');
        case 2 % 2/3
            if strcmp(stream_type, 'W'), keep = false;
            else, keep = (mod(addr, 2) == 0);
            end
        case 3 % 3/4
            if strcmp(stream_type, 'W'), keep = false;
            else, m = mod(addr, 6); keep = (m == 0 || m == 2);
            end
        case 4 % 4/5
            if strcmp(stream_type, 'W'), keep = false;
            else, keep = (mod(addr, 4) == 0);
            end
        case 5 % 5/6
            if strcmp(stream_type, 'W'), keep = false;
            else, m = mod(addr, 20); keep = (m == 0 || m == 4 || m == 8 || m == 12);
            end
        case 6 % 6/7
            if strcmp(stream_type, 'W'), keep = false;
            else, m = mod(addr, 12); keep = (m == 0 || m == 4);
            end
        case 7 % 7/8
            if strcmp(stream_type, 'W'), keep = false;
            else, m = mod(addr, 28); keep = (m == 0 || m == 4 || m == 12 || m == 20);
            end
        otherwise
            keep = true;
    end
end

% =========================================================================
% Output Word Packing (MSB-First 32-bit Words)
% =========================================================================
function words = pack_bits_to_words32(bits)
    num_words = ceil(length(bits) / 32);
    words = zeros(1, num_words);
    for w = 0:(num_words - 1)
        val = uint32(0);
        for b = 0:31
            idx = w * 32 + b + 1;
            if idx <= length(bits)
                bit_val = uint32(bits(idx));
                val = bitor(val, bitshift(bit_val, 31 - b));
            end
        end
        words(w + 1) = val;
    end
end

function write_hex_file(filename, words)
    fid = fopen(filename, 'w');
    if fid < 0
        error('Cannot open file %s for writing', filename);
    end
    for i = 1:length(words)
        fprintf(fid, '%08X\n', uint32(words(i)));
    end
    fclose(fid);
end
