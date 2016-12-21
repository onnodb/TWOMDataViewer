function [idx] = findClosest_BinSearch(a, val)
% FINDCLOSEST_BINSEARCH Performs a binary search in a numeric array
%
% INPUT:
% a = numeric array (vector), assumed to be sorted in ascending order
% val = value to search for
%
% OUTPUT:
% idx = index of the value in a that is either equal to val, or the closest
%       to val. Zero if val is less than the first element of a, or if val
%       is greater than the last element of a.

if ~isvector(a) || ~isnumeric(a)
    error('Invalid argument "a": numeric array expected.');
end
if ~isscalar(val) || ~isnumeric(val)
    error('Invalid argument "val": numeric value expected.');
end

if isempty(a) || val < a(1) || val > a(end)
    idx = 0;
    return
end

idxLo = 1;
idxHi = length(a);

while idxHi > idxLo+1
    i = floor( (idxHi+idxLo)/2 );
    if val == a(i)
        idx = i;
        return
    elseif val > a(i)
        idxLo = i;
    else % val < a(i)
        idxHi = i;
    end
end

if abs(val-a(idxLo)) < abs(a(idxHi)-val)
    idx = idxLo;
else
    idx = idxHi;
end

end
