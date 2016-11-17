classdef TWOMDataViewer < handle
    % TWOMDATAVIEWER Encapsulation of TWOM Data Viewer UI.

    properties

        % Currently shown directory.
        currentDir;

    end

    % ------------------------------------------------------------------------

    properties (Access=protected)

        % Internal variable containing object handles.
        gui;

    end

    % ------------------------------------------------------------------------

    methods

        function [this] = TWOMDataViewer(c)
            % Set up GUI.
            this.createGui();
            this.browseTo(pwd());
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        function createGui(this)
            this.gui = struct();

            % ----- Window
            screenSize = get(0, 'ScreenSize');
            this.gui.window = figure(...
                'Name',             'TWOM Data Viewer' ...
              , 'NumberTitle',      'off' ...
              , 'MenuBar',          'none' ...
              , 'Toolbar',          'none' ...
              , 'HandleVisibility', 'off' ...
              , 'Position',         [screenSize(3)/8 screenSize(4)/8 screenSize(3)/1.3 screenSize(4)/1.3] ...
              );

            % ----- Menu
            % + File
            this.gui.menu.file = uimenu(this.gui.window, 'Label', 'File');
            this.gui.menu.file_browse = uimenu(this.gui.menu.file, ...
                  'Label',          'Browse...' ...
                , 'Callback',       @(h,e) this.onBrowseBtnClick(h, e) ...
                );
            this.gui.menu.file_exit = uimenu(this.gui.menu.file, ...
                  'Separator',      'on' ...
                , 'Label',          'Exit' ...
                , 'Callback',       @(h,e) this.onFileExit(h, e) ...
              );

            % ----- Main columns
            this.gui.root = uiextras.HBoxFlex('Parent', this.gui.window);
            this.gui.root.Spacing = 5;

            % ----- Left panel
            this.gui.left.panel = uiextras.VBox('Parent', this.gui.root);

            this.gui.dirpanel.panel = uiextras.HBox('Parent', this.gui.left.panel);
            this.gui.dirpanel.edit = uicontrol(...
                  'Parent',         this.gui.dirpanel.panel ...
                , 'Style',          'edit' ...
                , 'String',         '' ...
                , 'Callback',       @(h,e) this.onDirChange ...
                );
            this.gui.dirpanel.browseBtn = uicontrol(...
                  'Parent',         this.gui.dirpanel.panel ...
                , 'Style',          'pushbutton' ...
                , 'String',         'Browse...' ...
                , 'Callback',       @(h,e) this.onBrowseBtnClick ...
                );
            this.gui.dirpanel.panel.Sizes = [-1 70];

            this.gui.dirlisting = uicontrol(...
                  'Parent',         this.gui.left.panel ...
                , 'Style',          'listbox' ...
                , 'Callback',       @(h,e) this.onDirListingChange ...
                );

            this.gui.left.panel.Sizes = [20 -1];

            % ----- Center, main panel
            this.gui.main.panel = uiextras.VBox('Parent', this.gui.root);

            this.gui.root.Sizes         = [screenSize(3)/6 -1];
            this.gui.root.MinimumWidths = [200 200];

        end

        function browseTo(this, newDir)
            if exist(newDir, 'dir') == 7
                this.currentDir = newDir;
                this.gui.dirpanel.edit.String = newDir;
                this.refreshDirectory();
            else
                errordlg(['Directory ' newDir ' not found']);
                this.gui.dirpanel.edit.String = this.currentDir;
            end
        end

        function refreshDirectory(this)
            % TODO
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        % ----- CALLBACK METHODS

        function onBrowseBtnClick(this, ~, ~)
            newDir = uigetdir(this.currentDir);
            if newDir ~= 0
                this.browseTo(newDir);
            end
        end

        function onDirChange(this, ~, ~)
            this.browseTo(this.gui.dirpanel.edit.String);
        end

        function onDirListingChange(this, ~, ~)
            % TODO
        end

        function onFileExit(this, ~, ~)
            delete(this.gui.window);
        end

    end

end
