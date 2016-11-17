function [homedir] = gethomedir()
% GETHOMEDIR Returns the user's home directory
%
% Uses the Registry on Windows systems, and uses Java on other systems.

if ispc
    homedir = winqueryreg('HKEY_CURRENT_USER',...
        ['Software\Microsoft\Windows\CurrentVersion\' ...
         'Explorer\Shell Folders'],'Personal');
else
    homedir = char(java.lang.System.getProperty('user.home'));
end
