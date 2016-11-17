function [c] = readdatafolder(directory, readDataFun, defaultExt)
% READDATAFOLDER Read a directory with data files (internal function).
%
% This is a function for internal use by "readasciifolder" and
% "readtdmsfolder".
%
% SEE ALSO:
% readasciifolder, readtdmsfolder

c = FdDataCollection();

directory = normalizepath(directory);

% Recurse into subdirectories if requested
if directory(end) == '+'
    directory = directory(1:end-1);     % remove final '+'
	recurse = true;
else
	recurse = false;
end

% Has an extension been given explicitly?
[path, name, ext] = fileparts(directory);
if strcmp(name, '*')
	filterStr = [name ext];
	directory = path;
else
	filterStr = ['*.' defaultExt];
end

% Process given directory.
files = dir(fullfile(directory, filterStr));

for i = 1:length(files)
	curFile = fullfile(directory, files(i).name);
    fprintf('Reading %s...\n', curFile);
	c.add(readDataFun(curFile));
end

% Recurse into subdirectories if requested.
if recurse
	recurseSubdirectories(directory);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	function recurseSubdirectories(directory)
		listing = dir(directory);

		for j = 1:length(listing)
			if listing(j).isdir && ~any(strcmp(listing(j).name, {'.','..'}))
				c.add(...,
					readdatafolder(...
						fullfile(directory, listing(j).name, filterStr), ...
						readDataFun, defaultExt ...
						) ...
					);
				recurseSubdirectories(fullfile(directory, listing(j).name));
			end
		end
	end

end
