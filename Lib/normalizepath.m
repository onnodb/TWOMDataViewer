function [path] = normalizepath(path)
% Normalizes a path, by trimming and removing any 'file://' URL prefix present.
%
% SYNTAX:
% path = normalizepath(path);
%
% Useful for processing paths pasted into MATLAB from Linux file managers.
%
% INPUT:
% path = a string containing a path
%
% OUTPUT:
% path = the trimmed path with any 'file://' URL prefix removed

path = strtrim(path);

if strcmp(path(1:7), 'file://')
    path = path(8:end);
end

end
