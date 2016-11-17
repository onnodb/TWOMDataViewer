function [c] = readasciifolder(directory, varargin)
% READASCIIFOLDER Read a directory with ASCII files into an FdDataCollection.
%
% SYNTAX:
% c = readasciifolder('C:\My\Path')
% 	Read all "*.csv" files in the given directory.
% c = readasciifolder('C:\My\Path+')
% 	Read all "*.csv" files in the given directory and its subdirectories.
% c = readasciifolder('C:\My\Path\*.dat')
% 	Explicitly give the extension of the ASCII files to read.
% c = readasciifolder('C:\My\Path', <any arguments to readasciifile>)
% 	Any additional arguments are passed on directly to "readasciifile". See
% 	that function for details.
%
% INPUT:
% directory = name of a directory with ASCII files. End the directory name
%       with a '+' sign to recurse into subdirectories.
% 		It is also possible to explicitly give a filter in the form "*.ext",
% 		to specify the extension of the files to read.
%
% OUTPUT:
% c = an FdDataCollection.
%
% SEE ALSO:
% readasciifile

c = readdatafolder(directory, @(f) readasciifile(f, varargin{:}), 'csv');

end

