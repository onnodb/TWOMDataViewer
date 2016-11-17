function [path] = normalizepath(path)
% Normalizes a path, by trimming and removing any 'file://' URL prefix present,
% and expanding '~' into the user's home directory.
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
% path = the trimmed path with any 'file://' URL prefix removed, and '~'
%   expanded to the user's home directory.

path = strtrim(path);

if length(path) >= 1 && path(1) == '~'
    path = fullfile(gethomedir(), path(2:end));
end

if length(path) >= 7 && strcmp(path(1:7), 'file://')
    path = path(8:end);
end

end
