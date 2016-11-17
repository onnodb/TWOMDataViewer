function [fd] = readexcelfile(filename, varargin)
% READEXCELFILE Read data from an Excel file.
%
% The Excel spreadsheet is assumed to consist of a single sheet, with data
% stored in columns. By default, the first column is assumed to consist of
% distance values (in um), and the second column of force values (in pN).
% This can easily be customized, using the key- value pair arguments listed
% below.
%
% SYNTAX:
% fd = readexcelfile();
% fd = readexcelfile('myfile.xlsx');
% fd = readexcelfile(..., 'key', value, ...);
%
% INPUT:
% filename = name of the Excel file; if not given, or empty, a dialog is 
%       shown in which the user can select a file.
%
% KEY-VALUE PAIR ARGUMENTS:
% sheet = optional name of the sheet from which to import data.
% beadDiameter = diameter of the bead (in um). If given, this is automatically
%       subtracted from the distance data.
% distanceCol, forceCol, timeCol = the column indices for the various data.
%       (Default: 1, 2, []). Set to empty to use auto-incrementing numbers
%       for that column.
% distanceMultiplier, forceMultiplier, timeMultiplier = if the data are not
%       in the required units (pN for force, um for distance, ms for time),
%       use these arguments to multiply all values in that column with a
%       constant, to convert the data into the required units. For example,
%       set "forceMultiplier" to "1000" if your data is in nN instead of pN.
%
% NOTE:
% readexcelfile automatically adds some metadata fields to the FdData object
% returned. This includes the filename (from the 'filename' parameter).
%
% OUTPUT:
% fd = FdData object

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parse & validate input

if nargin < 1 || isempty(filename)
    [uifile, uipath] = uigetfile(...
                                 {'*.xls;*.xlsx', 'Excel files (*.xls;*.xlsx)'; ...
                                  '*.*', 'All files (*.*)'}, ...
                                 'Select file'...
                                );
    if uifile == 0
        fd = [];
        return
    end
    filename = fullfile(uipath, uifile);
end

defArgs = struct(...
                ... % readexcelfile parameters:
                  'beadDiameter',           0 ...
                , 'distanceCol',            1 ...
                , 'forceCol',               2 ...
                , 'timeCol',                [] ...
                , 'distanceMultiplier',     1 ...
                , 'forceMultiplier',        1 ...
                , 'timeMultiplier',         1 ...
                , 'sheet',                  [] ...
                );
args = parseArgs(varargin, defArgs);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Read data

filename = normalizepath(filename);

% Load file
if isempty(args.sheet)
    filecnt = xlsread(filename);
else
    filecnt = xlsread(filename, args.sheet);
end

% Create output
[~, basename, ~] = fileparts(filename);

data = struct();
if isempty(args.distanceCol)
    data.d = 1:size(filecnt,1);
else
    data.d = filecnt(1:end,args.distanceCol) .* args.distanceMultiplier;
end
if isempty(args.forceCol)
    data.f = 1:size(filecnt,1);
else
    data.f = filecnt(1:end,args.forceCol) .* args.forceMultiplier;
end
if isempty(args.timeCol)
    data.t = 1:size(filecnt,1);
else
    data.t = filecnt(1:end,args.timeCol) .* args.timeMultiplier;
end

fd = FdData(...
        basename, ...
        data.f, data.d, data.t, ...
        getMetaData() ...
        );

if args.beadDiameter ~= 0
    % Subtract bead diameter
    fd = fd.shift('d', -args.beadDiameter);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function [m] = getMetaData()
        m = struct(...
                'originalFile',     filename ...
                );

        if ~isempty(args.sheet)
            m.sheet = args.sheet;
        end
    end

end

