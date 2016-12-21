classdef TWOMDataFile < handle

    properties (SetAccess=protected)

        Filename = '';
        SupportedFileFormatVersions = 4:6;

    end

    % ------------------------------------------------------------------------

    properties (Dependent)

        DateTime;
        FileFormatVersion;
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

            % Parse force channel specification
            if ischar(forceChan) || isnumeric(forceChan)
                [forceChanNames, friendlyForceChanNames] = n_parseForceChan(forceChan);
                forceChanNames         = {forceChanNames};
                friendlyForceChanNames = {friendlyForceChanNames};
            elseif iscell(forceChan)
                forceChanNames         = cell(length(forceChan),1);
                friendlyForceChanNames = cell(length(forceChan),1);
                for i = 1:length(forceChan)
                    [forceChanNames{i}, friendlyForceChanNames{i}] = n_parseForceChan(forceChan{i});
                end
            else
                error('Invalid argument "forceChan"');
            end

            % Parse distance channel specification
            if ischar(distChan)
                distChan = str2num(distChan);
            end
            if isnumeric(distChan) && isscalar(distChan)
                if distChan < 1 || distChan > 2
                    error('Distance channel out of range.');
                end
                distChanName = sprintf('Distance %d (um)', distChan);
            else
                error('Invalid argument "distChan".');
            end

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

                % Assemble FdData object containing data.
                fd = FdData(sprintf('%s - %s, %s', ...
                                    self.getTdmsProperty('name'), ...
                                    friendlyForceChanNames{j}, distChanName), ...
                            f, d, t);

                % ... metadata
                fd.metaData = self.tdmsStruct.Props;
                fn = fieldnames(self.tdmsStruct.FD_Data.Props);
                for k = 1:length(fn)
                    fd.metaData.(fn{k}) = self.tdmsStruct.FD_Data.Props.(fn{k});
                end

                % ... add to FdDataCollection
                fdc.add(fd);
            end

            % Rectify output: just a single FdData object instead of an
            % FdDataCollection when appropriate
            if ~iscell(forceChan) && (fdc.length == 1)
                fd = fdc.items{1};
            else
                fd = fdc;
            end

            % >> nested functions
            function [fcName, friendlyFcName] = n_parseForceChan(fc)
                if isnumeric(fc)
                    fcName         = sprintf('Force Channel %d (pN)', fc-1);
                    friendlyFcName = sprintf('Force Channel %d (pN)', fc);
                elseif ischar(fc) && length(fc) == 3 && fc(1) == 'c'
                    forceIdx = str2num(fc(2));
                    chanIdx = 2*(forceIdx-1);
                    friendlyFcName = sprintf('Force Trap %d', forceIdx);
                    if (fc(3) == 'x')
                        % ok
                        friendlyFcName = [friendlyFcName ' - X'];
                    elseif (fc(3) == 'y')
                        chanIdx = chanIdx + 1;
                        friendlyFcName = [friendlyFcName ' - Y'];
                    else
                        error('Invalid argument "forceChan".');
                    end
                    if chanIdx >= self.NForceChannels
                        error('Force channel index out of range.');
                    end
                    fcName = sprintf('Force Channel %d (pN)', chanIdx);
                    friendlyFcName = [friendlyFcName ' (pN)'];
                elseif ischar(fc) && length(fc) == 2 && fc(1) == 't'
                    forceIdx = str2num(fc(2));
                    if forceIdx*2 > self.NForceChannels
                        error('Force trap index out of range.');
                    end
                    fcName         = sprintf('Force Trap %d (pN)', forceIdx-1);
                    friendlyFcName = sprintf('Force Trap %d (pN)', forceIdx);
                else
                    error('Invalid argument "forceChan".');
                end
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

    end

end
