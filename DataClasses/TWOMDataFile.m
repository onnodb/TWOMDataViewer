classdef TWOMDataFile < handle

    properties (SetAccess=protected)

        Filename = '';
        SupportedFileFormatVersions = 4:6;

    end

    % ------------------------------------------------------------------------

    properties (Dependent)

        DateTime;
        FileFormatVersion;
        HasHiResFtData;
        ID;

        % Nx2 cell array, with metadata keys in the first column, and metadata
        % values in the second column.
        MetaData;

        NForceChannels;

    end

    % ------------------------------------------------------------------------

    properties (SetAccess=protected)

        % Structure for property values and group/channel structure.
        tdmsStruct = [];

        % TDMS struct for internal use by TDMS_*.
        tdmsMeta = [];

    end

    % ------------------------------------------------------------------------

    methods

        function [self] = TWOMDataFile(filename, varargin)
            self.Filename = filename;

            % Parse varargin.
            parseClassArgs(varargin, self);

            % Load TDMS file structure (no data, only metadata/properties).
            [output, self.tdmsMeta] = TDMS_readTDMSFile(filename, ...
                          'GET_DATA_OPTION',    'getSubset' ...
                        , 'OBJECTS_GET',        struct('groupsKeep', {{'Marks'}}) ...
                        );
            self.tdmsStruct = TDMS_dataToGroupChanStruct_v4(output);

            % Is this a valid TWOM data file?
            if ~self.isValidTWOMDataFile()
                error('This does not appear to be a valid TWOM data file.');
            end
            if ~any(self.FileFormatVersion == self.SupportedFileFormatVersions)
                error('This file format version (%d) is not supported.', self.FileFormatVersion);
            end
        end

        function [fd] = getFdData(self, forceChan, distChan)
            % GETFDDATA
            %
            % INPUT:
            % forceChan = either:
            %       - a string 'c1x', which gives force data for "trap 1 - X";
            %       - a string 't2', which gives the total vector sum for the
            %         force on trap 2;
            %       - a channel index, 1-based.
            %       - A cell array of the above.
            % distChan = 1 or 2
            %
            % OUTPUT:
            % fd = an FdData object, or, if forceChan was a cell array, an
            %       FdDataCollection.

            % Parse channel specs
            [forceChanNames, friendlyForceChanNames] = self.parseForceChannelSpecArg(forceChan);
            [distChanName, ~]                        = self.parseDistanceChannelSpec(distChan);

            % Retrieve needed subset of TDMS file data
            objGet = struct();
            objGet.fullPathsKeep = {['/''FD Data''/''' distChanName  ''''], ...
                                     '/''FD Data''/''Time (ms)'''};
            for i = 1:length(forceChanNames)
                objGet.fullPathsKeep{end+1} = ['/''FD Data''/''' forceChanNames{i} ''''];
            end
            data = TDMS_readTDMSFile(self.Filename, ...
                          'META_STRUCT',        self.tdmsMeta ...
                        , 'GET_DATA_OPTION',    'getSubset' ...
                        , 'OBJECTS_GET',        objGet ...
                        );

            % Assemble output FdDataCollection with requested data
            fdc = FdDataCollection();
            for j = 1:length(forceChanNames)
                % Find data channels for this requested dataset in TDMS output
                d = []; f = []; t = [];
                for i = 1:length(data.data)
                    if strcmpi(self.tdmsMeta.groupNames{i}, 'FD Data') ...
                            && strcmpi(self.tdmsMeta.chanNames{i}, forceChanNames{j})
                        f = data.data{i};
                    elseif strcmpi(self.tdmsMeta.groupNames{i}, 'FD Data') ...
                            && strcmpi(self.tdmsMeta.chanNames{i}, distChanName)
                        d = data.data{i};
                    elseif strcmpi(self.tdmsMeta.groupNames{i}, 'FD Data') ...
                            && strcmpi(self.tdmsMeta.chanNames{i}, 'Time (ms)')
                        t = data.data{i};
                    end
                end
                if isempty(d)
                    error('Error retrieving data: data not found.');
                end

                fd = self.makeFdDataObject(...
                            [' - ' friendlyForceChanNames{j} ', ' distChanName], ...
                            f, d, t);
                fdc.add(fd);
            end

            % Rectify output: just a single FdData object instead of an
            % FdDataCollection when appropriate.
            if ~iscell(forceChan) && (fdc.length == 1)
                fd = fdc.items{1};
            else
                fd = fdc;
            end
        end

        function [fd] = getHiResFtData(self, forceChan, timeRange)
            % GETHIRESFTDATA Returns high-resolution F,t data, if available
            %
            % INPUT:
            % forceChan = see 'getFdData'. Note that trap channels are not
            %       allowed here.
            % timeRange = if not empty (default), only force data for this time
            %       range is returned.
            %
            % OUTPUT:
            % fd = an FdData object, or, if forceChan was a vector, an
            %       FdDataCollection.

            if ~self.HasHiResFtData
                error('No high-resolution F,t data available.');
            end

            if nargin < 3
                timeRange = [];
            end

            [forceChanNames, friendlyForceChanNames] = self.parseForceChannelSpecArg(forceChan, false);

            if isempty(timeRange)
                subsGet = [];
            else
                if ~isvector(timeRange) || length(timeRange) ~= 2 || ~isnumeric(timeRange)
                    error('Invalid argument "timeRange".');
                end
                [t1Idx, t2Idx] = n_findTimeRange(timeRange);
                if (t1Idx == 0) || (t2Idx == 0)
                    error('Time range for high-resolution F,t data not found.');
                end
                subsGet = [t1Idx t2Idx];
            end

            objGet = struct();
            objGet.fullPathsKeep = { '/''Ft HiRes Data''/''Time (ms)''' };
            for i = 1:length(forceChanNames)
                objGet.fullPathsKeep{end+1} = ['/''Ft HiRes Data''/''' forceChanNames{i} ''''];
            end

            data = TDMS_readTDMSFile(self.Filename, ...
                          'META_STRUCT',        self.tdmsMeta ...
                        , 'GET_DATA_OPTION',    'getSubset' ...
                        , 'OBJECTS_GET',        objGet ...
                        , 'SUBSET_GET',         subsGet ...
                        , 'SUBSET_IS_LENGTH',   false ...
                        );
            % Find data channels for this requested dataset in TDMS output
            fdc = FdDataCollection();
            for j = 1:length(forceChanNames)
                f = []; t = [];
                for i = 1:length(data.data)
                    if strcmpi(self.tdmsMeta.groupNames{i}, 'Ft HiRes Data') ...
                            && strcmpi(self.tdmsMeta.chanNames{i}, forceChanNames{j})
                        f = data.data{i};
                    elseif strcmpi(self.tdmsMeta.groupNames{i}, 'Ft HiRes Data') ...
                            && strcmpi(self.tdmsMeta.chanNames{i}, 'Time (ms)')
                        t = data.data{i};
                    end
                end
                if isempty(t)
                    error('Error retrieving data: data not found.');
                end

                fd = self.makeFdDataObject(...
                            [' - ' friendlyForceChanNames{j}], ...
                            f, [], t);
                fdc.add(fd);
            end

            % Rectify output: just a single FdData object instead of an
            % FdDataCollection when appropriate
            if fdc.length == 1
                fd = fdc.items{1};
            else
                fd = fdc;
            end

            % >> nested functions
            function [t1, t2] = n_findTimeRange(range)
                data = TDMS_readTDMSFile(self.Filename, ...
                              'META_STRUCT',        self.tdmsMeta ...
                            , 'GET_DATA_OPTION',    'getSubset' ...
                            , 'OBJECTS_GET', ...
                                struct('fullPathsKeep', ...
                                       {{'/''Ft HiRes Data''/''Time (ms)'''}} ) ...
                            );
                t = [];
                for k = 1:length(data.data)
                    if strcmpi(self.tdmsMeta.groupNames{k}, 'Ft HiRes Data') ...
                            && strcmpi(self.tdmsMeta.chanNames{k}, 'Time (ms)')
                        t = data.data{k};
                    end
                end
                if isempty(t)
                    error('Error retrieving time data: data not found.');
                end
                t1 = findClosest_BinSearch(t, range(1));
                t2 = findClosest_BinSearch(t, range(2));
            end
            % << nested functions
        end

        function [marks] = getMarks(self)
            % GETMARKS Returns a list of data marks in the file
            %
            % OUTPUT:
            % marks = struct array with the following fields:
            %   .number = number of the data mark
            %   .comment = textual comment on the data mark as entered by
            %           the user during the measurement
            %   .t = timestamp (in ms)

            marks = struct('number', {}, 'comment', {}, 't', {});

            markNumbers = self.tdmsStruct.Marks.Mark__.data;
            markTimes   = self.tdmsStruct.Marks.Time__ms_.data;

            if ~isempty(markNumbers)
                for i = 1:length(markNumbers)
                    marks(end+1).number  = markNumbers(i);
                    marks(end)  .comment = self.tdmsStruct.Marks.Props.(sprintf('Mark_%d_comment', markNumbers(i)));
                    marks(end)  .t       = markTimes(i);
                end
            end
        end

        function [valid] = isValidTWOMDataFile(self)
            valid = ~isempty(self.FileFormatVersion) ...
                    && isfield(self.tdmsStruct, 'FD_Data');
        end

    end

    % ------------------------------------------------------------------------

    methods     % property getters

        function [val] = get.DateTime(self)
            s = self.getTdmsProperty('Date/time');
            val = datetime(s, 'InputFormat', 'yyyyMMdd-HHmmss');
        end

        function [val] = get.FileFormatVersion(self)
            val = uint8(sscanf(self.getTdmsProperty('File Format Version'), '%u'));
        end

        function [val] = get.HasHiResFtData(self)
            val = any(strcmpi(self.tdmsMeta.groupNames, 'Ft HiRes Data'));
        end

        function [val] = get.ID(self)
            val = self.getTdmsProperty('ID');
        end

        function [val] = get.MetaData(self)
            [rootPropNames, rootPropVals] = self.listTdmsProperties('');
            [fdPropNames,   fdPropVals  ] = self.listTdmsProperties('FD Data');

            metaKeys = [rootPropNames fdPropNames];
            metaVals = [rootPropVals  fdPropVals];

            val = [metaKeys' metaVals'];
        end

        function [val] = get.NForceChannels(self)
            val = self.getTdmsProperty('FD Data\Number of Force Channels');
        end

    end

    % ------------------------------------------------------------------------

    methods     % low-level methods

        function [fd] = makeFdDataObject(self, nameSuffix, f, d, t)
            fd = FdData(...
                    [self.getTdmsProperty('name') nameSuffix], ...
                    f, d, t ...
                    );

            % Add metadata
            % ... file-level metadata
            fd.metaData = self.tdmsStruct.Props;

            % ... 'FD Data' group-level metadata
            fn = fieldnames(self.tdmsStruct.FD_Data.Props);
            for i = 1:length(fn)
                fd.metaData.(fn{i}) = self.tdmsStruct.FD_Data.Props.(fn{i});
            end
        end

        function [val] = getTdmsProperty(self, path, default, varargin)
            % GETTDMSPROPERTY Get a single TDMS property value
            %
            % SYNTAX:
            % val = tdf.getTdmsProperty(path)
            % val = tdf.getTdmsProperty(path, default)
            % val = tdf.getTdmsProperty(path, default, Key, Value, ___)
            %
            % INPUT:
            % path = name of the property, if necessary prefixed by group
            %       and channel name, using '\' as a separator.
            %       For example 'Group\Channel\Property', 'Group\Property',
            %       or, for a property in the root of the file, simply
            %       'Property'.
            % default = what value to return if the property does not exist.
            %       If not given, and the property is not found, [] is returned.
            %
            % OUTPUT:
            % val = property value.
            %
            % KEY-VALUE PAIR ARGUMENTS:
            % CaseSensitive = whether or not group, channel and property names
            %       are case sensitive (default: false)

            if nargin < 3
                default = [];
            end
            defArgs = struct(...
                              'CaseSensitive',          false ...
                            );
            if nargin > 3
                args = parseArgs(varargin, defArgs, {'CaseSensitive'});
            else
                args = defArgs;
            end

            if args.CaseSensitive
                caseCmpFun = @strcmp;
            else
                caseCmpFun = @strcmpi;
            end
            val = default;

            pathParts = strsplit(path, '\');
            switch length(pathParts)
                case 1
                    groupName   = '';
                    channelName = '';
                    propName    = pathParts{1};
                case 2
                    groupName   = pathParts{1};
                    channelName = '';
                    propName    = pathParts{2};
                case 3
                    groupName   = pathParts{1};
                    channelName = pathParts{2};
                    propName    = pathParts{3};
                otherwise
                    error('Invalid parameter "path"');
            end

            for i = 1:length(self.tdmsMeta.rawDataInfo)
                if caseCmpFun(self.tdmsMeta.groupNames{i}, groupName) ...
                        && caseCmpFun(self.tdmsMeta.chanNames{i}, channelName)
                    % Match group/channel, now find property
                    for j = 1:length(self.tdmsMeta.rawDataInfo(i).propNames)
                        if caseCmpFun(self.tdmsMeta.rawDataInfo(i).propNames{j}, propName)
                            % Found it!
                            val = self.tdmsMeta.rawDataInfo(i).propValues{j};
                            return;
                        end
                    end
                end
            end
        end % function getTdmsProperty

        function [propNames, propVals] = listTdmsProperties(self, path, varargin)
            % LISTTDMSPROPERTIES Get all TDMS properties from a given path
            %
            % SYNTAX:
            % val = tdf.getTdmsProperty(path)
            %
            % INPUT:
            % path = which properties to return. For example, '' for the TDMS
            %       root properties; or 'Group'; or 'Group\Channel'.
            %
            % OUTPUT:
            % propNames = cell array with property names, or {} if none found.
            % propVals  = cell array with property values, or {} if none found.
            %
            % KEY-VALUE PAIR ARGUMENTS:
            % CaseSensitive = whether or not group, channel and property names
            %       are case sensitive (default: false)

            defArgs = struct(...
                              'CaseSensitive',          false ...
                            );
            args = parseArgs(varargin, defArgs, {'CaseSensitive'});

            if args.CaseSensitive
                caseCmpFun = @strcmp;
            else
                caseCmpFun = @strcmpi;
            end

            pathParts = strsplit(path, '\');
            switch length(pathParts)
                case 1
                    groupName   = pathParts{1};
                    channelName = '';
                case 2
                    groupName   = pathParts{1};
                    channelName = pathParts{2};
                otherwise
                    error('Invalid parameter "path"');
            end

            for i = 1:length(self.tdmsMeta.rawDataInfo)
                if caseCmpFun(self.tdmsMeta.groupNames{i}, groupName) ...
                        && caseCmpFun(self.tdmsMeta.chanNames{i}, channelName)
                    % Match group/channel: return properties
                    propNames = self.tdmsMeta.rawDataInfo(i).propNames;
                    propVals  = self.tdmsMeta.rawDataInfo(i).propValues;

                    [propNames, propVals] = n_filterProps(propNames, propVals);
                    return;
                end
            end

            propNames = {};
            propVals  = {};

            % >> nested functions
                function [n,v] = n_filterProps(n, v)
                    % Filter out any internal properties ('NI_*', etc.)
                    for k = length(n):-1:1
                        if strncmp(n{k}, 'NI_', 3) || strcmp(n{k}, 'name')
                            n(k) = [];
                            v(k) = [];
                        end
                    end
                end
            % << nested functions
        end % function listTdmsProperties

        function [tdmsChannelName, friendlyName] = parseDistanceChannelSpec(self, dc)
            if ischar(dc)
                dc = str2num(dc);
            end
            if isnumeric(dc) && isscalar(dc)
                if dc < 1 || dc > 2
                    error('Invalid distance channel specification: index out of range.');
                end
                tdmsChannelName = sprintf('Distance %d (um)', dc);
                friendlyName    = tdmsChannelName;
            else
                error('Invalid distance channel specification: unknown type.');
            end
        end

        function [tdmsChannelName, friendlyName] = parseForceChannelSpec(self, fc, allowTrapChannel)
            if nargin < 3
                allowTrapChannel = true;
            end

            if isnumeric(fc)
                % numeric fc
                tdmsChannelName = sprintf('Force Channel %d (pN)', fc-1);
                friendlyName    = sprintf('Force Channel %d (pN)', fc);

            elseif ischar(fc) && fc(1) == 'c' && length(fc) > 2
                % fc = 'c1x', 'c3y', etc.
                forceIdx = str2num(fc(2:end-1));
                tdmsChanIdx = 2*(forceIdx-1);

                friendlyName = sprintf('Force Trap %d', forceIdx);
                if fc(end) == 'x'
                    friendlyName = [friendlyName ' - X'];
                elseif fc(end) == 'y'
                    friendlyName = [friendlyName ' - Y'];
                    tdmsChanIdx = tdmsChanIdx + 1;
                else
                    error('Invalid force channel specification "%s": malformed X/Y channel spec.', fc);
                end
                friendlyName = [friendlyName ' (pN)'];

                if tdmsChanIdx >= self.NForceChannels
                    error('Invalid force channel specification "%s": channel index out of range.', fc);
                end
                tdmsChannelName = sprintf('Force Channel %d (pN)', tdmsChanIdx);

            elseif ischar(fc) && fc(1) == 't' && length(fc) > 1
                % fc = 't1', 't3', etc.
                if ~allowTrapChannel
                    error('Invalid force channel specification: trap channel is not allowed here.');
                end

                forceIdx = str2num(fc(2:end));
                if forceIdx*2 > self.NForceChannels
                    error('Invalid force channel specification "%s": channel index out of range.', fc);
                end

                tdmsChannelName = sprintf('Force Trap %d (pN)', forceIdx-1);
                friendlyName    = sprintf('Force Trap %d (pN)', forceIdx);

            else
                error('Invalid force channel specification "%s".', fc);
            end
        end

        function [tdmsChannelNames, friendlyNames] = parseForceChannelSpecArg(self, fc, allowTrapChannel)
            if nargin < 3
                allowTrapChannel = true;
            end

            if ischar(fc) || (isnumeric(fc) && isscalar(fc))
                fc = {fc};
            elseif iscell(fc)
                % ok
            elseif isnumeric(fc) && isvector(fc)
                fc = num2cell(fc);
            else
                error('Invalid force channel specification: unknown type.');
            end

            tdmsChannelNames = cell(length(fc),1);
            friendlyNames    = cell(length(fc),1);
            for i = 1:length(fc)
                [tdmsChannelNames{i}, friendlyNames{i}] = self.parseForceChannelSpec(fc{i}, allowTrapChannel);
            end
        end

    end

end
