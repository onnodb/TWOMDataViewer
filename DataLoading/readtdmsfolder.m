function [c] = readtdmsfolder(directory, varargin)
% READTDMSFOLDER Read a directory with TDMS data files into an FdDataCollection.
%
% SYNTAX:
% c = readtdmsfolder('C:\My\Path')
% 	Read all "*.tdms" files in the given directory.
% c = readtdmsfolder('C:\My\Path+')
% 	Read all "*.tdms" files in the given directory and its subdirectories.
% c = readtdmsfolder('C:\My\Path\*.dat')
% 	Explicitly give the extension of the TDMS files to read.
% c = readtdmsfolder('C:\My\Path', <any arguments to readtdmsfile>)
% 	Any additional arguments are passed on directly to "readtdmsfile". See
% 	that function for details.
%
% INPUT:
% directory = name of a directory with TDMS data files. End the directory name
%       with a '+' sign to recurse into subdirectories.
% 		It is also possible to explicitly give a filter in the form "*.ext",
% 		to specify the extension of the files to read.
%
% OUTPUT:
% c = an FdDataCollection.
%
% SEE ALSO:
% readtdmsdata

c = readdatafolder(directory, @(f) readtdmsfile(f, varargin{:}), 'tdms');

end
