classdef TWOMDataViewer < handle
    % TWOMDATAVIEWER Encapsulation of TWOM Data Viewer UI.

    properties

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
            this.gui.menu.file_exit = uimenu(this.gui.menu.file, ...
                'Label', 'Exit' ...
              , 'Callback', @(h, e) this.onFileExit(h, e) ...
              );

        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        % ----- CALLBACK METHODS

        function onFileExit(this, ~, ~)
            delete(this.gui.window);
        end

    end

end
