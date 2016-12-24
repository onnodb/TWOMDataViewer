function [h] = twomdv(varargin)
% TWOMDV UI for exploring TWOM Data Files on disk.
%
% SYNTAX:
% twomdv
% twomdv(dir)
% twomdv(dir, 'key', value, ___)
%
% INPUT:
% dir = starting directory

if ~isempty(varargin)
    twomdv = TWOMDataViewer(varargin{1});
else
    twomdv = TWOMDataViewer();
end

h = twomdv.guiHandle;

if ~isempty(varargin)
    if length(varargin) > 1
        parseClassArgs(varargin(2:end), twomdv);
    end
end

end
