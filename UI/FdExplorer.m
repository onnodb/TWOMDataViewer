classdef FdExplorer < handle
    % FDEXPLORER Encapsulation of the FdExplorer UI.

    properties

        % FdDataCollection
        c;

        % Optional handle to an alternative plotting function.
        % should have the prototype:
        %     plotFcn(axes_handle, data)
        % with 'data' being an FdDataCollection.
        plotFcn = [];

    end


    % ------------------------------------------------------------------------

    properties (Access=protected)

        % Internal variable containing object handles.
        gui;

        % Data items shown in the listbox on the left-hand side.
        % (As an FdDataCollection)
        dataShown;

        % Currently selected data.
        % (As an FdDataCollection)
        dataSelected;

        % Available filter tags (cell string).
        availableTags;

    end

    % ------------------------------------------------------------------------

    methods

        function [self] = FdExplorer(c)
            self.c = c;

            % Initialize state.
            self.dataShown = FdDataCollection('skipduplicatecheck', self.c);
            self.dataSelected = [];

            % Set up GUI.
            self.createGui();
            self.loadFilterTags(self.c);
            self.loadDataShown(self.dataShown);
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        function createGui(self)
            self.gui = struct();

            % ----- Window
            screenSize = get(0, 'ScreenSize');
            self.gui.window = figure(...
                'Name',             'FD Explorer' ...
              , 'NumberTitle',      'off' ...
              , 'MenuBar',          'none' ...
              , 'Toolbar',          'none' ...
              , 'HandleVisibility', 'off' ...
              , 'Position',         [screenSize(3)/8 screenSize(4)/8 screenSize(3)/1.3 screenSize(4)/1.3] ...
              );

            % ----- Menu
            % + File
            self.gui.menu.file = uimenu(self.gui.window, 'Label', 'File');
            self.gui.menu.file_exit = uimenu(self.gui.menu.file, ...
                'Label', 'Exit' ...
              , 'Callback', @(h, e) self.onFileExit(h, e) ...
              );

            % ----- Main columns
            self.gui.main.panel = uiextras.HBoxFlex('Parent', self.gui.window);

            % -- Left panel
            self.gui.left.panel = uiextras.VBoxFlex('Parent', self.gui.main.panel);

            % Listbox with loaded data
            self.gui.left.list.panel = uiextras.VBox('Parent', self.gui.left.panel);
            self.gui.left.list.label = uicontrol(...
                'Parent',           self.gui.left.list.panel ...
              , 'Style',            'text' ...
              , 'String',           'Select one or more datasets:' ...
              );
            self.gui.left.list.list  = uicontrol(...
                'Parent',           self.gui.left.list.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {'Loading...'} ...
              , 'Min',              0 ...
              , 'Max',              2 ...    % allow multi-selection
              , 'Callback',         @(h, e) self.onListItemChange(h, e) ...
              );
            self.gui.left.list.bottomInfo.panel = uiextras.HBox('Parent', self.gui.left.list.panel);
            self.gui.left.list.bottomInfo.itemIdxLabel = uicontrol(...
                'Parent',           self.gui.left.list.bottomInfo.panel ...
              , 'Style',            'text' ...
              , 'String',           '' ...
              , 'HorizontalAlignment', 'left' ...
              );
            self.gui.left.list.bottomInfo.itemCountLabel = uicontrol(...
                'Parent',           self.gui.left.list.bottomInfo.panel ...
              , 'Style',            'text' ...
              , 'String',           '' ...
              , 'HorizontalAlignment', 'right' ...
              );
            set(self.gui.left.list.bottomInfo.panel, 'Sizes', [-1 -1]);
            set(self.gui.left.list.panel, 'Sizes', [20 -1 18]);

            % Tags list
            self.gui.left.tagsList.panel = uiextras.VBox('Parent', self.gui.left.panel);
            self.gui.left.tagsList.label = uicontrol(...
                'Parent',           self.gui.left.tagsList.panel ...
              , 'Style',            'text' ...
              , 'String',           'Filter by tags:' ...
              );
            self.gui.left.tagsList.list = uicontrol(...
                'Parent',           self.gui.left.tagsList.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {'Loading...'} ...
              , 'Min',              0 ...
              , 'Max',              2 ...   % allow multi-selection
              , 'Callback',         @(h, e) self.onTagsListItemChange(h, e) ...
              );
            self.gui.left.tagsList.options.panel = uiextras.HBox('Parent', self.gui.left.tagsList.panel);
            self.gui.left.tagsList.options.NOT   = uicontrol(...
                'Parent',           self.gui.left.tagsList.options.panel ...
              , 'Style',            'check' ...
              , 'String',           'NOT' ...
              , 'Value',            false ...
              , 'Callback',         @(h, e) self.onTagsListOptionsChange(h, e, 'NOT') ...
              );
            self.gui.left.tagsList.options.AND   = uicontrol(...
                'Parent',           self.gui.left.tagsList.options.panel ...
              , 'Style',            'radio' ...
              , 'String',           'AND' ...
              , 'Value',            true ...
              , 'Callback',         @(h, e) self.onTagsListOptionsChange(h, e, 'AND') ...
              );
            self.gui.left.tagsList.options.OR    = uicontrol(...
                'Parent',           self.gui.left.tagsList.options.panel ...
              , 'Style',            'radio' ...
              , 'String',           'OR' ...
              , 'Value',            false ...
              , 'Callback',         @(h, e) self.onTagsListOptionsChange(h, e, 'OR') ...
              );
            set(self.gui.left.tagsList.options.panel, 'Sizes', [-1 -1 -1]);
            set(self.gui.left.tagsList.panel, 'Sizes', [20 -1 30]);
            set(self.gui.left.panel, 'Sizes', [-3 -1]);

            % -- Middle panel
            self.gui.center.panel = uiextras.Panel('Parent', self.gui.main.panel);
            self.gui.center.axes = axes(...
                'Parent',           self.gui.center.panel ...
              , 'ActivePositionProperty', 'OuterPosition' ...
              );

            % -- Right panel
            self.gui.right.panel = uiextras.VBoxFlex('Parent', self.gui.main.panel);

            % Action buttons
            self.gui.right.buttons_label = uicontrol(...
                'Parent',           self.gui.right.panel ...
              , 'Style',            'text' ...
              , 'String',           'Options:' ...
              );
            self.gui.right.buttons.panel = uiextras.VButtonBox(...
                'Parent',           self.gui.right.panel ...
              , 'VerticalAlignment','top' ...
              , 'ButtonSize',       [200 30] ...
              , 'Spacing',          2 ...
              );
            self.gui.right.buttons.selectSubset = uicontrol(...
                'Parent',           self.gui.right.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Select subset...' ...
              , 'Callback',         @(h, e) self.onButtonSelectSubsetClick(h, e) ...
              );
            self.gui.right.buttons.exportToWorkspace = uicontrol(...
                'Parent',           self.gui.right.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Export to workspace...' ...
              , 'Callback',         @(h, e) self.onButtonExportToWorkspaceClick(h, e) ...
              );
            self.gui.right.buttons.removeFromCollection = uicontrol(...
                'Parent',           self.gui.right.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Remove from collection' ...
              , 'Callback',         @(h, e) self.onButtonRemoveFromCollectionClick(h, e) ...
              );

            % Metadata table
            self.gui.right.metadata.panel = uiextras.VBoxFlex('Parent', self.gui.right.panel);
            self.gui.right.metadata.label = uicontrol(...
                'Parent',           self.gui.right.metadata.panel ...
              , 'Style',            'text' ...
              , 'String',           'Metadata:' ...
              );
            self.gui.right.metadata.table = uitable(...
                'Parent',           self.gui.right.metadata.panel ...
              , 'Data',             {'-', '-'} ...
              , 'ColumnEditable',   [false false] ...
              , 'ColumnFormat',     {'char', 'char'} ...
              , 'ColumnName',       {'Name', 'Value'} ...
              , 'ColumnWidth',      {145 145} ...
              , 'RowName',          [] ...
              , 'RowStriping',      'on' ...
              , 'CellSelectionCallback', @(h, e) self.onMetaDataCellSelection(h, e) ...
              );
            self.gui.right.metadata.edit = uicontrol(...
                'Parent',           self.gui.right.metadata.panel ...
              , 'Style',            'edit' ...
              , 'Min',              0 ...
              , 'Max',              2 ...   % multi-line
              , 'String',           '' ...
              , 'Enable',           'inactive' ...  % read-only
              , 'HorizontalAlignment', 'left' ...
              );
            set(self.gui.right.metadata.panel, 'Sizes', [20 -4 -1]);

            % Tags list for current item
            self.gui.right.tags.panel = uiextras.VBox('Parent', self.gui.right.panel);
            self.gui.right.tags.label = uicontrol(...
                'Parent',           self.gui.right.tags.panel ...
              , 'Style',            'text' ...
              , 'String',           'Tags:' ...
              );
            self.gui.right.tags.list = uicontrol(...
                'Parent',           self.gui.right.tags.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {} ...
              , 'Min',              0 ...
              , 'Max',              2 ...   % allow multi-selection
              );
            self.gui.right.tags.buttons.panel = uiextras.VButtonBox(...
                'Parent',           self.gui.right.tags.panel ...
              , 'VerticalAlignment','top' ...
              , 'ButtonSize',       [200 24] ...
              , 'Spacing',          2 ...
              );
            self.gui.right.tags.buttons.addTag = uicontrol(...
                'Parent',           self.gui.right.tags.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Add tag...' ...
              , 'Callback',         @(h, e) self.onButtonAddTagClick(h, e) ...
              );
            self.gui.right.tags.buttons.removeTag = uicontrol(...
                'Parent',           self.gui.right.tags.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Remove tag(s)' ...
              , 'Callback',         @(h, e) self.onButtonRemoveTagClick(h, e) ...
              );
            set(self.gui.right.tags.panel, 'Sizes', [20 -1 (26*(length(fieldnames(self.gui.right.tags.buttons))-1))]);

            % History
            self.gui.right.history.panel = uiextras.VBox('Parent', self.gui.right.panel);
            self.gui.right.history.label = uicontrol(...
                'Parent',           self.gui.right.history.panel ...
              , 'Style',            'text' ...
              , 'String',           'History:' ...
              );
            self.gui.right.history.list = uicontrol(...
                'Parent',           self.gui.right.history.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {} ...
              );
            set(self.gui.right.history.panel, 'Sizes', [20 -1]);

            % Sizing
            set(self.gui.main.panel, 'Sizes', [300 -1 300]);
            set(self.gui.right.panel, 'Sizes', [20 (32*(length(fieldnames(self.gui.right.buttons))-1)) -3 -1.5 -1]);
        end

        function loadData(self, data)
            % LOADDATA Load the FdDataCollection contents into the user interface.

            % Draw the F,d graph.
            cla(self.gui.center.axes);
            legend(self.gui.center.axes, 'off');
            if isempty(self.plotFcn)
                plotfd(self.gui.center.axes, data);
            else
                self.plotFcn(self.gui.center.axes, data);
            end

            % Load the metadata properties.
            self.loadMetaData(data);

            % Load the tags.
            self.loadItemTags(data);

            % Load the history.
            self.loadItemHistory(data);

            % Update item index label, if one single item selected.
            if data.length == 1
                set(self.gui.left.list.bottomInfo.itemIdxLabel, 'String', sprintf('Item %d', self.c.indexOf(data.items{1})));
            else
                set(self.gui.left.list.bottomInfo.itemIdxLabel, 'String', '');
            end
        end

        function loadDataShown(self, dataShown)
            % LOADDATASHOWN Update to UI to reflect the "dataShown" property.

            listOfNames = cell(1,dataShown.length);
            for i = 1:dataShown.length
                listOfNames{i} = dataShown.items{i}.name;
            end

            set(self.gui.left.list.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(self.gui.left.list.list, 'String', listOfNames);
            set(self.gui.left.list.bottomInfo.itemCountLabel, 'String', sprintf('%d item(s)', dataShown.length));
        end

        function loadFilterTags(self, collection)
            % LOADFILTERTAGS Load the "filter by tags" listbox.

            self.availableTags = collection.getAllTags();

            set(self.gui.left.tagsList.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(self.gui.left.tagsList.list, 'String', [{'(Show all)'} self.availableTags]);
        end

        function loadItemHistory(self, data)
            % LOADITEMHISTORY Load the history list of the given item into the UI.

            if data.length > 1
                hist = {''};
            else
                hist = data.items{1}.history;
            end

            set(self.gui.right.history.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(self.gui.right.history.list, ...
                'String', hist ...
                );
        end

        function loadItemTags(self, data)
            % LOADITEMTAGS Load the tags of the given item into the UI.

            if data.length > 1
                tags = data.getCommonTags();
            else
                tags = data.items{1}.tags;
            end

            set(self.gui.right.tags.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(self.gui.right.tags.list, ...
                'String', tags ...
                );
        end

        function loadMetaData(self, data)
            % LOADMETADATA Load the metadata of the given item into the UI.

            if data.length > 1
                data = {'', ''};
            else
                item = data.items{1};
                fn = fieldnames(item.metaData);
                vals = cell(length(fn),1);
                for i = 1:length(fn)
                    vals{i} = item.metaData.(fn{i});

                    if isnumeric(vals{i}) || islogical(vals{i})
                        if isscalar(vals{i})
                            % ok
                        else
                            vals{i} = mat2str(vals{i});
                        end
                    elseif ischar(vals{i})
                        % ok
                    else
                        vals{i} = '<cannot display>';
                    end
                end
                data = [fn(:) vals(:)];
            end

            set(self.gui.right.metadata.table ...
              , 'Data', data ...
                );
            set(self.gui.right.metadata.edit, 'String', '');
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        % ----- CALLBACK METHODS

        function onFileExit(self, ~, ~)
            delete(self.gui.window);
        end

        function onButtonRemoveTagClick(self, ~, ~)
            listItems = get(self.gui.right.tags.list, 'String');
            itemsSelected = get(self.gui.right.tags.list, 'Value');

            if ~isempty(self.dataSelected) && ~isempty(itemsSelected)
                for i = itemsSelected
                    self.dataSelected.forAll(@(x) x.removeTag(listItems{i}));
                end

                self.loadFilterTags(self.c);
                self.loadItemTags(self.dataSelected);
            end
        end

        function onButtonAddTagClick(self, ~, ~)
            if ~isempty(self.dataSelected)
                dlgAns = inputdlg(...
                    ['Please enter one or more tags to add. ' ...
                     'You can separate multiple tags with commas.'], ...
                    'Add tag');
                if ~isempty(dlgAns)
                    tagsToAdd = strsplit(dlgAns{1}, ',');
                    for tag = tagsToAdd
                        self.dataSelected.forAll(@(x) x.addTag(strtrim(tag{:})));
                    end
                end

                self.loadFilterTags(self.c);
                self.loadItemTags(self.dataSelected);
            end
        end

        function onButtonExportToWorkspaceClick(self, ~, ~)
            if ~isempty(self.dataSelected)
                exportVarName = inputdlg(...
                    'Please enter a name for the variable to be exported.', ...
                    'Export to workspace', ...
                    1, {'fd'} ...
                    );
                if ~isempty(exportVarName)
                    if self.dataSelected.length > 1
                        assignin('base', exportVarName{1}, self.dataSelected.copy());
                    else
                        assignin('base', exportVarName{1}, self.dataSelected.items{1});
                    end
                end
            end
        end

        function onButtonRemoveFromCollectionClick(self, ~, ~)
            if ~isempty(self.dataSelected)
                listSelectionBeforeDelete = get(self.gui.left.list.list, 'Value');

                self.dataShown.remove(self.dataSelected);
                self.c.remove(self.dataSelected);

                self.dataSelected = [];
                self.loadDataShown(self.dataShown);
                self.loadFilterTags(self.c);

                % Try to restore item selection
                set(self.gui.left.list.list, 'Value', ...
                    min([ min(listSelectionBeforeDelete)-1 length(get(self.gui.left.list.list, 'String')) ]) ...
                    );
            end
        end

        function onButtonSelectSubsetClick(self, ~, ~)
            if ~isempty(self.dataSelected)
                for i = 1:self.dataSelected.length
                    oldItem = self.dataSelected.items{i};
                    newItem = trimfd(oldItem);
                    if eq(oldItem, newItem)  % dialog cancelled
                        return
                    end

                    self.c.replace(oldItem, newItem);
                    self.dataShown.replace(oldItem, newItem);
                end

                self.dataSelected = [];
            end
        end

        function onListItemChange(self, ~, ~)
            itemsSelected = get(self.gui.left.list.list, 'Value');

            self.dataSelected = FdDataCollection();
            for i = 1:length(itemsSelected)
                self.dataSelected.add('skipduplicatecheck', self.dataShown.items{itemsSelected(i)});
            end

            self.loadData(self.dataSelected);
        end

        function onMetaDataCellSelection(self, ~, e)
            if ~isempty(self.dataSelected) && ~isempty(e.Indices)
                fn = fieldnames(self.dataSelected.items{1}.metaData);

                val = self.dataSelected.items{1}.metaData.(fn{e.Indices(1,1)});
            else
                val = '';
            end

            set(self.gui.right.metadata.edit, 'String', val);
        end

        function onTagsListItemChange(self, ~, ~)
            itemsSelected = get(self.gui.left.tagsList.list, 'Value');
            andFilter = get(self.gui.left.tagsList.options.AND, 'Value');
            notSelected = get(self.gui.left.tagsList.options.NOT, 'Value');

            % Remove "(Show all)" item, and correct indices
            itemsSelected(itemsSelected == 1) = [];
            itemsSelected = itemsSelected - 1;

            % Apply filter
            if isempty(itemsSelected)
                self.dataShown = FdDataCollection('skipduplicatecheck', self.c);
            else
                % Filter items shown on tags selected
                if andFilter
                    self.dataShown = FdDataCollection('skipduplicatecheck', self.c);
                else
                    self.dataShown = FdDataCollection();
                end

                for i = 1:length(itemsSelected)
                    if andFilter
                        self.dataShown = self.dataShown.intersect(...
                                                self.c.getByTag(...
                                                        self.availableTags{itemsSelected(i)} ...
                                                        ));
                    else
                        self.dataShown = self.dataShown.union(...
                                                self.c.getByTag(...
                                                        self.availableTags{itemsSelected(i)} ...
                                                        ));
                    end
                end

                if notSelected
                    self.dataShown = self.c.subtract(self.dataShown);
                end
            end

            self.loadDataShown(self.dataShown);
        end

        function onTagsListOptionsChange(self, ~, ~, option)
            switch option
                case 'AND'
                    set(self.gui.left.tagsList.options.OR, 'Value', false);
                    set(self.gui.left.tagsList.options.AND, 'Value', true);
                case 'OR'
                    set(self.gui.left.tagsList.options.OR, 'Value', true);
                    set(self.gui.left.tagsList.options.AND, 'Value', false);
                case 'NOT'
                    % nothing to update in UI in self case
                otherwise
                    error('Invalid "option" argument "%s" in onTagsListOptionsChange', option);
            end

            self.onTagsListItemChange([], []);
        end

    end

end

