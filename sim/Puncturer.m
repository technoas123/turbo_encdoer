classdef Puncturer
    properties (SetAccess = private)
        Config
    end
    methods
        function obj = Puncturer(config)
            obj.Config = config;
        end

        function coded = punctureAndAssemble(obj, sysA, sysB, Y1, W1, Y2, W2)
            N = numel(sysA);
            coded = zeros(N * 6, 1);
            
            % Pack 6 bits per couple: {sys, par1, par2}
            % Each pair is packed as a 2-bit integer: MSB is A/Y, LSB is B/W
            for k = 1:N
                sys_val  = 2*sysA(k) + sysB(k);
                par1_val = 2*Y1(k)   + W1(k);
                par2_val = 2*Y2(k)   + W2(k);
                
                % LSB-first bit stream: sys(0..1), par1(0..1), par2(0..1)
                coded((k-1)*6 + 1) = bitget(sys_val, 1);
                coded((k-1)*6 + 2) = bitget(sys_val, 2);
                coded((k-1)*6 + 3) = bitget(par1_val, 1);
                coded((k-1)*6 + 4) = bitget(par1_val, 2);
                coded((k-1)*6 + 5) = bitget(par2_val, 1);
                coded((k-1)*6 + 6) = bitget(par2_val, 2);
            end
        end
    end
end
