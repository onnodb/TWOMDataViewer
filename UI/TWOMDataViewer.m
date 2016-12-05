classdef TWOMDataViewer < handle
    % TWOMDATAVIEWER Encapsulation of TWOM Data Viewer UI.

    properties

        % Extension of files to show.
        fileFilter = 'tdms';

    end

    % ------------------------------------------------------------------------

    properties (SetAccess=protected)

        % Currently shown directory [char]
        currentDir;

        % Currently loaded file [TWOMDataFile]
        currentFile;

        % Currently shown data [FdDataCollection]
        data;

    end

    % ------------------------------------------------------------------------

    properties (Access=protected)

        % Internal variable containing object handles.
        gui;

        % TWOMDataFile object for current file.
        tdf;

    end

    % ------------------------------------------------------------------------

    methods

        function [self] = TWOMDataViewer(startDir)
            self.createGui();
            if nargin > 0
                self.browseTo(startDir);
            else
                self.browseTo(pwd());
            end
        end

        function browseTo(self, newDir)
            self.clearPlots();
            if exist(newDir, 'dir') == 7
                self.currentDir = newDir;
                self.gui.dirpanel.edit.String = newDir;
                self.refreshDirectory();
            else
                errordlg(['Directory ' newDir ' not found']);
                self.gui.dirpanel.edit.String = self.currentDir;
            end
        end

        function browseUp(self)
            [pathStr, ~, ~] = fileparts(self.currentDir);
            if ~isempty(pathStr)
                self.browseTo(pathStr);
            end
        end

        function clearPlots(self)
            cla(self.gui.plotfd.axes);
            cla(self.gui.plotft.axes);
            cla(self.gui.plotdt.axes);

            % Layout plots
            xlabel(self.gui.plotfd.axes, 'Distance (um)');
            ylabel(self.gui.plotfd.axes, 'Force (pN)');

            self.gui.plotft.axes.XTickLabel = {};
            self.gui.plotft.axes.XGrid = 'on';
            ylabel(self.gui.plotft.axes, 'Force (pN)');

            self.gui.plotdt.axes.XGrid = 'on';
            xlabel(self.gui.plotdt.axes, 'Time (s)');
            ylabel(self.gui.plotdt.axes, 'Distance (um)');
        end

        function loadFile(self, file)
            if exist(file, 'file') ~= 2
                self.clearPlots();
                return
            end

            try
                self.tdf = TWOMDataFile(file);
            catch err
                self.clearPlots();
                errordlg(err.message);
                return
            end

            self.currentFile = file;
            self.gui.window.Name = sprintf('TWOM Data Viewer - [%s]', file);

            % Load metadata
            self.gui.metadata.table.Data = self.tdf.MetaData;

            % Load force channels
            [forceChanCaptions, forceChanRefs] = n_getForceChanListData();
            if size(self.gui.forcechan.Data,1) == length(forceChanCaptions)
                forceChanSelections = self.gui.forcechan.Data(:,1);  % keep selection
            else
                forceChanSelections = num2cell(false(length(forceChanCaptions),1));
            end
            self.gui.forcechan.Data = [forceChanSelections forceChanCaptions'];
            self.gui.forcechan.UserData = forceChanRefs';

            % Load plots
            self.updateData();

            % >> nested functions
            function [captions, forceChans] = n_getForceChanListData()
                nTrapChan  = floor(self.tdf.NForceChannels/2);

                captions   = {};
                forceChans = {};

                for k = 1:nTrapChan
                    captions{end+1} = sprintf('Force Trap %d - X', k);
                    captions{end+1} = sprintf('Force Trap %d - Y', k);
                    forceChans{end+1} = sprintf('c%dx', k);
                    forceChans{end+1} = sprintf('c%dy', k);
                end
                for k = 1:nTrapChan
                    captions{end+1} = sprintf('Force Trap %d - Sum', k);
                    forceChans{end+1} = sprintf('t%d', k);
                end
            end
            % << nested functions
        end

        function updateData(self)
            dataItems = n_getSelectedData();
            if isempty(dataItems)
                self.clearPlots();
            else
                self.data = FdDataCollection();
                for i = 1:length(dataItems)
                    self.data.add(self.tdf.getFdData(dataItems{i}{:}));
                end
                self.updatePlots();
            end

            % >> nested functions
            function [p] = n_getSelectedData()
                distChan = self.gui.distchan.Value;
                p = {};
                for k = 1:size(self.gui.forcechan.Data,1)
                    if self.gui.forcechan.Data{k,1}
                        p{end+1} = {self.gui.forcechan.UserData{k}, distChan};
                    end
                end
            end
            % << nested functions
        end

        function updatePlots(self)
            if isempty(self.data)
                return
            end

            self.clearPlots();

            for i = 1:self.data.length
                plot(self.gui.plotfd.axes, self.data.items{i}.d, self.data.items{i}.f, '.');
                hold(self.gui.plotfd.axes, 'on');
                plot(self.gui.plotft.axes, self.data.items{i}.t, self.data.items{i}.f, '.');
                hold(self.gui.plotft.axes, 'on');
                plot(self.gui.plotdt.axes, self.data.items{i}.t, self.data.items{i}.d, '.');
                hold(self.gui.plotdt.axes, 'on');
            end
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        function createGui(self)
            self.gui = struct();

            % ----- Window
            screenSize = get(0, 'ScreenSize');
            self.gui.window = figure(...
                'Name',             'TWOM Data Viewer' ...
              , 'NumberTitle',      'off' ...
              , 'MenuBar',          'none' ...
              , 'Toolbar',          'none' ...
              , 'HandleVisibility', 'off' ...
              , 'Position',         [screenSize(3)/8 screenSize(4)/8 screenSize(3)/1.3 screenSize(4)/1.3] ...
              );

            % ----- Menu
            % + File
            self.gui.menu.file = uimenu(self.gui.window, 'Label', 'File');
            self.gui.menu.file_browse = uimenu(self.gui.menu.file, ...
                  'Label',          'Browse...' ...
                , 'Callback',       @(h,e) self.onBrowseBtnClick(h,e) ...
                );
            self.gui.menu.file_exit = uimenu(self.gui.menu.file, ...
                  'Separator',      'on' ...
                , 'Label',          'Exit' ...
                , 'Callback',       @(h,e) self.onFileExit(h,e) ...
              );

            % ----- Main columns
            self.gui.root = uiextras.HBoxFlex('Parent', self.gui.window);
            self.gui.root.Spacing = 3;

            % ----- Left panel
            self.gui.left.panel = uiextras.VBox('Parent', self.gui.root);

            self.gui.dirpanel.panel = uiextras.HBox('Parent', self.gui.left.panel);
            self.gui.dirpanel.edit = uicontrol(...
                  'Parent',         self.gui.dirpanel.panel ...
                , 'Style',          'edit' ...
                , 'String',         '' ...
                , 'Callback',       @(h,e) self.onDirChange(h,e) ...
                );
            self.gui.dirpanel.browseBtn = uicontrol(...
                  'Parent',         self.gui.dirpanel.panel ...
                , 'Style',          'pushbutton' ...
                , 'String',         'Browse...' ...
                , 'Callback',       @(h,e) self.onBrowseBtnClick(h,e) ...
                );
            self.gui.dirpanel.panel.Sizes = [-1 70];

            self.gui.dirlisting = uicontrol(...
                  'Parent',         self.gui.left.panel ...
                , 'Style',          'listbox' ...
                , 'Min',            0 ...
                , 'Max',            0 ...       % no multi-select
                , 'Callback',       @(h,e) self.onDirListingChange(h,e) ...
                , 'KeyPressFcn',    @(h,e) self.onDirListingKeyPress(h,e) ...
                );

            self.gui.left.panel.Sizes = [20 -1];

            % ----- Center, main panel
            self.gui.main.panel = uiextras.VBoxFlex('Parent', self.gui.root);

            for axesName = {'plotfd', 'plotft', 'plotdt'}
                self.gui.(axesName{1}).panel = uiextras.Panel('Parent', self.gui.main.panel);
                self.gui.(axesName{1}).axes = axes(...
                      'Parent',         self.gui.(axesName{1}).panel ...
                    , 'ActivePositionProperty', 'OuterPosition' ...
                    , 'FontSize',       12 ...
                    );
                % TODO Try to decrease amount of empty space in plots.
            end

            linkaxes([self.gui.plotft.axes, self.gui.plotdt.axes], 'x');
            self.clearPlots();

            self.gui.main.panel.Sizes = [-2 -1 -1];
            self.gui.main.panel.Spacing = 3;

            % ----- Right panel
            self.gui.right.panel = uiextras.VBox('Parent', self.gui.root);

            self.gui.distchan = uicontrol(...
                  'Parent',         self.gui.right.panel ...
                , 'Style',          'popupmenu' ...
                , 'String',         {'Distance 1', 'Distance 2'} ...
                , 'Callback',       @(h,e) self.onDistChanCallback(h,e) ...
                );
            self.gui.forcechan = uitable(...
                  'Parent',         self.gui.right.panel ...
                , 'RowName',        [] ...
                , 'ColumnName',     [] ...
                , 'ColumnWidth',    {25 175} ...
                , 'ColumnFormat',   {'logical' 'char'} ...
                , 'ColumnEditable', [true false] ...
                , 'Data',           {} ...
                , 'CellEditCallback',@(h,e) self.onForceChanCellEdit(h,e) ...
                );

            self.gui.metadata.table = uitable(...
                  'Parent',         self.gui.right.panel ...
                , 'RowName',        [] ...
                , 'ColumnName',     {'Name', 'Value'} ...
                , 'ColumnWidth',    {125 125} ...
                , 'ColumnFormat',   {'char', 'char'} ...
                , 'ColumnEditable', [] ...
                , 'CellSelectionCallback', @(h,e) self.onMetadataCellSelection(h,e) ...
                );
            self.gui.metadata.details = uicontrol(...
                  'Parent',         self.gui.right.panel ...
                , 'Style',          'edit' ...
                , 'Min',            0 ...
                , 'Max',            2 ... % multi-line
                , 'HorizontalAlignment', 'left' ...
                , 'Enable',         'inactive' ...
                );

            self.gui.right.panel.Sizes = [20 -1 -2 80];

            self.gui.root.Sizes         = [screenSize(3)/6 -1 screenSize(3)/6];
            self.gui.root.MinimumWidths = [200 200 200];
        end

        function refreshDirectory(self)
            list = self.gui.dirlisting;

            listing = dir(self.currentDir);

            % List subdirectories.
            files = {'..'};
            for i = 1:length(listing)
                if listing(i).isdir ...
                        && ~fileattrib(fullfile(self.currentDir, listing(i).name), 'h') ...
                        && listing(i).name(1) ~= '.'
                    files{end+1} = listing(i).name;
                end
            end

            % List files matching filter.
            for i = 1:length(listing)
                [~, ~, fileExt] = fileparts(listing(i).name);
                if ~listing(i).isdir ...
                        && (strcmpi(fileExt, ['.' self.fileFilter]) || isempty(self.fileFilter)) ...
                        && ~fileattrib(fullfile(self.currentDir, listing(i).name), 'h') ...
                        && listing(i).name(1) ~= '.'
                    files{end+1} = listing(i).name;
                end
            end

            list.String = files;
            list.Value  = 1;
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        % ----- CALLBACK METHODS

        function onBrowseBtnClick(self, ~, ~)
            newDir = uigetdir(self.currentDir);
            if newDir ~= 0
                self.browseTo(newDir);
            end
        end

        function onDirChange(self, ~, ~)
            self.browseTo(self.gui.dirpanel.edit.String);
        end

        function onDirListingChange(self, ~, ~)
            if ~isempty(self.gui.dirlisting.Value) ...
                    && isscalar(self.gui.dirlisting.Value)
                if strcmp(self.gui.window.SelectionType, 'open')
                    % Double-click
                    item = self.gui.dirlisting.String{self.gui.dirlisting.Value};
                    if strcmp(item, '..')
                        self.browseUp();
                    elseif isdir(fullfile(self.currentDir, item))
                        self.browseTo(fullfile(self.currentDir, item));
                    else
                        % Ignore double-clicks on regular file.
                    end
                else
                    % Normal click
                    item = self.gui.dirlisting.String{self.gui.dirlisting.Value};
                    self.loadFile(fullfile(self.currentDir, item));
                end
            else
                self.gui.dirlisting.Value = 1;
                    % Work around MATLAB bug where user can accidentally
                    % unselect all items, which is an invalid state for a
                    % non-multi-select listbox.
            end
        end

        function onDirListingKeyPress(self, ~, e)
            if ~isempty(self.gui.dirlisting.Value) ...
                    && isscalar(self.gui.dirlisting.Value)
                if strcmp(e.Key, 'enter')
                    % Pressed Enter
                    item = self.gui.dirlisting.String{self.gui.dirlisting.Value};
                    if strcmp(item, '..')
                        self.browseUp();
                    elseif isdir(fullfile(self.currentDir, item))
                        self.browseTo(fullfile(self.currentDir, item));
                    else
                        % Ignore Enter key press on regular file.
                    end
                elseif strcmp(e.Key, 'backspace')
                    self.browseUp();
                end
            end
        end

        function onDistChanCallback(self, ~, ~)
            self.updateData();
        end

        function onFileExit(self, ~, ~)
            delete(self.gui.window);
        end

        function onForceChanCellEdit(self, ~, ~)
            self.updateData();
        end

        function onMetadataCellSelection(self, ~, e)
            if isequal(size(e.Indices), [1 2])
                self.gui.metadata.details.String = ...
                    self.gui.metadata.table.Data{e.Indices(1), e.Indices(2)};
            else
                self.gui.metadata.details.String = '';
            end
        end

    end

end
