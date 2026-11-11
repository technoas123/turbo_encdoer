classdef ARPInterleaver

    properties (SetAccess = private)
        N
        P
        Q
        PermMap
    end

    methods

        function obj = ARPInterleaver(N,P,Q)

            validateattributes(N,{'numeric'},  {'scalar','integer','positive'});

            validateattributes(P,{'numeric'}, {'scalar','integer','nonnegative'});

            if numel(Q) ~= 4
                error('ARPInterleaver: Q must be [Q0 Q1 Q2 Q3].');
            end

            if any(Q < 0) || any(floor(Q) ~= Q)
                error('ARPInterleaver: Q values must be non-negative integers.');
            end

            if mod(N,4) ~= 0
                error('ARPInterleaver: N must be a multiple of 4.');
            end

            if mod(N,15) == 0
                error(['ARPInterleaver: N must not be a multiple of 15 ' 'for the DVB-RCS2 16-state circular code.']);
            end

            obj.N = N;
            obj.P = P;
            obj.Q = Q(:).';

            obj.PermMap = obj.buildPermMap();

            if numel(unique(obj.PermMap)) ~= N
                error('ARPInterleaver: generated map is not a permutation.');
            end
        end

        function map = buildPermMap(obj)

            map = zeros(obj.N,1);

            Q0 = obj.Q(1);
            Q1 = obj.Q(2);
            Q2 = obj.Q(3);
            Q3 = obj.Q(4);

            for j = 0:obj.N-1

                switch mod(j,4)

                    case 0
                        Qj = 0;

                    case 1
                        Qj = 4*Q1;

                    case 2
                        Qj = 4*Q0*obj.P + 4*Q2;

                    case 3
                        Qj = 4*Q0*obj.P + 4*Q3;
                end

                map(j+1) = mod( obj.P*j + Qj + 3, obj.N);
            end
        end

        function outputCouples = permute(obj,inputCouples)

            if size(inputCouples,1) ~= obj.N || size(inputCouples,2) ~= 2
                error('ARPInterleaver: input must be N x 2.');
            end

            outputCouples = zeros(obj.N,2);

            for j = 0:obj.N-1

                src = obj.PermMap(j+1) + 1;

                pair = inputCouples(src,:);

                % ETSI current version: even j -> swap A/B
                if mod(j,2) == 0
                    pair = pair([2 1]);
                end

                outputCouples(j+1,:) = pair;
            end
        end

        function inputCouples = depermute(obj,outputCouples)

            if size(outputCouples,1) ~= obj.N || size(outputCouples,2) ~= 2
                error('ARPInterleaver: input must be N x 2.');
            end

            inputCouples = zeros(obj.N,2);

            for j = 0:obj.N-1

                pair = outputCouples(j+1,:);

                % Undo internal A/B permutation
                if mod(j,2) == 0
                    pair = pair([2 1]);
                end

                src = obj.PermMap(j+1) + 1;

                inputCouples(src,:) = pair;
            end
        end
    end
end