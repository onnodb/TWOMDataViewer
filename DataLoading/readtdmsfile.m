function [fd] = readtdmsfile(filename, forceChannel, distanceChannel, beadDiameter)
% READTDMSFILE Read data from a TDMS data file.
%
% This function reads force-extension data from a LabVIEW TDMS file generated
% by the TWOM/Lumicks software (the software controlling the instruments
% used for measuring the data in the paper). This will only be useful if
% you either use this software yourself, or if you would like to read the
% raw data from the paper.
%
% SYNTAX:
% fd = readtdmsfile(filename);
% fd = readtdmsfile(filename, forceChannel);
% fd = readtdmsfile(filename, highResForceChannel);
% fd = readtdmsfile(filename, forceChannel, distanceChannel);
% fd = readtdmsfile(filename, forceChannel, distanceChannel, beadDiameter);
%
% INPUT:
% filename = path to the .tdms file; leave empty to browse for a file.
% forceChannel = string in the format '(c|t)<n>'; 'c' indicates a channel
%   force, 't' a trap force; '<n>' is the 1-based index of the
%   channel/trap (default: 'c1').
% highResForceChannel = a string in the format 'c<n>*', where '<n>' is the
%   1-based index of the channel. In this case, no distance values are read.
% distanceChannel = 1 or 2; indicates the distance channel to use (default: 1).
% beadDiameter = bead diameter (in um) to subtract from all distance data.
%                If the string 'auto' is given (default): tries to find the bead
%                diameter in the file's metadata.
%
% OUTPUT:
% fd = FdData object.
%   If high-resolution force data is read, distance values in the object are
%   empty (NaN).
%
% EXAMPLES:
% >> readtdmsfile;
% Browse for a TWOM data file, and load it using the default settings
% (force channel 1 and distance channel 1).
%
% >> readtdmsfile('mydata.tdms', 'c1', 1);
% Read Fd data from force channel 1 and distance channel 1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parse & validate input

if nargin < 1 || isempty(filename)
    [uifile, uipath] = uigetfile(...
                                 {'*.tdms', 'TDMS data files (*.tdms)'; ...
                                  '*.*', 'All files (*.*)'}, ...
                                 'Select file'...
                                );
    if uifile == 0
        fd = [];
        return
    end
    filename = fullfile(uipath, uifile);
end
if nargin < 2
    forceChannel = 'c1';
end
if nargin < 3
    distanceChannel = 1;
end
if ischar(distanceChannel)
    % Allow distanceChannel to be a string, which is more consistent with
    % the 'forceChannel' parameter.
    distanceChannel = str2double(distanceChannel);
end
if nargin < 4
    beadDiameter = 'auto';
end

if ~isValidForceChannelSpec(forceChannel)
	error('Invalid force channel specification "%s".', forceChannel);
end
if ~any(distanceChannel == [1 2])
	error('Invalid distance channel "%d".', distanceChannel);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Read data

filename = normalizepath(filename);

data = TDMS_getStruct(filename);

[~, basename, ~] = fileparts(filename);

if forceChannel(end) == '*'
    bareForceChannel = forceChannel(1:end-1);
    % High-res force data
    fData = data.Ft_HiRes_Data.(forceChannelToTDMSChannelName(bareForceChannel)).data;
    fd = FdData(...
                basename, ...
                fData, ...
                NaN(size(fData)), ...
                data.Ft_HiRes_Data.Time__ms_.data, ...
                getMetaData(data, bareForceChannel, distanceChannel), ...
                struct() ...
                );
