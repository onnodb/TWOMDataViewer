function twomdv(varargin)
% TWOMDV UI for exploring TWOM Data Files on disk.
%
% SYNTAX:
% twomdv
% twomdv(dir)
%
% INPUT:
% dir = starting directory

twomdv = TWOMDataViewer();

if ~isempty(varargin)
    twomdv.browseTo(varargin{1});
end

end
