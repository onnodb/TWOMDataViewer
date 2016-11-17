function [fd] = readasciifile(filename, varargin)
% READASCIIFILE Read data from an ASCII file (separated values).
%
% The format of the ASCII file is assumed to be comma-separated values
% by default, with the distance (in um) in the first column, and the force
% (in pN) in the second column. This can easily be customized, using the key-
% value pair arguments listed below. Most of these correspond to the arguments
% to MATLAB's "textscan" function, which is used for actually parsing the file.
%
% SYNTAX:
% fd = readasciifile();
% fd = readasciifile('myfile.txt');
% fd = readasciifile(..., 'key', value, ...);
%
% INPUT:
% filename = name of the ASCII file; if not given, or empty, a dialog is shown
%       in which the user can select a file.
%
% KEY-VALUE PAIR ARGUMENTS:
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
% TEXTSCAN KEY-VALUE PAIR ARGUMENTS:
% CommentStyle = (see the 'textscan' function) (default: '#')
% Delimiter = (see the 'textscan' function) (default: ',')
% EmptyValue = (see the 'textscan' function) (default: NaN)
% EndOfLine = (see the 'textscan' function) (default: '\r\n')
% ExpChars = (see the 'textscan' function) (default: 'eEdD')
% HeaderLines = (see the 'textscan' function) (default: 0)
% MultipleDelimsAsOne = (see the 'textscan' function) (default: 1)
% TreatAsEmpty = (see the 'textscan' function) (default: {'--'})
% Whitespace = (see the 'textscan' function) (default: ' \b\t')
%
% NOTE:
% readasciifile automatically adds some metadata fields to the FdData object
% returned. This includes the filename (from the 'filename' parameter), as well
% as any header lines that were skipped (see the "HeaderLines" argument).
%
% OUTPUT:
% fd = FdData object

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parse & validate input

if nargin < 1 || isempty(filename)
    [uifile, uipath] = uigetfile(...
                                 {'*.csv', 'Comma-separated value files (*.csv)'; ...
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
                ... % readasciifile parameters:
                  'beadDiameter',           0 ...
                , 'distanceCol',            1 ...
                , 'forceCol',               2 ...
                , 'timeCol',                [] ...
                , 'distanceMultiplier',     1 ...
                , 'forceMultiplier',        1 ...
                , 'timeMultiplier',         1 ...
                ... % textscan parameters:
                , 'CommentStyle',           '#' ...
                , 'Delimiter',              ',' ...
                , 'EmptyValue',             NaN ...
                , 'EndOfLine',              '\r\n' ...
                , 'ExpChars',               'eEdD' ...
                , 'HeaderLines',            0 ...
                , 'MultipleDelimsAsOne',    1 ...
                , 'TreatAsEmpty',           {'--'} ...
                , 'Whitespace',             ' \b\t' ...
                );
args = parseArgs(varargin, defArgs);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Read data

filename = normalizepath(filename);

% Parse file
fid = fopen(filename);
filecnt = textscan(...
                fid, '%f %f' ...
                , 'CommentStyle',               args.CommentStyle ...
                , 'Delimiter',                  args.Delimiter ...
                , 'EmptyValue',                 args.EmptyValue ...
                , 'EndOfLine',                  args.EndOfLine ...
                , 'ExpChars',                   args.ExpChars ...
                , 'HeaderLines',                args.HeaderLines ...
                , 'MultipleDelimsAsOne',        args.MultipleDelimsAsOne ...
                , 'TreatAsEmpty',               args.TreatAsEmpty ...
                , 'Whitespace',                 args.Whitespace ...
                );
fclose(fid);

% Process data
if ~isequal(size(filecnt), [1 2])
    error('Could not parse input file: wrong number of columns (2 expected; %d found)', size(filecnt,2));
end

% Create output
[~, basename, ~] = fileparts(filename);

data = struct();
if isempty(args.distanceCol)
    data.d = 1:length(filecnt{1});
else
    data.d = filecnt{args.distanceCol} .* args.distanceMultiplier;
end
if isempty(args.forceCol)
    data.f = 1:length(filecnt{1});
else
    data.f = filecnt{args.forceCol} .* args.forceMultiplier;
end
if isempty(args.timeCol)
    data.t = 1:length(filecnt{1});
else
    data.t = filecnt{args.timeCol} .* args.timeMultiplier;
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

        if args.HeaderLines > 0
            m.headerLines = getHeaderLines();
        end
    end

    function [h] = getHeaderLines()
        h = {};
        f = fopen(filename);
        f_cleanup = onCleanup(@()fclose(f));
        lineCount = 0;
        l = fgetl(f);
        while ischar(l)
            lineCount = lineCount + 1;
            h{end+1} = l;
            if lineCount >= args.HeaderLines
                return;
            end
            l = fgetl(f);
        end
    end

end