else
    % Normal force-distance data
    fd = FdData(...
                basename, ...
                data.FD_Data.(forceChannelToTDMSChannelName(forceChannel)).data, ...
                data.FD_Data.(distanceChannelToTDMSChannelName(distanceChannel)).data, ...
                data.FD_Data.Time__ms_.data, ...
                getMetaData(data, forceChannel, distanceChannel), ...
                getMarks(data) ...
                );

    if ischar(beadDiameter) && strcmpi(beadDiameter, 'auto')
        % Auto-detect bead diameter.
        beadDiameter = getBeadDiameterFromMetaData(data);
    end
    if beadDiameter ~= 0
        % Subtract bead diameter.
        fd = fd.shift('d', -beadDiameter);
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function [valid] = isValidForceChannelSpec(forceChannel)
		valid = ischar(forceChannel) ...
			    && (~isempty(regexp(forceChannel, '^[ct][0-9]+$')) ...
                     || ~isempty(regexp(forceChannel, '^c[0-9]+\*$')));
    end

    function [name] = forceChannelToTDMSChannelName(fc, isError)
        if nargin < 2
            isError = false;
        end

        if fc(1) == 't'
            channelType = 'Trap';
        else
            channelType = 'Channel';
        end
        if isError
            stdevType = 'STDEV';
		else
			stdevType = '';
        end

		name = sprintf('Force_%s_%d_%s_pN_', ...
						channelType, ...
						sscanf(fc(2:end), '%d') - 1, ...
						stdevType ...
						);
    end

    function [name] = distanceChannelToTDMSChannelName(dc)
		name = sprintf('Distance_%d__um_', dc);
    end

    function [beadDiameter] = getBeadDiameterFromMetaData(data)
        beadDiameter = 0;

        if isfield(data, 'FD_Data') && isfield(data.FD_Data, 'Props') && ...
           		isfield(data.FD_Data.Props, 'Bead_Diameter__um_')
			beadDiameter = data.FD_Data.Props.Bead_Diameter__um_;
			return
        end

        warning('No bead diameter metadata found; assuming zero bead size.');
    end

    function [metaData] = getMetaData(data, forceChannel, distanceChannel)
        metaData = struct();

        forceChannelName = forceChannelToTDMSChannelName(forceChannel);

        metaData.id                 = getFileId(data);
        metaData.file               = filename;
        metaData.forceChannel       = forceChannel;
        metaData.distanceChannel    = distanceChannel;
        metaData.originalFile       = getMetaDataIfExists(data, 'Props.name');
        metaData.dateTime           = convertMetaDataDateTime(...
                                        getMetaDataIfExists(data, 'Props.Date_time') ...
                                        );
        metaData.experiment         = getMetaDataIfExists(data, 'Props.Experiment');
        metaData.moleculeNo         = str2num(getMetaDataIfExists(data, 'Props.Molecule__'));
        metaData.fileNo             = str2num(getMetaDataIfExists(data, 'Props.File__'));
        metaData.description        = getMetaDataIfExists(data, 'Props.Description');
        metaData.beadDiameter       = getMetaDataIfExists(data, 'FD_Data.Props.Bead_Diameter__um_');
        metaData.distanceCalibration= getMetaDataIfExists(data, 'FD_Data.Props.Distance_Calibration__nm_pix_');
        metaData.forceCalibration   = getMetaDataIfExists(data, ...
                                        ['FD_Data.' forceChannelName '.Props.Force_Calibration__pN_V_']);
        metaData.forceOffset        = getMetaDataIfExists(data, ...
                                        ['FD_Data.' forceChannelName '.Props.Force_Offset__V_']);
        metaData.cornerFrequency    = getMetaDataIfExists(data, ...
                                        ['FD_Data.' forceChannelName '.Props.Corner_Frequency__Hz_']);
        metaData.trapStiffness      = getMetaDataIfExists(data, ...
                                        ['FD_Data.' forceChannelName '.Props.Trap_stiffness__pN_m_']);

    end

    function [fileId] = getFileId(data)
        fileId = '';
        if isfield(data, 'Props')
            if isfield(data.Props, 'ID')
                fileId = data.Props.ID;
            end
        end
    end

    function [mdStr] = getMetaDataIfExists(data, path)
        mdStr = '';

        pathParts = strsplit(path, '.');
        for part = pathParts
            if ~isfield(data, part)
                return;
            end
            data = data.(part{:});
        end

        mdStr = data;
    end

    function [dt] = convertMetaDataDateTime(s)
        [tokens, ~] = regexp(s, '(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})', 'tokens', 'match');
        if ~isempty(tokens)
            dtdata = cellfun(@str2num, tokens{1});
            dt = datenum(dtdata);
        end
    end

    function [marks] = getMarks(data)
        marks = struct();
        if isfield(data, 'Marks')
            for iMark = 1:length(data.Marks.Mark__.data)
                markNo = data.Marks.Mark__.data(iMark);
                marks(iMark).mark    = markNo;
                marks(iMark).time    = data.Marks.Time__ms_.data(iMark);
				marks(iMark).comment = data.Marks.Props.(sprintf('Mark_%d_comment', markNo));
            end
        end
    end

end

