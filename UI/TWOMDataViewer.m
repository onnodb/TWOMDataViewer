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
            for ax = self.gui.allaxes
                cla(ax);
            end

            % Layout plots
            xlabel(self.gui.plotfd.axes, 'Distance (um)');
            ylabel(self.gui.plotfd.axes, 'Force (pN)');

            self.gui.plotft.axes.XTickLabel = {};
            self.gui.plotft.axes.XGrid = 'on';
            ylabel(self.gui.plotft.axes, 'Force (pN)');

            self.gui.plotdt.axes.XGrid = 'on';
            xlabel(self.gui.plotdt.axes, 'Time (s)');
            ylabel(self.gui.plotdt.axes, 'Distance (um)');

            for ax = self.gui.allaxes
                hold(ax, 'on');
                axis(ax, 'tight');
                set(ax, 'FontSize', 12);
            end

            % Add cursors to F,t / d,t plots
            self.gui.plotft.cur = cursors(self.gui.plotft.axes, [1 0 0]);
            self.gui.plotdt.cur = cursors(self.gui.plotdt.axes, [1 0 0]);

            % Add context menu to F,t / d,t plots
            self.gui.plotft.axes.UIContextMenu = self.gui.main.xtmenu.handle;
            self.gui.plotdt.axes.UIContextMenu = self.gui.main.xtmenu.handle;
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
            if all(~cell2mat(forceChanSelections))
                forceChanSelections{1} = true;
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
            [forceChans, distChan] = n_getSelectedData();
            if isempty(forceChans)
                self.clearPlots();
            else
                self.data = self.tdf.getFdData(forceChans, distChan);
                self.updatePlots();
            end

            % >> nested functions
            function [fc, dc] = n_getSelectedData()
                dc = self.gui.distchan.Value;
                fc = {};
                for k = 1:size(self.gui.forcechan.Data,1)
                    if self.gui.forcechan.Data{k,1}
                        fc{end+1} = self.gui.forcechan.UserData{k};
                    end
                end
            end
            % << nested functions
        end

        function updateFdPlot(self)
            minT = min(self.gui.plotft.cur.Positions);
            maxT = max(self.gui.plotft.cur.Positions);
            for i = 1:self.data.length
                fd_subset = self.data.items{i}.subset('t', [minT maxT]);
                set(self.gui.plotfd.plots(i), ...
                    'XData', fd_subset.d, 'YData', fd_subset.f);
            end
        end

        function updatePlots(self)
            if isempty(self.data)
                return
            end

            % TODO Optimize this: maybe only delete plots / update plot data,
            % instead of clearing axes every time, and thus every time
            % recreating things like cursors?
            self.clearPlots();

            % Plot data
            self.gui.plotfd.plots = [];
            for i = 1:self.data.length
                self.gui.plotfd.plots(end+1) = ...
                    plot(self.gui.plotfd.axes, [NaN NaN], [NaN NaN], '.');
                plot(self.gui.plotft.axes, self.data.items{i}.t, self.data.items{i}.f, '.');
                plot(self.gui.plotdt.axes, self.data.items{i}.t, self.data.items{i}.d, '.');
            end

            % Update cursors
            for cur = {self.gui.plotft.cur, self.gui.plotdt.cur}
                cur{1}.add(min(self.data.items{i}.t));
                cur{1}.add(max(self.data.items{i}.t));
                addlistener(cur{1}, 'onDrag',     @(h,e) self.onCursorDrag(h,e));
                addlistener(cur{1}, 'onReleased', @(h,e) self.onCursorRelease(h,e));
            end

            self.updateFdPlot();
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
            self.gui.menu.file_browse = uimenu(self.gui.menu.file ...
                , 'Label',          'Browse...' ...
                , 'Callback',       @(h,e) self.onBrowseBtnClick(h,e) ...
                );
            self.gui.menu.file_exit = uimenu(self.gui.menu.file ...
                , 'Separator',      'on' ...
                , 'Label',          'Exit' ...
                , 'Callback',       @(h,e) self.onFileExit(h,e) ...
              );
            % + View
            self.gui.menu.view = uimenu(self.gui.window, 'Label', 'View');
            self.gui.menu.view_zoomCursors = uimenu(self.gui.menu.view ...
                    , 'Label',      'Zoom to Cursors' ...
                    , 'Callback',   @(h,e) self.onZoomCursors ...
                    );
            self.gui.menu.view_zoomOut = uimenu(self.gui.menu.view ...
                    , 'Label',      'Zoom Out' ...
                    , 'Callback',   @(h,e) self.onZoomOut ...
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

            % Create plot axes
            self.gui.allaxes = [];
            for axesName = {'plotfd', 'plotft', 'plotdt'}
                self.gui.(axesName{1}).panel = uiextras.Panel('Parent', self.gui.main.panel);
                self.gui.(axesName{1}).axes = axes(...
                      'Parent',         self.gui.(axesName{1}).panel ...
                    , 'ActivePositionProperty', 'OuterPosition' ...
                    );
                self.gui.allaxes(end+1) = self.gui.(axesName{1}).axes;
                % TODO Try to decrease amount of empty space in plots.
            end

            linkaxes([self.gui.plotft.axes, self.gui.plotdt.axes], 'x');

            % Set up context menus
            self.gui.main.xtmenu.handle = uicontextmenu(self.gui.window);
            self.gui.main.xtmenu.zoom = uimenu(self.gui.main.xtmenu.handle ...
                    , 'Label',      'Zoom to Cursors' ...
                    , 'Callback',   @(h,e) self.onZoomCursors ...
                    );

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

        function onCursorDrag(self, h, e)
            % Sync cursors in other graph with this one.
            if h == self.gui.plotft.cur
                self.gui.plotdt.cur.Positions = e.Positions;
            else
                self.gui.plotft.cur.Positions = e.Positions;
            end
        end

        function onCursorRelease(self, h, e)
            self.updateFdPlot();
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

        function onZoomCursors(self)
            minT = min(self.gui.plotft.cur.Positions);
            maxT = max(self.gui.plotft.cur.Positions);

            for ax = [self.gui.plotft.axes, self.gui.plotdt.axes]
                set(ax, 'XLim', [minT maxT]);
            end
        end

        function onZoomOut(self)
            axis(self.gui.plotft.axes, 'tight');
            axis(self.gui.plotdt.axes, 'tight');
        end

    end

end
