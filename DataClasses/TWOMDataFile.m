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
            [output, self.tdmsMeta] = TDMS_readTDMSFile(filename, 'GET_DATA_OPTION', 'getnone');
            self.tdmsStruct = TDMS_dataToGroupChanStruct_v4(output);

            % Is this a valid TWOM data file?
            if ~self.isValidTWOMDataFile()
                error('This does not appear to be a valid TWOM data file.');
            end
            if ~any(self.FileFormatVersion == self.SupportedFileFormatVersions)
                error('This file format version (%d) is not supported.', self.FileFormatVersion);
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
