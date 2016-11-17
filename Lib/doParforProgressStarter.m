function [ppm] = doParforProgressStarter(msg, n)
% Simple wrapper around the 'ParforProgressStarter2' function of the 
% 'ParforProgress' library. If this library is not installed, a dummy
% object is returned.

if exist('ParforProgressStarter2', 'file') == 2
    ppm = ParforProgressStarter2(msg, n);
else
    ppm = ParforProgressDummy(msg, n);
end

end

