function n = countKept(N, period, pattern)
%COUNTKEPT  Number of bits kept out of N given puncturing period & pattern
%   pattern is a binary row vector of length 'period'.
%   Bit index i (0-based) is kept when pattern(mod(i,period)+1) == 1.

  idx = mod(0:(N-1), period);        % 0-based modulo
  n = sum(pattern(idx + 1));          % 1-based indexing into pattern
end
