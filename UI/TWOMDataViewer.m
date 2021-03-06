classdef TWOMDataViewer < handle
    % TWOMDATAVIEWER Encapsulation of TWOM Data Viewer UI.

    properties

        % Extension of files to show.
        fileFilter = 'tdms';

    end

    % ------------------------------------------------------------------------

    properties (SetAccess=protected)

        % ----- Data Viewer State
        % Currently shown directory [char]
        directory = [];

        % Currently loaded file [TWOMDataFile]
        file = [];

        % File viewing state
        % NOTE: Copy any changes here to resetView(), as anything here is just
        % for documentation purposes.
        view = struct(...
              'distChannel',            [] ...   % 1 or 2
            , 'forceChannels',          [] ...   % {'c1', 't2', ...}
            , 'data',                   [] ...   % [FdDataCollection]
            , 'fdSubset',               [] ...   % [minT maxT] for plotfd
            , 'zoom',                   [] ...   % [minT maxT] for x,t zoom
            );

    end

    % ------------------------------------------------------------------------

    properties (Access=protected)

        % Internal variable containing object handles.
        gui = struct();

    end

    % ------------------------------------------------------------------------

    properties (Dependent)

        guiHandle;

    end

    % ------------------------------------------------------------------------

    methods

        function [self] = TWOMDataViewer(initialDir)
            self.createGui();
            if nargin > 0
                self.browseTo(initialDir);
            else
                self.browseTo(pwd());
            end
            self.fileChanged();
        end

        function browseTo(self, newDir)
            if exist(newDir, 'dir') == 7
                self.directory = newDir;
            else
                errordlg(['Directory "' newDir '" not found']);
            end
            self.directoryChanged();
        end

        function browseUp(self)
            [pathStr, ~, ~] = fileparts(self.directory);
            if ~isempty(pathStr)
                self.browseTo(pathStr);
            end
        end

        function copyToFigure(self, whatToCopy, destination)
            if isempty(self.file) || isempty(self.view.data) || self.view.data.isempty
                warning('No data available to copy.');
                return
            end

            switch whatToCopy
                case {'fd','ft','dt'}
                    % ok
                otherwise
                    error('Invalid argument "whatToCopy".');
            end
            if ischar(destination) && strcmpi(destination, 'new')
                destination = TDVFigureWindow.create();
            else
                if ~TDVFigureWindow.isValidFigureWindow(destination)
                    error('Invalid destination.');
                end
            end

            if isempty(self.view.fdSubset)
                TDVFigureWindow.addData(destination, self.view.data);
            else
                fdc = FdDataCollection();
                for i = 1:self.view.data.length
                    fdc.add(self.view.data.items{i}.subset('t', self.view.fdSubset*1000));
                end
                TDVFigureWindow.addData(destination, fdc);
            end
        end

        function exportDataToWorkspace(self)
            if isempty(self.file) || isempty(self.view.data)
                return
            end

            name = inputdlg('Please enter a name for the workspace variable:');
            if ~isempty(name) && ischar(name{1}) && ~isempty(name{1})
                name = name{1};
                if isvarname(name)
                    fd = self.view.data;
                    if fd.length == 1
                        fd = fd.items{1};
                    end
                    assignin('base', name, fd);
                    fprintf('The variable "%s" now contains the exported data:\n', name);
                    disp(fd);
                else
                    errordlg(sprintf('The name "%s" is not a valid variable name.', name));
                end
            else
                disp('Export canceled.');
            end
        end

        function exportHiResFtDataToWorkspace(self)
            if isempty(self.file) || isempty(self.view.data) ...
                    || ~self.file.HasHiResFtData
                return
            end

            channels = n_getChannels();
            if isempty(channels)
                errordlg(['No data to export. Please select at least one X/Y force channel first. ' ...
                          'Note that Force Trap Sum channels are not available.']);
                return
            end

            name = inputdlg('Please enter a name for the workspace variable:');
            if ~isempty(name) && ischar(name{1}) && ~isempty(name{1})
                name = name{1};
                if isvarname(name)
                    fd = self.file.getHiResFtData(channels, self.view.fdSubset*1000);
                    assignin('base', name, fd);
                    fprintf('The variable "%s" now contains the exported data:\n', name);
                    disp(fd);
                else
                    errordlg(sprintf('The name "%s" is not a valid variable name.', name));
                end
            else
                disp('Export canceled.');
            end

            % >> nested functions
            function [c] = n_getChannels()
                c = {};
                for m = 1:length(self.view.forceChannels)
                    if self.view.forceChannels{m}(1) == 'c'
                        c{end+1} = self.view.forceChannels{m};
                    end
                end
            end
            % << nested functions
        end

        function loadFile(self, file)
            self.file = [];

            if exist(file, 'file') ~= 2
                errordlg(['File "' file '" not found']);
            else
                try
                    self.file = TWOMDataFile(file);
                catch err
                    errordlg(err.message);
                end
            end

            self.fileChanged();
        end

        function plotHiResFtData(self)
            if isempty(self.file) || isempty(self.view.data) ...
                    || ~self.file.HasHiResFtData
                return
            end

            channels = n_getChannels();
            if isempty(channels)
                errordlg(['No data to plot. Please select at least one X/Y force channel first. ' ...
                          'Note that Force Trap Sum channels are not available.']);
                return
            end

            fdc = self.file.getHiResFtData(channels, self.view.fdSubset*1000);
            figure;
            for i = 1:fdc.length
                plot(fdc.items{i}.t/1000, fdc.items{i}.f, '.', ...
                     'DisplayName', fdc.items{i}.name);
                hold('on');
            end
            xlabel('Time (s)');
            ylabel('Force (pN)');

            % >> nested functions
            function [c] = n_getChannels()
                c = {};
                for m = 1:length(self.view.forceChannels)
                    if self.view.forceChannels{m}(1) == 'c'
                        c{end+1} = self.view.forceChannels{m};
                    end
                end
            end
            % << nested functions
        end


    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        function applyView(self)
            % APPLYVIEW Apply changes to the "view" struct data to the actual UI.
            if n_hasDataSelectionChanged()
                for ax = self.gui.allaxes
                    delete(findobj(ax, 'Type', 'line', '-and', '-not', 'Tag', 'cursor'));
                    set(ax, 'ColorOrderIndex', 1);
                end

                for i = 1:self.view.data.length
                    plotUserData = { self.view.distChannel self.view.forceChannels{i} };
                    plot(self.gui.plotfd.axes, [NaN NaN], [NaN NaN], '.');
                    plot(self.gui.plotft.axes, self.view.data.items{i}.t/1000, self.view.data.items{i}.f, ...
                                 '.', 'UserData', plotUserData);
                    plot(self.gui.plotdt.axes, self.view.data.items{i}.t/1000, self.view.data.items{i}.d, ...
                                 '.', 'UserData', plotUserData);
                end
            end

            % Update F,d graph
            fdplots = findobj(self.gui.plotfd.axes, 'Type', 'line');
            fdplots = fdplots(end:-1:1);  % otherwise plot colors flip on channel selection change
            for i = 1:self.view.data.length
                if isempty(self.view.fdSubset)
                    fd_subset = self.view.data.items{i};
                else
                    fd_subset = self.view.data.items{i}.subset('t', self.view.fdSubset*1000);
                end
                set(fdplots(i), 'XData', fd_subset.d, 'YData', fd_subset.f);
            end

            % Update cursors
            if isempty(self.view.fdSubset)
                % Initialize cursor positions
                if ~self.view.data.isempty
                    self.view.fdSubset = [min(self.view.data.items{1}.t/1000) ...
                                          max(self.view.data.items{1}.t/1000)];
                    self.gui.plotft.cur.Positions = self.view.fdSubset;
                    self.gui.plotdt.cur.Positions = self.view.fdSubset;
                end
            end
            if ~isempty(self.view.zoom)
                % Ensure cursor positions don't fall outside zoom.
                if self.view.fdSubset(1) < self.view.zoom(1) ...
                        || self.view.fdSubset(2) > self.view.zoom(2)
                    self.view.fdSubset = self.view.zoom;
                    self.gui.plotft.cur.Positions = self.view.fdSubset;
                    self.gui.plotdt.cur.Positions = self.view.fdSubset;
                end
            end

            % Update zoom
            for ax = [self.gui.plotft.axes, self.gui.plotdt.axes]
                if isempty(self.view.zoom)
                    axis(ax, 'tight');
                else
                    set(ax, 'XLim', self.view.zoom);
                end
            end

            % >> nested functions
            function [b] = n_hasDataSelectionChanged()
                currentD = 0;
                plots = findobj(self.gui.plotft.axes, 'Type', 'line', '-and', '-not', 'Tag', 'cursor');
                currentFItems = cell(size(plots));
                for k = 1:length(plots)
                    currentD         = plots(k).UserData{1};
                    currentFItems{k} = plots(k).UserData{2};
                end
                b = ~isequal(sort(currentFItems(:)), sort(self.view.forceChannels(:))) ...
                    || (currentD ~= self.view.distChannel);
            end
            % << nested functions
        end

        function createGui(self)
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
                , 'Label',          'Browse to Folder...' ...
                , 'Callback',       @(h,e) self.onBrowseBtnClick(h,e) ...
                );
            self.gui.menu.file_exit = uimenu(self.gui.menu.file ...
                , 'Separator',      'on' ...
                , 'Label',          'Exit' ...
                , 'Accelerator',    'w' ...
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
            % + Data
            self.gui.menu.data = uimenu(self.gui.window, 'Label', 'Data');
            self.gui.menu.data_exportToWorkspace = uimenu(self.gui.menu.data ...
                    , 'Label',      'Export to Workspace' ...
                    , 'Callback',   @(h,e) self.exportDataToWorkspace ...
                    );
            self.gui.menu.data_exportHiResToWorkspace = uimenu(self.gui.menu.data ...
                    , 'Label',      'Export High-Frequency F,t Data to Workspace' ...
                    , 'Callback',   @(h,e) self.exportHiResFtDataToWorkspace ...
                    );
            self.gui.menu.data_plotHiRes = uimenu(self.gui.menu.data ...
                    , 'Label',      'Plot High-Frequency F,t Data' ...
                    , 'Callback',   @(h,e) self.plotHiResFtData ...
                    );

            % ----- Context menus
            % x,t graph context menu
            self.gui.xtmenu.handle = uicontextmenu(self.gui.window);
            self.gui.xtmenu.zoomCursors = uimenu(self.gui.xtmenu.handle ...
                    , 'Label',      'Zoom to Cursors' ...
                    , 'Callback',   @(h,e) self.onZoomCursors ...
                    );
            self.gui.xtmenu.zoomOut = uimenu(self.gui.xtmenu.handle ...
                    , 'Label',      'Zoom Out' ...
                    , 'Callback',   @(h,e) self.onZoomOut ...
                    );

            % F,d graph context menu
            self.gui.fdmenu.handle = uicontextmenu(self.gui.window ...
                    , 'Callback',   @(h,e) self.onFdMenuCallback(h,e) );
            self.gui.fdmenu.copyToFigure = uimenu(self.gui.fdmenu.handle ...
                    , 'Label',      'Copy to Figure' ...
                    );
            self.gui.fdmenu.copyToFigure_New = uimenu(self.gui.fdmenu.copyToFigure ...
                    , 'Label',      'New Figure...' ...
                    , 'Callback',   @(h,e) self.copyToFigure('fd', 'new') ...
                    );

            % ----- Main grid
            self.gui.maingrid.root = uiextras.HBoxFlex('Parent', self.gui.window);
            self.gui.maingrid.root.Spacing = 3;
            self.gui.maingrid.leftpanel = uiextras.VBox('Parent', self.gui.maingrid.root);
            self.gui.maingrid.centerpanel = uiextras.VBoxFlex('Parent', self.gui.maingrid.root);
            self.gui.maingrid.centerpanel.Spacing = 3;
            self.gui.maingrid.rightpanel = uiextras.VBox('Parent', self.gui.maingrid.root);

            % ----- Left panel
            self.gui.dirpanel.panel = uiextras.HBox('Parent', self.gui.maingrid.leftpanel);
            self.gui.dirpanel.edit = uicontrol(...
                  'Parent',         self.gui.dirpanel.panel ...
                , 'Style',          'edit' ...
                , 'String',         '' ...
                , 'Callback',       @(h,e) self.onDirPanelEditChange(h,e) ...
                );
            self.gui.dirpanel.browseBtn = uicontrol(...
                  'Parent',         self.gui.dirpanel.panel ...
                , 'Style',          'pushbutton' ...
                , 'String',         'Browse...' ...
                , 'Callback',       @(h,e) self.onBrowseBtnClick(h,e) ...
                );
            self.gui.dirpanel.panel.Sizes = [-1 70];

            self.gui.dirlisting = uicontrol(...
                  'Parent',         self.gui.maingrid.leftpanel ...
                , 'Style',          'listbox' ...
                , 'Min',            0 ...
                , 'Max',            0 ...       % no multi-select
                , 'Callback',       @(h,e) self.onDirListingChange(h,e) ...
                , 'KeyPressFcn',    @(h,e) self.onDirListingKeyPress(h,e) ...
                );

            self.gui.maingrid.leftpanel.Sizes = [20 -1];

            % ----- Center panel: plots
            % Create plot axes
            self.gui.allaxes = [];
            for axesName = {'plotfd', 'plotft', 'plotdt'}
                self.gui.(axesName{1}).axes = axes(...
                      'Parent', uiextras.Panel('Parent', self.gui.maingrid.centerpanel) ...
                    , 'ActivePositionProperty', 'OuterPosition' ...
                    );
                self.gui.allaxes(end+1) = self.gui.(axesName{1}).axes;
                % TODO Try to decrease amount of empty space in plots.
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

            linkaxes([self.gui.plotft.axes, self.gui.plotdt.axes], 'x');

            for ax = self.gui.allaxes
                hold(ax, 'on');
                axis(ax, 'tight');
                set(ax, 'FontSize', 12);
            end

            % Add cursors to F,t / d,t plots
            self.gui.plotft.cur = cursors(self.gui.plotft.axes, [1 0 0]);
            self.gui.plotdt.cur = cursors(self.gui.plotdt.axes, [1 0 0]);
            for cur = {self.gui.plotft.cur, self.gui.plotdt.cur}
                cur{1}.add(0);
                cur{1}.add(1);
                addlistener(cur{1}, 'onDrag',     @(h,e) self.onCursorDrag(h,e));
                addlistener(cur{1}, 'onReleased', @(h,e) self.onCursorReleased(h,e));
            end

            % Add context menus to plots
            self.gui.plotfd.axes.UIContextMenu = self.gui.fdmenu.handle;
            self.gui.plotft.axes.UIContextMenu = self.gui.xtmenu.handle;
            self.gui.plotdt.axes.UIContextMenu = self.gui.xtmenu.handle;

            % Add mouse click event handlers to x,t plots
            self.gui.plotft.axes.ButtonDownFcn = @(h,e) self.onXtAxesButtonDown(h,e);
            self.gui.plotdt.axes.ButtonDownFcn = @(h,e) self.onXtAxesButtonDown(h,e);

            self.gui.maingrid.centerpanel.Sizes = [-2 -1 -1];

            % ----- Right panel
            self.gui.distchan = uicontrol(...
                  'Parent',         self.gui.maingrid.rightpanel ...
                , 'Style',          'popupmenu' ...
                , 'String',         {'Distance 1', 'Distance 2'} ...
                , 'Callback',       @(h,e) self.onDistChanCallback(h,e) ...
                );
            self.gui.forcechan = uitable(...
                  'Parent',         self.gui.maingrid.rightpanel ...
                , 'RowName',        [] ...
                , 'ColumnName',     [] ...
                , 'ColumnWidth',    {25 175} ...
                , 'ColumnFormat',   {'logical' 'char'} ...
                , 'ColumnEditable', [true false] ...
                , 'Data',           {} ...
                , 'CellEditCallback',@(h,e) self.onForceChanCellEdit(h,e) ...
                );

            self.gui.marks = uicontrol(...
                  'Parent',         self.gui.maingrid.rightpanel ...
                , 'Style',          'listbox' ...
                , 'Min',            0 ...
                , 'Max',            2 ...       % multi-select
                , 'Callback',       @(h,e) self.onMarksCallback(h,e) ...
                );

            self.gui.metadata.table = uitable(...
                  'Parent',         self.gui.maingrid.rightpanel ...
                , 'RowName',        [] ...
                , 'ColumnName',     {'Name', 'Value'} ...
                , 'ColumnWidth',    {125 125} ...
                , 'ColumnFormat',   {'char', 'char'} ...
                , 'ColumnEditable', [] ...
                , 'CellSelectionCallback', @(h,e) self.onMetadataCellSelection(h,e) ...
                );
            self.gui.metadata.details = uicontrol(...
                  'Parent',         self.gui.maingrid.rightpanel ...
                , 'Style',          'edit' ...
                , 'Min',            0 ...
                , 'Max',            2 ... % multi-line
                , 'HorizontalAlignment', 'left' ...
                , 'Enable',         'inactive' ...
                );

            self.gui.maingrid.rightpanel.Sizes = [20 -1 -1 -2 80];

            self.gui.maingrid.root.Sizes         = [screenSize(3)/6 -1 screenSize(3)/6];
            self.gui.maingrid.root.MinimumWidths = [200 200 200];
        end % function createGui

        function directoryChanged(self)
            self.gui.dirpanel.edit.String = self.directory;
            n_updateDirListing();

            % >> nested functions
            function n_updateDirListing()
                list = self.gui.dirlisting;

                listing = dir(self.directory);

                % List subdirectories.
                files = {'..'};
                for i = 1:length(listing)
                    if listing(i).isdir ...
                            && ~fileattrib(fullfile(self.directory, listing(i).name), 'h') ...
                            && listing(i).name(1) ~= '.'
                        files{end+1} = listing(i).name;
                    end
                end

                % List files matching filter.
                for i = 1:length(listing)
                    [~, ~, fileExt] = fileparts(listing(i).name);
                    if ~listing(i).isdir ...
                            && (strcmpi(fileExt, ['.' self.fileFilter]) || isempty(self.fileFilter)) ...
                            && ~fileattrib(fullfile(self.directory, listing(i).name), 'h') ...
                            && listing(i).name(1) ~= '.'
                        files{end+1} = listing(i).name;
                    end
                end

                list.String = files;
                list.Value  = 1;
            end
            % << nested functions
        end

        function fileChanged(self)
            if isempty(self.file)
                self.gui.window.Name = 'TWOM Data Viewer';
                self.gui.forcechan.Data = {};
                self.gui.forcechan.UserData = {};
                self.gui.marks.String = {};
                self.gui.metadata.table.Data = {};

                hiResEnable = 'off';
            else
                [~, fileName, fileExt] = fileparts(self.file.Filename);
                self.gui.window.Name = sprintf('TWOM Data Viewer - [%s%s]', fileName, fileExt);

                % Load data marks
                [self.gui.marks.String, self.gui.marks.UserData] = n_getMarksData();
                self.gui.marks.Value = [];

                % Load force channel selection list
                self.gui.forcechan.Data = [n_getForceChanSelection() n_getForceChanCaptions()];
                self.gui.forcechan.UserData = n_getForceChanRefs();

                % Load metadata
                self.gui.metadata.table.Data = self.file.MetaData;

                % Enable/disable menu items
                if self.file.HasHiResFtData
                    hiResEnable = 'on';
                else
                    hiResEnable = 'off';
                end
            end

            % Enabled/disable menu items
            self.gui.menu.data_exportHiResToWorkspace.Enable = hiResEnable;
            self.gui.menu.data_plotHiRes.Enable = hiResEnable;

            self.resetView();
            self.uiToView_FDChannelSelection();
            self.applyView();

            % >> nested functions
            function [captions] = n_getForceChanCaptions()
                nTrapChan = floor(self.file.NForceChannels/2);
                cCaptions = {}; tCaptions = {};
                for k = 1:nTrapChan
                    cCaptions{end+1} = sprintf('Force Trap %d - X', k);
                    cCaptions{end+1} = sprintf('Force Trap %d - Y', k);
                    tCaptions{end+1} = sprintf('Force Trap %d - Sum', k);
                end
                captions = [cCaptions(:); tCaptions(:)];
            end
            function [chanRefs] = n_getForceChanRefs()
                nTrapChan = floor(self.file.NForceChannels/2);
                cRefs = {}; tRefs = {};
                for k = 1:nTrapChan
                    cRefs{end+1} = sprintf('c%dx', k);
                    cRefs{end+1} = sprintf('c%dy', k);
                    tRefs{end+1} = sprintf('t%d', k);
                end
                chanRefs = [cRefs(:); tRefs(:)];
            end
            function [sel] = n_getForceChanSelection()
                % Returns first column of Data for Force Channel selection
                % table: cell array of booleans indicating force channel
                % selection.
                nTrapChan = floor(self.file.NForceChannels/2);
                if size(self.gui.forcechan.Data,1) == 3*nTrapChan
                    sel = self.gui.forcechan.Data(:,1);  % preserve selection
                else
                    sel = num2cell(false(3*nTrapChan,1));
                end
                if all(~cell2mat(sel))
                    sel{1} = true;  % default selection: top item
                end
            end
            function [markStrings, markUserData] = n_getMarksData()
                marks = self.file.getMarks();
                markStrings  = cell(length(marks),1);
                markUserData = cell(length(marks),1);
                for i = 1:length(marks)
                    markStrings{i}  = sprintf('[%d] %s', marks(i).number, marks(i).comment);
                    markUserData{i} = marks(i).t/1000;
                end
            end
            % << nested functions
        end

        function resetView(self)
            % NOTE: Copy any changes here to the property definition, for
            % documentation.
            self.view = struct(...
                  'distChannel',            [] ...   % 1 or 2
                , 'forceChannels',          [] ...   % {'c1', 't2', ...}
                , 'data',                   FdDataCollection() ...
                , 'fdSubset',               [] ...   % [minT maxT] for plotfd
                , 'zoom',                   [] ...   % [minT maxT] for x,t zoom
                );
        end

        function uiToView_FDChannelSelection(self)
            if isempty(self.file)
                return
            end

            self.view.distChannel = self.gui.distchan.Value;

            self.view.forceChannels = {};
            for k = 1:size(self.gui.forcechan.Data,1)
                if self.gui.forcechan.Data{k,1}
                    self.view.forceChannels{end+1} = self.gui.forcechan.UserData{k};
                end
            end

            self.view.data = self.file.getFdData(self.view.forceChannels, ...
                                                 self.view.distChannel);
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        % ----- CALLBACK METHODS

        function onBrowseBtnClick(self, ~, ~)
            newDir = uigetdir(self.directory);
            if newDir ~= 0
                self.browseTo(newDir);
            end
        end

        function onCursorDrag(self, h, e)
            % Sync cursors in other graph with this one.
            if isempty(self.gui.plotft) || isempty(self.gui.plotdt)
                return
            end
            if h == self.gui.plotft.cur
                self.gui.plotdt.cur.Positions = e.Positions;
            else
                self.gui.plotft.cur.Positions = e.Positions;
            end
        end

        function onCursorReleased(self, ~, ~)
            if ~isempty(self.view.data)
                self.view.fdSubset = [min(self.gui.plotft.cur.Positions) ...
                                      max(self.gui.plotft.cur.Positions)];
                self.applyView();
            end
        end

        function onDirPanelEditChange(self, ~, ~)
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
                    elseif isdir(fullfile(self.directory, item))
                        self.browseTo(fullfile(self.directory, item));
                    else
                        % Ignore double-clicks on regular file.
                    end
                else
                    % Normal click
                    item = self.gui.dirlisting.String{self.gui.dirlisting.Value};
                    if strcmp(item, '..') || isdir(fullfile(self.directory, item))
                        % ignore
                    else
                        self.loadFile(fullfile(self.directory, item));
                    end
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
                    elseif isdir(fullfile(self.directory, item))
                        self.browseTo(fullfile(self.directory, item));
                    else
                        % Ignore Enter key press on regular file.
                    end
                elseif strcmp(e.Key, 'backspace')
                    self.browseUp();
                end
            end
        end

        function onDistChanCallback(self, ~, ~)
            if ~isempty(self.file)
                self.uiToView_FDChannelSelection();
                self.applyView();
            end
        end

        function onFdMenuCallback(self, ~, ~)
            % Refresh list of existing windows in "Copy to Figure" submenu.
            delete(findobj(self.gui.fdmenu.copyToFigure, 'Tag', 'existing'));

            hFigs = TDVFigureWindow.findAll();
            for i = 1:length(hFigs)
                hFig = hFigs(i);
                uimenu(self.gui.fdmenu.copyToFigure ...
                    , 'Label',      n_getFigCaption(hFig) ...
                    , 'Callback',   @(h,e) self.copyToFigure('fd', hFig) ...
                    , 'Tag',        'existing' ...
                    );
            end

            % >> nested functions
            function [caption] = n_getFigCaption(h)
                caption = get(h, 'Name');
                if isempty(caption)
                    if isempty(get(h, 'Number'))
                        caption = sprintf('Figure %d', h);
                    else
                        caption = sprintf('Figure %d', get(h, 'Number'));
                    end
                end
            end
            % << nested functions
        end

        function onFileExit(self, ~, ~)
            delete(self.gui.window);
        end

        function onForceChanCellEdit(self, ~, ~)
            if ~isempty(self.file)
                self.uiToView_FDChannelSelection();
                self.applyView();
            end
        end

        function onMarksCallback(self, ~, ~)
            if ~isempty(self.file) && ~isempty(self.gui.marks.Value)
                if isscalar(self.gui.marks.Value)
                    newPos = [self.gui.marks.UserData{self.gui.marks.Value} ...
                              max(self.gui.plotft.cur.Positions)];
                else
                    newPos = [self.gui.marks.UserData{self.gui.marks.Value(1)} ...
                              self.gui.marks.UserData{self.gui.marks.Value(2)} ];
                end
                if newPos(1) == newPos(2)
                    newPos(2) = max(self.view.data.items{1}.t/1000);
                end
                self.gui.plotft.cur.Positions = newPos;
                self.gui.plotdt.cur.Positions = newPos;
                self.onCursorReleased();
            end
        end

        function onMetadataCellSelection(self, ~, e)
            if isequal(size(e.Indices), [1 2])
                self.gui.metadata.details.String = ...
                    self.gui.metadata.table.Data{e.Indices(1), e.Indices(2)};
            else
                self.gui.metadata.details.String = '';
            end
        end

        function onXtAxesButtonDown(self, h, e)
            if ~isempty(self.file) && strcmp(self.gui.window.SelectionType, 'open') ...
                    && ~isempty(self.view.zoom)
                dx = self.gui.plotft.axes.XLim;
                dz = (self.view.zoom(2)-self.view.zoom(1)) * 2/3;
                if e.IntersectionPoint(1) < (dx(2)-dx(1))/3+dx(1)
                    % Double-clicked on left 1/3 of axes: pan left
                    self.view.zoom = self.view.zoom - dz;
                    self.applyView();
                elseif e.IntersectionPoint(1) > (dx(2)-dx(1))*2/3+dx(1)
                    % Double-clicked on right 1/3 of axes: pan right
                    self.view.zoom = self.view.zoom + dz;
                    self.applyView();
                end
            end
        end

        function onZoomCursors(self)
            if ~isempty(self.file)
                self.view.zoom = [min(self.gui.plotft.cur.Positions) ...
                                  max(self.gui.plotft.cur.Positions)];
                self.applyView();
            end
        end

        function onZoomOut(self)
            if ~isempty(self.file)
                self.view.zoom = [];
                self.applyView();
            end
        end

    end

    % ------------------------------------------------------------------------

    methods % Getters/Setters

        function [val] = get.guiHandle(self)
            val = self.gui.window;
        end

    end

end
