classdef Puncturer

    properties (SetAccess = private)
        Config
    end

    methods

        function obj = Puncturer(config)

            obj.validateConfig(config);
            obj.Config = config;
        end

        function coded = punctureAndAssemble(  obj,sysA,sysB,Y1,W1,Y2,W2)

            sysA = double(sysA(:));
            sysB = double(sysB(:));
            Y1 = double(Y1(:));
            W1 = double(W1(:));
            Y2 = double(Y2(:));
            W2 = double(W2(:));

            N = numel(sysA);

            if any([numel(sysB),numel(Y1),numel(W1), numel(Y2),numel(W2)] ~= N)

                error('Puncturer: all streams must have length N.');
            end

            % Systematic part
            systematic = zeros(2*N,1);

            systematic(1:2:end) = sysA;
            systematic(2:2:end) = sysB;

            keptY1 = obj.punctureStream(Y1,obj.Config.Y1_Period,obj.Config.Y1_Pattern);

            keptW1 = obj.punctureStream( W1,obj.Config.W1_Period,obj.Config.W1_Pattern);

            keptY2 = obj.punctureStream( Y2,obj.Config.Y2_Period,obj.Config.Y2_Pattern);

            keptW2 = obj.punctureStream(  W2,obj.Config.W2_Period,obj.Config.W2_Pattern);

            coded = [
                systematic
                keptY1
                keptW1
                keptY2
                keptW2
                ];
        end
    end

    methods (Static)

        function kept = punctureStream(stream,period,pattern)

            stream = stream(:);

            if period <= 0 || mod(period,1) ~= 0
                error('Invalid puncturing period.');
            end

            pattern = double(pattern(:).');

            if numel(pattern) ~= period
                error('Pattern length must equal period.');
            end

            keep = repmat(pattern,1,ceil(numel(stream)/period));
            keep = keep(1:numel(stream));

            kept = stream(logical(keep));
        end

        function validateConfig(config)

            names = { ...
                'Y1_Period','Y1_Pattern', 'W1_Period','W1_Pattern', 'Y2_Period','Y2_Pattern',  'W2_Period','W2_Pattern'};

            for k = 1:numel(names)
                if ~isfield(config,names{k})
                    error('Puncturer: missing field %s.',names{k});
                end
            end

            for k = 1:2:7

                period = config.(names{k});
                pattern = config.(names{k+1});

                if numel(pattern) ~= period
                    error('Puncturer: %s length mismatch.',names{k+1});
                end

                if any(~ismember(pattern,[0 1]))
                    error('Puncturer: pattern must contain 0/1.');
                end
            end
        end
    end
end