classdef TWOMDataViewer < handle
    % TWOMDATAVIEWER Encapsulation of TWOM Data Viewer UI.

    properties

        % Currently shown directory.
        currentDir;

        % Extension of files to show.
        fileFilter = 'tdms';

    end

    % ------------------------------------------------------------------------

    properties (Access=protected)

        % Internal variable containing object handles.
        gui;

    end

    % ------------------------------------------------------------------------

    methods

        function [self] = TWOMDataViewer(startDir)
            % Set up GUI.
            self.createGui();
            if nargin > 0
                self.browseTo(startDir);
            else
                self.browseTo(pwd());
            end
        end

        function browseTo(self, newDir)
            if exist(newDir, 'dir') == 7
                self.currentDir = newDir;
                self.gui.dirpanel.edit.String = newDir;
                self.refreshDirectory();
            else
                errordlg(['Directory ' newDir ' not found']);
                self.gui.dirpanel.edit.String = self.currentDir;
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
                , 'Callback',       @(h,e) self.onBrowseBtnClick(h, e) ...
                );
            self.gui.menu.file_exit = uimenu(self.gui.menu.file, ...
                  'Separator',      'on' ...
                , 'Label',          'Exit' ...
                , 'Callback',       @(h,e) self.onFileExit(h, e) ...
              );

            % ----- Main columns
            self.gui.root = uiextras.HBoxFlex('Parent', self.gui.window);
            self.gui.root.Spacing = 5;

            % ----- Left panel
            self.gui.left.panel = uiextras.VBox('Parent', self.gui.root);

            self.gui.dirpanel.panel = uiextras.HBox('Parent', self.gui.left.panel);
            self.gui.dirpanel.edit = uicontrol(...
                  'Parent',         self.gui.dirpanel.panel ...
                , 'Style',          'edit' ...
                , 'String',         '' ...
                , 'Callback',       @(h,e) self.onDirChange ...
                );
            self.gui.dirpanel.browseBtn = uicontrol(...
                  'Parent',         self.gui.dirpanel.panel ...
                , 'Style',          'pushbutton' ...
                , 'String',         'Browse...' ...
                , 'Callback',       @(h,e) self.onBrowseBtnClick ...
                );
            self.gui.dirpanel.panel.Sizes = [-1 70];

            self.gui.dirlisting = uicontrol(...
                  'Parent',         self.gui.left.panel ...
                , 'Style',          'listbox' ...
                , 'Callback',       @(h,e) self.onDirListingChange ...
                );

            self.gui.left.panel.Sizes = [20 -1];

            % ----- Center, main panel
            self.gui.main.panel = uiextras.VBox('Parent', self.gui.root);

            self.gui.root.Sizes         = [screenSize(3)/6 -1];
            self.gui.root.MinimumWidths = [200 200];

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
            % TODO
        end

        function onFileExit(self, ~, ~)
            delete(self.gui.window);
        end

    end

end
