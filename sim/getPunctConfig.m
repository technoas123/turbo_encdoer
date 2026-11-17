% getPunctConfig.m
function [y_pat, w_pat, rate_str] = getPunctConfig(rate_code)
    switch rate_code
        case 0 % Rate 1/3
            y_pat = [1];
            w_pat = [1];
            rate_str = '1/3';
        case 1 % Rate 1/2
            y_pat = [1];
            w_pat = [0];
            rate_str = '1/2';
        case 2 % Rate 2/3
            y_pat = [1, 0];
            w_pat = [0];
            rate_str = '2/3';
        case 3 % Rate 3/4
            y_pat = [1, 0, 1, 0, 0, 0];
            w_pat = [0];
            rate_str = '3/4';
        case 4 % Rate 4/5
            y_pat = [1, 0, 0, 0];
            w_pat = [0];
            rate_str = '4/5';
        case 5 % Rate 5/6
            y_pat = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0];
            w_pat = [0];
            rate_str = '5/6';
        case 6 % Rate 6/7
            y_pat = [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0];
            w_pat = [0];
            rate_str = '6/7';
        case 7 % Rate 7/8
            y_pat = [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0];
            w_pat = [0];
            rate_str = '7/8';
        otherwise
            y_pat = [1];
            w_pat = [1];
            rate_str = '1/3';
    end
end
