function explorefd(fdc, varargin)
% EXPLOREFD UI for exploring a collection of force-extension data.
%
% SYNTAX:
% explorefd(fdc)
%
% INPUT:
% fdc = an FdDataCollection object.

fdexplorer = FdExplorer(fdc);

if ~isempty(varargin)
    parseClassArgs(varargin, fdexplorer);
end

end
