function [averageFd, Ferr] = averageFdData(fdc, varargin)
% AVERAGEFDDATA Returns averaged data for all F,d curves in the FdDataCollection 'fdc'.
%
% Averages all curves in the FdDataCollection 'fdc' to generate one averaged
% curve. Averaging is done by binning the data points into bins along the
% distance axis.
%
% SYNTAX:
% [averageFd, Ferr] = averageFdData(fdc);
%
% INPUT:
% fdc = an FdDataCollection.
%
% OUTPUT:
% averageFd = FdData object with the averaged F,d data.
% Ferr = vector with standard error of the mean or standard deviation values
%       for the averaged force values in 'averageFd.f'. See also "errMode"
%       below.
%
% KEY-VALUE PAIR ARGUMENTS:
% bins = vector of bin boundaries. If not given, defaults to 0.02 um bins
%       between the minimum and maximum distance found in the data.
% errMode = sem|sd (whether to use the standard deviation or standard error
%       of the mean for "Ferr").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parse & validate input

if ~isa(fdc, 'FdDataCollection')
    error('Invalid argument "fdc": FdDataCollection expected.');
end

defArgs = struct(...
                  'bins',                                   [] ...
                , 'errMode',                                'sem' ...
                );
args = parseArgs(varargin, defArgs);

switch args.errMode
    case 'sem'
        errFun = @(fdata) std(fdata)./sqrt(length(fdata));
    case 'sd'
        errFun = @(fdata) std(fdata);
    otherwise
        error('Invalid argument "errMode": unknown mode "%s".', args.errMode);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Generate averaged data

concatData = fdc.concatenatedData();

if isempty(args.bins)
    defaultBinResolution = 0.02;     % um
    args.bins = min(concatData.d):defaultBinResolution:max(concatData.d);
end

avgD = zeros(length(args.bins)-1,1);
avgF = zeros(length(args.bins)-1,1);
avgT = 1:length(args.bins);
Ferr = zeros(length(args.bins)-1,1);

for i = 2:length(args.bins)
    binLeft  = args.bins(i-1);
    binRight = args.bins(i);

    avgD(i) = (binLeft+binRight)/2;
    fdata = concatData.f(concatData.d > binLeft & concatData.d <= binRight);
    avgF(i) = mean(fdata);
    Ferr(i) = errFun(fdata);
end

averageFd = FdData('averaged data', avgF, avgD, avgT);

end
