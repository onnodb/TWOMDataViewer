classdef FdData < matlab.mixin.Copyable
    % FDDATA Object storing F,d,t or F,t data
    %
    % This is a simple data storage object for storing force-extension data
    % (plus associated time data); or, alternatively, force-time data.
    %
    % FdData objects also support some other convenience features, such as:
    %
    %  - Tagging: each object can have one or more optional tags. These can
    %    be used for filtering. This is especially useful when combined with
    %    the "FdDataCollection" class.
    %
    %  - Various methods for cropping and scaling data are available.
    %
    %  - Data manipulation methods (such as the aforementioned cropping and
    %    scaling) keep track of their actions in a "history" list. This is
    %    really just a cell array of strings, with each string recording
    %    an action that has been performed. See the "history" property for
    %    more information.
    %
    %  - There is support for a struct property containing metadata about
    %    the force-extension data contained in the object.

    properties (Dependent=true)

        % Distance values (um)
        % NOTE: Can be empty, in case only F,t data is stored.
        d;

        % Force values (pN)
        f;

        % Time values (ms)
        t;

        % ----- Read-only properties

        % Does the object contain distance data?
        hasDistanceData;

        % Associated tags combined into one string
        tagString;

        % Number of data points.
        length;

    end

    properties

        % Data marks.
        % This is a minor feature for supporting 'data marks' from the
        % Tweez-O-Matic optical tweezers software. A data mark is really
        % just a time coordinate ("time" field) with an associated number
        % ("mark") and optional comment ("comment", string). These are
        % like "bookmarks" for time points in the data.
        marks = struct('comment', {}, 'mark', {}, 'time', {});

        % Metadata (such as filename, ID, description, etc.)
        metaData = struct();

        % Optional name associated with the data (could be a filename,
        % for example).
        name = '';

    end

    properties (SetAccess=protected)

        % Manipulation history of the FdData object.
        % This is a cell array of strings, each string encoding the
        % call to one of the manipulation functions (e.g., "subset").
        % The list is sorted in most-recent-first order.
        % (Note: row vector)
        history = {};

        % List of associated tags (strings) for categorization and
        % organization of the data. See, e.g., "addTag" and "hasTag".
        tags = {};

    end

    % ------------------------------------------------------------------------

    properties (Access=protected)

        % Internal storage for actual force/distance/time data.
        % (column 1: time; column 2: force; column 3: distance)
        data = [];

    end


    % ------------------------------------------------------------------------

    methods

        function [self] = FdData(varargin)
            % FDDATA Constructor.
            %
            % SYNTAX:
            % fd = FdData();
            % fd = FdData('name');
            % fd = FdData('name', f_values, d_values, t_values);
            % fd = FdData('name', f_values, d_values, t_values, metaData);
            % fd = FdData('name', f_values, d_values, t_values, metaData, marks);
            % fd = FdData('name', f_values, d_values, t_values, metaData, marks, history);
            %
            % INPUT:
            % f_values = force values (pN)
            % d_values = distance values (um); allowed to be an empty array []
            % t_values = time values (ms)
            % metaData = metadata struct (see "metaData" property).
            % marks = data marks information (see "marks" property).
            % history = history cellstring (see "history" property).

            if ~isempty(varargin)
                self.name = varargin{1};
                if nargin > 1 && nargin < 4
                    error('FdData:invalidArgument', 'Invalid arguments');
                end
                if nargin >= 4
                    self.setFDT(varargin{2:4});
                end
                if nargin >= 5
                    if ~isstruct(varargin{5})
                        error('FdData:invalidArgument', 'Invalid argument "metaData": struct expected');
                    end
                    self.metaData = varargin{5};
                end
                if nargin >= 6
                    if ~isValidMarks(varargin{6})
                        error('FdData:invalidArgument', 'Invalid argument "marks": marks struct array expected');
                    end
                    self.marks = varargin{6};
                end
                if nargin >= 7
                    if ~isValidHistory(varargin{7})
                        error('FdData:invalidArgument', 'Invalid argument "history": cell array with strings expected');
                    end
                    self.history = varargin{7}(:)';  % should be a row vector
                end
                if nargin > 7
                    error('FdData:invalidArgument', 'Invalid arguments');
                end
            end

                % ----- nested function
                function [valid] = isValidMarks(marksArray)
                    valid = false;
                    if ~isstruct(marksArray)
                        return
                    end
                    if ~isempty(fieldnames(marksArray)) && ...
                       ~isequal( sort(fieldnames(marksArray)), {'comment';'mark';'time'} )
                        return
                    end
                    valid = true;
                end

                function [valid] = isValidHistory(histArray)
                    valid = false;
                    if ~iscell(histArray)
                        return
                    end
                    if ~isempty(histArray)
                        if ~isvector(histArray)
                            return
                        end
                        for i = 1:length(histArray)
                            if ~ischar(histArray{i})
                                return
                            end
                        end
                    end
                    valid = true;
                end
        end

        function addHistory(self, historyItem)
            % ADDHISTORY Add an item to the object's history list.
            %
            % Note that the most recent event is at the front of the history
            % list.

            self.history = [ {historyItem} self.history ];
        end

        function addTag(self, varargin)
            % ADDTAG Associate a user tag with the object.
            %
            % SYNTAX:
            % fd.addTag('tagName')
            % fd.addTag('tagName', 'tagName2', ...)

            if length(varargin) > 1
                for tag = varargin
                    self.addTag(tag{:});
                end
            else
                if ~self.hasTag(varargin{1})
                    self.tags = [self.tags varargin{1}];
                end
            end
        end

        function [fdSubset] = betweenMarks(self, mark1, mark2)
            % BETWEENMARKS Returns a fragment of the data between two data marks.
            %
            % SYNTAX:
            % sub = fd.betweenMarks(3, 4);
            %   All data between marks numbers 3 and 4.
            % sub = fd.betweenMarks('mark1', 'mark2');
            %   All data between the first mark with comment 'mark1', and
            %   the first mark with comment 'mark2'.
            %
            % INPUT:
            % mark1 = index of the first mark; or comment for the first mark
            %       (case-insensitive).
            % mark2 = (as mark1)
            %
            % OUTPUT:
            % fdSubset = data fragment, or [] if data marks were not found.
            %
            % NOTE: Calls "fragment" internally, and thus records a history
            % item.

            if ischar(mark1)
                mark1 = markCommentToMarkIdx(mark1);
            end
            if ischar(mark2)
                mark2 = markCommentToMarkIdx(mark2);
            end

            if isempty(mark1) || isempty(mark2)
                fdSubset = [];
                return
            end

            indices = [...
                       find( (self.data(:,3) >= self.marks(mark1).time), 1, 'first') ...
                       find( (self.data(:,3) >= self.marks(mark2).time), 1, 'first') ...
                      ];
            idx1 = min(indices);
            idx2 = max(indices);

            fdSubset = self.fragment(idx1,idx2);

                % ----- Nested function
                function [idx] = markCommentToMarkIdx(markComment)
                    idx = find(strcmpi(markComment, {self.marks.comment}), 1, 'first');
                end
        end

        function disp(self, varargin)
            % DISP Displays the contents of the object.
            %
            % SYNTAX:
            % disp(fd)
            % fd.disp()
            % fd.disp('full')
            %   Also displays the full metadata.

            fulldisplay = (length(varargin) >= 1 && strcmpi(varargin{1}, 'full'));

            if isempty(self.name)
                dispName = '<untitled>';
            else
                dispName = self.name;
            end

            fprintf('[ FD DATA OBJECT ]\n');
            fprintf('|--- Name:     %s\n', dispName);
            if ~isempty(fieldnames(self.metaData))
                fprintf('|--- Metadata: ');
                if fulldisplay
                    fprintf('\n');
                    dispMetaData(self);
                else
                    fprintf('...\n');
                end
            end
            if ~isempty(self.tags)
                fprintf('|--- Tags:     %s\n', self.tagString);
            end
            if ~isempty(self.marks)
                fprintf('|--- Marks:    ');
                if fulldisplay
                    fprintf('\n');
                    dispMarks(self);
                else
                    fprintf('...\n');
                end
            end
            if ~isempty(self.history)
                fprintf('|--- History\n');
                for i = 1:length(self.history)
                    fprintf('     |--- %s\n', self.history{i});
                end
            end

            % ----- Nested function >
            function dispMarks(self)
                if ~isempty(self.marks) && ~isempty(fieldnames(self.marks))
                    for j = 1:length(self.marks)
                        fprintf( ...
                            '|    |--- %3d @%-8d: %-70.70s\n', ...
                            self.marks(j).mark, ...
                            self.marks(j).time, ...
                            self.marks(j).comment ...
                            );
                    end
                end
            end
            function dispMetaData(self)
                fn = fieldnames(self.metaData);
                for j = 1:length(fn)
                    curVal = self.metaData.(fn{j});
                    if iscellstr(curVal)
                        fprintf('|    |--- %-25.25s:\n', [fn{j} '{}']);
                        for k = 1:length(curVal)
                            fprintf( ...
                                '|    |                               %-60.60s\n', ...
                                curVal{k} ...
                                );
                        end
                    else
                        if isnumeric(curVal)
                            formatStr = '%g';
                        else
                            formatStr = '%s';
                        end
                        fprintf( ...
                            ['|    |--- %-25.25s: ' formatStr '\n'], ...
                            fn{j}, curVal ...
                            );
                    end
                end
            end
        end

        function [fdFragment] = fragment(self, startIdx, endIdx)
            % FRAGMENT Returns a fragment of the data.
            %
            % INPUT:
            % startIdx = start index of the fragment.
            % endIdx = end index of the fragment.
            %
            % NOTE: Records a history item 'fragment(%d:%d)'.

            fdFragment = copy(self);
            fdFragment.data = self.data(startIdx:endIdx,:);
            fdFragment.addHistory(sprintf('fragment(%d:%d)', startIdx, endIdx));
        end

        function [b] = hasMetaData(self, varargin)
            % HASMETADATA Checks for the existence of certain metadata.
            %
            % SYNTAX:
            % fd.hasMetaData('keyName')
            %   Checks for the existence of a metadata key (a field in the
            %   "metaData" struct).
            %
            % fd.hasMetaData('keyName', 'keyValue')
            %   Checks if a certain metadata key has a specific value.
            %
            % fd.hasMetaData('keyName', 'keyValueMin', 'keyValueMax')
            %   Checks if a metadata key has a value that is in the
            %   specified range.
            %   Note: This only works for numerical metadata.

            switch length(varargin)
                case 1
                    b = isfield(self.metaData, varargin{1});
                case 2
                    if isfield(self.metaData, varargin{1})
                        b = isequal(self.metaData.(varargin{1}), varargin{2});
                    else
                        b = false;
                    end
                case 3
                    if isfield(self.metaData, varargin{1})
                        if ~isnumeric(self.metaData.(varargin{1}))
                            error('Metadata key "%s" is not numeric', varargin{1});
                        end
                        b = (self.metaData.(varargin{1}) >= varargin{2}) ...
                            && (self.metaData.(varargin{1}) <= varargin{3});
                    else
                        b = false;
                    end
                otherwise
                    error('FdData:invalidArgument', 'Invalid arguments');
            end
        end

        function [b] = hasTag(self, varargin)
            % HASTAG Checks if a certain tag is associated with this object.
            %
            % SYNTAX:
            % fd.hasTag('myTag')
            %   Checks for the tag 'myTag' (case-insensitive)
            %
            % fd.hasTag('myTag1', 'myTag2', ...)
            %   Returns a boolean array, one for each tag specified

            if length(varargin) > 1
                b = zeros(1,numel(varargin));
                for iTag = 1:numel(varargin)
                    b(iTag) = self.hasTag(varargin{iTag});
                end
            else
                b = any(strcmpi(varargin{1}, self.tags));
            end
        end

        function removeTag(self, varargin)
            % REMOVETAG Removes a user tag from the object.
            %
            % SYNTAX:
            % fd.removeTag('myTag')
            %   Removes the tag 'myTag' (case-insensitive)
            %
            % fd.removeTag('myTag1', 'myTag2', ...)
            %   Removes all specified tags.
            %
            % NOTE: A warning is emitted if a tag was not found.

            if length(varargin) > 1
                for tag = varargin
                    self.removeTag(tag{:});
                end
            else
                idx = find(strcmpi(varargin{1}, self.tags), 1, 'first');
                if isempty(idx)
                    warning('FdData:tagNotFound', 'Cannot remove tag "%s": tag not found', varargin{1});
                else
                    self.tags(idx) = [];
                end
            end
        end

        function [fdScaled] = scale(self, axis, factor)
            % SCALE Scales all the data along a particular axis.
            %
            % Multiplies all values on a particular axis with by an amount
            % 'factor'.
            %
            % SYNTAX:
            % shift = fd.scale('f', 1.5);
            %
            % INPUT:
            % axis = which of the axes to scale ('d', 'f', or 't').
            % factor = multiplication factor.
            %
            % NOTE: Records a history item 'scale(%s, %g)'.

            fdScaled = copy(self);

            switch axis
                case 'd'
                    if self.hasDistanceData
                        fdScaled.d = fdScaled.d .* factor;
                    end
                case 'f'
                    fdScaled.f = fdScaled.f .* factor;
                case 't'
                    fdScaled.t = fdScaled.t .* factor;
                otherwise
                    error('FdData:invalidArgument', 'Invalid argument "axis": "%s"', axis);
            end

            fdScaled.addHistory(sprintf('scale(%s, %g)', axis, factor));
        end

        function setFDT(self, newF, newD, newT)
            % SETFDT Updates the F, d and t data all at once.
            %
            % NOTE: newD is allowed to be empty, in case this FdData object is
            % only used to store F,t data.

            if ~isreal(newF) || ~isreal(newD) || ~isreal(newT)
                error('FdData:invalidArgument', 'Invalid arguments: real vectors expected');
            end
            if length(newT) ~= length(newF) || ...
                    ( (length(newT) ~= length(newD)) && ~isempty(newD) )
                error('FdData:invalidDataDimension', 'Invalid data dimensions: lengths of new F,D,T should be equal');
            end

            if isempty(newD)
                self.data = [newT(:) newF(:)];
            else
                self.data = [newT(:) newF(:) newD(:)];
            end
        end

        function [fdShifted] = shift(self, axis, amount)
            % SHIFT Shifts all the data along a particular axis.
            %
            % Adds an offset 'amount' to all values on a particular axis.
            %
            % SYNTAX:
            % shift = fd.shift('d', -1);        % shift one um to the left
            % shift = fd.shift('f', 1.5);       % add a 1.5 pN offset to the force
            %
            % INPUT:
            % axis = which of the axes to shift ('d', 'f', or 't').
            % amount = how much to shift.
            %
            % NOTE: Records a history item 'shift(%s, %g)'.

            fdShifted = copy(self);

            switch axis
                case 'd'
                    if self.hasDistanceData
                        fdShifted.d = fdShifted.d + amount;
                    end
                case 'f'
                    fdShifted.f = fdShifted.f + amount;
                case 't'
                    fdShifted.t = fdShifted.t + amount;
                otherwise
                    error('FdData:invalidArgument', 'Invalid argument "axis": "%s"', axis);
            end

            fdShifted.addHistory(sprintf('shift(%s, %g)', axis, amount));
        end

        function [fdSubset] = subset(self, axis, range)
            % SUBSET Returns a subset of the data
            %
            % Returns all the data within a specific range, along a given axis.
            %
            % SYNTAX:
            % fdSubset = fd.subset(axis, range);
            %
            % INPUT:
            % axis = which of the axes to filter ('d', 'f', or 't').
            % range = 1x2 vector [min max].
            %
            % EXAMPLES:
            % sub = fd.subset('d', [5 15]);
            % sub = fd.subset('f', [0 30]);
            % sub = fd.subset('t', [5 10]);
            %
            % NOTE: Records a history item 'subset(%s, %g:%g)'.

            switch axis
                case 'd'
                    if self.hasDistanceData
                        subset_indices = self.d >= range(1) & self.d <= range(2);
                    else
                        subset_indices = true(size(self.data,1),1);
                    end
                case 'f'
                    subset_indices = self.f >= range(1) & self.f <= range(2);
                case 't'
                    subset_indices = self.t >= range(1) & self.t <= range(2);
                otherwise
                    error('FdData:invalidArgument', 'Invalid argument "axis": "%s"', axis);
            end

            fdSubset = copy(self);
            fdSubset.data = self.data(subset_indices,:);
            fdSubset.addHistory(sprintf('subset(%s, %g:%g)', axis, range(1), range(2)));
        end

    end

    % ------------------------------------------------------------------------

    methods

        function [d] = get.d(self)
            if self.hasDistanceData
                d = self.data(:,3);
            else
                d = [];
            end
        end

        function set.d(self, newD)
            if self.hasDistanceData
                if length(newD) == size(self.data, 1)
                    self.data(:,3) = newD;
                else
                    error('FdData:invalidDataDimension', 'Invalid length for new "d" value');
                end
            else
                error('FdData:noDistanceData', 'This FdData object does not contain distance data');
            end
        end

        function [f] = get.f(self)
            f = self.data(:,2);
        end

        function set.f(self, newF)
            if length(newF) == size(self.data, 1)
                self.data(:,2) = newF;
            else
                error('FdData:invalidDataDimension', 'Invalid length for new "f" value');
            end
        end

        function [val] = get.hasDistanceData(self)
            val = (size(self.data,2) == 3);
        end

        function set.metaData(self, newMetaData)
            if ~isstruct(newMetaData)
                error('FdData:invalidArgument', 'Invalid metadata: struct expected');
            end

            self.metaData = newMetaData;
        end

        function [t] = get.t(self)
            t = self.data(:,1);
        end

        function set.t(self, newT)
            if length(newT) == size(self.data, 1)
                self.data(:,1) = newT;
            else
                error('FdData:invalidDataDimension', 'Invalid length for new "t" value');
            end
        end

        function [s] = get.tagString(self)
            s = '';
            for i = 1:length(self.tags)
                if i > 1
                    s = [s ',']; %#ok
                end
                s = [s self.tags{i}]; %#ok
            end
        end

        function [l] = get.length(self)
            l = size(self.data, 1);
        end

    end
end
