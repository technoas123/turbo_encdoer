classdef TurboEncoder

    properties
        CodeRate
        CodeRateNumeric

        P
        Q

        InputLen
        N

        RSC1
        RSC2

        Interleaver
        Punct

        C1
        C2
    end

    methods

        function obj = TurboEncoder( codeRate,P,Q,inputLen,punctConfig)

            if nargin < 5
                error(['TurboEncoder requires: ''codeRate, P, Q, inputLen, punctConfig.']);
            end

            obj.CodeRate = codeRate;
            obj.CodeRateNumeric = eval(codeRate);

            obj.InputLen = inputLen;

            if mod(inputLen,2) ~= 0
                error('TurboEncoder: input length must be even.');
            end

            obj.N = inputLen/2;

            if mod(obj.N,4) ~= 0
                error('TurboEncoder: N must be a multiple of 4.');
            end

            if mod(obj.N,15) == 0
                error('TurboEncoder: N must not be a multiple of 15.');
            end

            obj.P = P;
            obj.Q = Q;

            trellis = DuoBinaryTrellis();

            obj.RSC1 = RSCEncoder(trellis);
            obj.RSC2 = RSCEncoder(trellis);

            obj.Interleaver = ...
                ARPInterleaver(obj.N,P,Q);

            obj.Punct = Puncturer(punctConfig);
        end

        function [codedBits,info] = process(obj,bits)

            bits = double(bits(:));

            if numel(bits) ~= obj.InputLen
                error('TurboEncoder: input length mismatch.');
            end

            if any(~ismember(bits,[0 1]))
                error('TurboEncoder: input must be binary.');
            end

            couples = reshape(bits,2,obj.N).';

            % =====================================================
            % FIRST PASS: determine C1
            % =====================================================

            obj.RSC1.reset(0);

            obj.RSC1.encodeBlock(couples,0);

            lastState1 = obj.RSC1.getState();

            obj.C1 = obj.circularState( lastState1,obj.N);

            % =====================================================
            % SECOND PASS: determine C2
            % =====================================================

            interCouples =  obj.Interleaver.permute(couples);

            obj.RSC2.reset(0);

            obj.RSC2.encodeBlock(interCouples,0);

            lastState2 = obj.RSC2.getState();

            obj.C2 = obj.circularState( lastState2,obj.N);

            % =====================================================
            % THIRD PASS: actual encoder 1
            % =====================================================

            obj.RSC1.reset(obj.C1);

            [Y1,W1] =  obj.RSC1.encodeBlock(couples,obj.C1);

            % =====================================================
            % FOURTH PASS: actual encoder 2
            % =====================================================

            obj.RSC2.reset(obj.C2);

            [Y2,W2] =  obj.RSC2.encodeBlock(interCouples,obj.C2);

            % =====================================================
            % SYSTEMATIC
            % =====================================================

            sysA = couples(:,1);
            sysB = couples(:,2);

            % =====================================================
            % PUNCTURE / SERIALIZE
            % =====================================================

            codedBits = obj.Punct.punctureAndAssemble( sysA,sysB,Y1,W1,Y2,W2);

            info.N = obj.N;
            info.C1 = obj.C1;
            info.C2 = obj.C2;
            info.lastState1 = lastState1;
            info.lastState2 = lastState2;

            info.Y1 = Y1;
            info.W1 = W1;
            info.Y2 = Y2;
            info.W2 = W2;

            info.codedLength = numel(codedBits);
        end
    end

    methods (Static)

        function C = circularState(lastState,N)

            table = [  0 14  3 13  7  9  4 10 15  1 12  2  8  6 11  5;
                 0 11 13  6 10  1  7 12  5 14  8  3 15  4  2  9;
                 0  8  9  1  2 10 11  3  4 12 13  5  6 14 15  7;
                 0  3  4  7  8 11 12 15  1  2  5  6  9 10 13 14;
                 0 12  5  9 11  7 14  2  6 10  3 15 13  1  8  4;
                 0  4 12  8  9 13  5  1  2  6 14 10 11 15  7  3;
                 0  6 10 12  5  3 15  9 11 13  1  7 14  8  4  2;
                 0  7  8 15  1  6  9 14  3  4 11 12  2  5 10 13;
                 0  5 14 11 13  8  3  6 10 15  4  1  7  2  9 12;
                 0 13  7 10 15  2  8  5 14  3  9  4  1 12  6 11;
                 0  2  6  4 12 14 10  8  9 11 15 13  5  7  3  1;
                 0  9 11  2  6 15 13  4 12  5  7 14 10  3  1  8;
                 0 10 15  5 14  4  1 11 13  7  2  8  3  9 12  6;
                 0 15  1 14  3 12  2 13  7  8  6  9  4 11  5 10
                ];

            r = mod(N,15);

            if r == 0
                error('TurboEncoder: N mod 15 cannot be zero.');
            end

            if lastState < 0 || lastState > 15
                error('TurboEncoder: invalid last state.');
            end

            C = table(r,lastState+1);
        end
    end
end