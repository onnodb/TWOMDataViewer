function [c] = readexcelfolder(directory, varargin)
% READEXCELFOLDER Read a directory with Excel files into an FdDataCollection.
%
% SYNTAX:
% c = readexcelfolder('C:\My\Path')
% 	Read all "*.xlsx" files in the given directory.
% c = readexcelfolder('C:\My\Path+')
% 	Read all "*.xlsx" files in the given directory and its subdirectories.
% c = readexcelfolder('C:\My\Path\*.xls')
% 	Explicitly give the extension of the Excel files to read.
% c = readexcelfolder('C:\My\Path', <any arguments to readexcelfile>)
% 	Any additional arguments are passed on directly to "readexcelfile". See
% 	that function for details.
%
% INPUT:
% directory = name of a directory with Excel files. End the directory name
%       with a '+' sign to recurse into subdirectories.
% 		It is also possible to explicitly give a filter in the form "*.xls",
% 		to specify the extension of the files to read.
%
% OUTPUT:
% c = an FdDataCollection.
%
% SEE ALSO:
% readasciifile

c = readdatafolder(directory, @(f) readexcelfile(f, varargin{:}), 'xlsx');

end

