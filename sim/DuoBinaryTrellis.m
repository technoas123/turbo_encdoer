classdef DuoBinaryTrellis
    % DVB-RCS2 16-state double-binary CRSC trellis
    %
    % State:
    %   S = 8*S1 + 4*S2 + 2*S3 + S4
    %
    % Input:
    %   A,B = duo-binary information bits
    %
    % Feedback polynomial:
    %   1 + D^3 + D^4 = octal 23
    %
    % Y polynomial:
    %   1 + D + D^2 + D^4 = octal 35
    %
    % W polynomial:
    %   1 + D^2 + D^3 + D^4 = octal 27

    properties (SetAccess = private)
        NumStates = 16
        NumInputs = 4

        InputA
        InputB

        NextState
        Y
        W
    end

    methods
        function obj = DuoBinaryTrellis()

            obj.InputA = [0; 0; 1; 1];
            obj.InputB = [0; 1; 0; 1];

            obj.NextState = zeros(16,4);
            obj.Y = zeros(16,4);
            obj.W = zeros(16,4);

            for state = 0:15

                [S1,S2,S3,S4] = obj.stateBits(state);

                for input = 1:4

                    A = obj.InputA(input);
                    B = obj.InputB(input);

                    [Y,W,nextBits] =  obj.coreEquation(A,B,S1,S2,S3,S4);

                    nextState = 8*nextBits(1) +   4*nextBits(2) + 2*nextBits(3) + nextBits(4);

                    obj.Y(state+1,input) = Y;
                    obj.W(state+1,input) = W;

                    % MATLAB uses 1-based state indexing
                    obj.NextState(state+1,input) = nextState + 1;
                end
            end
        end

        function [S1,S2,S3,S4] = stateBits(~,state)

            S1 = bitget(state,4);
            S2 = bitget(state,3);
            S3 = bitget(state,2);
            S4 = bitget(state,1);
        end
    end

    methods (Static, Access = private)

        function [Y,W,nextBits] = coreEquation(A,B,S1,S2,S3,S4)

            % Feedback branch:
            % 1 + D^3 + D^4
            F = mod(A + B + S3 + S4,2);

            % Direct realization of the ETSI Y polynomial:
            % 1 + D + D^2 + D^4
            %
            % B is connected to the indicated encoder-core taps.
            Y = mod(F + B + S1 + S2 + S4,2);

            % Direct realization of the ETSI W polynomial:
            % 1 + D^2 + D^3 + D^4
            W = mod(F + B + S2 + S3 + S4,2);

            % Shift register
            nextBits = [F S1 S2 S3];
        end
    end
end