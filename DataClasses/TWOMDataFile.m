classdef TWOMDataFile < handle

    properties (SetAccess=protected)

        Filename = '';
        SupportedFileFormatVersions = 4:6;

    end

    % ------------------------------------------------------------------------

    properties (Dependent)

        FileFormatVersion;
        ID;

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

    methods   % property getters

        function [val] = get.FileFormatVersion(self)
            val = uint8(sscanf(self.getTdmsProperty('File_Format_Version'), '%u'));
        end

        function [val] = get.ID(self)
            val = self.getTdmsProperty('ID');
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=protected)

        function [val] = getTdmsProperty(self, path, default)
            if nargin < 3
                default = [];
            end

            val = default;

            data = self.tdmsStruct;
            pathParts = strsplit(path, '/');
            propName = pathParts{end};
            for propPath = pathParts(1:end-1)
                if ~isfield(data, propPath)
                    return;
                end
                data = data.(propPath{:});
            end

            if isfield(data.Props, propName)
                val = data.Props.(propName);
            end
        end

    end

end
