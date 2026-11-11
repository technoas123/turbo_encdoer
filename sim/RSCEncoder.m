classdef RSCEncoder < handle
    % DVB-RCS2 16-state double-binary CRSC encoder

    properties
        State = [0 0 0 0]
        Trellis
    end

    methods

        function obj = RSCEncoder(trellis)

            if nargin < 1 || isempty(trellis)
                trellis = DuoBinaryTrellis();
            end

            obj.Trellis = trellis;
        end

        function reset(obj,initState)

            if nargin < 2
                initState = 0;
            end

            if numel(initState) == 1

                if initState < 0 || initState > 15 || floor(initState) ~= initState
                    error('RSCEncoder: invalid state.');
                end

                state = initState;

            elseif numel(initState) == 4

                initState = double(initState(:).');

                if any(~ismember(initState,[0 1]))
                    error('RSCEncoder: state bits must be 0 or 1.');
                end

                state =  8*initState(1) + 4*initState(2) +  2*initState(3) +initState(4);

            else
                error('RSCEncoder: state must be scalar 0...15 or 1x4.');
            end

            obj.State = obj.stateBits(state);
        end

        function [Y,W] = encodeCouple(obj,A,B)

            validateattributes(A,{'numeric'},{'scalar'});
            validateattributes(B,{'numeric'},{'scalar'});

            if ~ismember(A,[0 1]) || ~ismember(B,[0 1])
                error('RSCEncoder: A and B must be binary.');
            end

            state = obj.stateNumber();

            inputIndex = 2*A + B + 1;

            Y = obj.Trellis.Y(state+1,inputIndex);
            W = obj.Trellis.W(state+1,inputIndex);

            nextState = obj.Trellis.NextState(state+1,inputIndex) - 1;

            obj.State = obj.stateBits(nextState);
        end

        function [parY,parW] = encodeBlock(obj,couples,initState)

            if nargin < 3
                initState = 0;
            end

            if size(couples,2) ~= 2
                error('RSCEncoder: couples must be N x 2.');
            end

            if any(~ismember(couples(:),[0 1]))
                error('RSCEncoder: couples must contain only 0/1.');
            end

            obj.reset(initState);

            N = size(couples,1);

            parY = zeros(N,1);
            parW = zeros(N,1);

            for k = 1:N
                [parY(k),parW(k)] =obj.encodeCouple(couples(k,1),couples(k,2));
            end
        end

        function finalState = getState(obj)

            finalState = obj.stateNumber();
        end
    end

    methods (Access = private)

        function state = stateNumber(obj)

            s = obj.State;

            state = 8*s(1) + 4*s(2) +  2*s(3) +s(4);
        end

        function bits = stateBits(~,state)

            bits = [ bitget(state,4),  bitget(state,3), bitget(state,2),   bitget(state,1)];
        end
    end
end