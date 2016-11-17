%% Initialization script for the FDFIT suite
% Run this script to automatically add all the necessary folders to the
% MATLAB path.

% Add all subfolders (excluding Mercurial/Svn meta folders) to the search path
thisScriptFile = mfilename('fullpath');
[thisPath, ~, ~] = fileparts(thisScriptFile);
newPath = genpath(thisPath);
if filesep == '\'
    filesepStr = '\\\';
else
    filesepStr = '/';
end
newPath = regexprep(newPath, ['([^' pathsep ']+' filesepStr '.(hg|svn|git)[^' pathsep ']*' pathsep ')'], '');
addpath(newPath);
clear thisScriptFile thisPath newPath filesepStr

% Ignore warnings caused by draggable cursors.
warning('off', 'MATLAB:hg:EraseModeIgnored');
