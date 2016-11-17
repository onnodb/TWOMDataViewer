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

        function [this] = FdExplorer(c)
            this.c = c;

            % Initialize state.
            this.dataShown = FdDataCollection('skipduplicatecheck', this.c);
            this.dataSelected = [];

            % Set up GUI.
            this.createGui();
            this.loadFilterTags(this.c);
            this.loadDataShown(this.dataShown);
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        function createGui(this)
            this.gui = struct();

            % ----- Window
            screenSize = get(0, 'ScreenSize');
            this.gui.window = figure(...
                'Name',             'FD Explorer' ...
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

            % ----- Main columns
            this.gui.main.panel = uiextras.HBoxFlex('Parent', this.gui.window);

            % -- Left panel
            this.gui.left.panel = uiextras.VBoxFlex('Parent', this.gui.main.panel);

            % Listbox with loaded data
            this.gui.left.list.panel = uiextras.VBox('Parent', this.gui.left.panel);
            this.gui.left.list.label = uicontrol(...
                'Parent',           this.gui.left.list.panel ...
              , 'Style',            'text' ...
              , 'String',           'Select one or more datasets:' ...
              );
            this.gui.left.list.list  = uicontrol(...
                'Parent',           this.gui.left.list.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {'Loading...'} ...
              , 'Min',              0 ...
              , 'Max',              2 ...    % allow multi-selection
              , 'Callback',         @(h, e) this.onListItemChange(h, e) ...
              );
            this.gui.left.list.bottomInfo.panel = uiextras.HBox('Parent', this.gui.left.list.panel);
            this.gui.left.list.bottomInfo.itemIdxLabel = uicontrol(...
                'Parent',           this.gui.left.list.bottomInfo.panel ...
              , 'Style',            'text' ...
              , 'String',           '' ...
              , 'HorizontalAlignment', 'left' ...
              );
            this.gui.left.list.bottomInfo.itemCountLabel = uicontrol(...
                'Parent',           this.gui.left.list.bottomInfo.panel ...
              , 'Style',            'text' ...
              , 'String',           '' ...
              , 'HorizontalAlignment', 'right' ...
              );
            set(this.gui.left.list.bottomInfo.panel, 'Sizes', [-1 -1]);
            set(this.gui.left.list.panel, 'Sizes', [20 -1 18]);

            % Tags list
            this.gui.left.tagsList.panel = uiextras.VBox('Parent', this.gui.left.panel);
            this.gui.left.tagsList.label = uicontrol(...
                'Parent',           this.gui.left.tagsList.panel ...
              , 'Style',            'text' ...
              , 'String',           'Filter by tags:' ...
              );
            this.gui.left.tagsList.list = uicontrol(...
                'Parent',           this.gui.left.tagsList.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {'Loading...'} ...
              , 'Min',              0 ...
              , 'Max',              2 ...   % allow multi-selection
              , 'Callback',         @(h, e) this.onTagsListItemChange(h, e) ...
              );
            this.gui.left.tagsList.options.panel = uiextras.HBox('Parent', this.gui.left.tagsList.panel);
            this.gui.left.tagsList.options.NOT   = uicontrol(...
                'Parent',           this.gui.left.tagsList.options.panel ...
              , 'Style',            'check' ...
              , 'String',           'NOT' ...
              , 'Value',            false ...
              , 'Callback',         @(h, e) this.onTagsListOptionsChange(h, e, 'NOT') ...
              );
            this.gui.left.tagsList.options.AND   = uicontrol(...
                'Parent',           this.gui.left.tagsList.options.panel ...
              , 'Style',            'radio' ...
              , 'String',           'AND' ...
              , 'Value',            true ...
              , 'Callback',         @(h, e) this.onTagsListOptionsChange(h, e, 'AND') ...
              );
            this.gui.left.tagsList.options.OR    = uicontrol(...
                'Parent',           this.gui.left.tagsList.options.panel ...
              , 'Style',            'radio' ...
              , 'String',           'OR' ...
              , 'Value',            false ...
              , 'Callback',         @(h, e) this.onTagsListOptionsChange(h, e, 'OR') ...
              );
            set(this.gui.left.tagsList.options.panel, 'Sizes', [-1 -1 -1]);
            set(this.gui.left.tagsList.panel, 'Sizes', [20 -1 30]);
            set(this.gui.left.panel, 'Sizes', [-3 -1]);

            % -- Middle panel
            this.gui.center.panel = uiextras.Panel('Parent', this.gui.main.panel);
            this.gui.center.axes = axes(...
                'Parent',           this.gui.center.panel ...
              , 'ActivePositionProperty', 'OuterPosition' ...
              );

            % -- Right panel
            this.gui.right.panel = uiextras.VBoxFlex('Parent', this.gui.main.panel);

            % Action buttons
            this.gui.right.buttons_label = uicontrol(...
                'Parent',           this.gui.right.panel ...
              , 'Style',            'text' ...
              , 'String',           'Options:' ...
              );
            this.gui.right.buttons.panel = uiextras.VButtonBox(...
                'Parent',           this.gui.right.panel ...
              , 'VerticalAlignment','top' ...
              , 'ButtonSize',       [200 30] ...
              , 'Spacing',          2 ...
              );
            this.gui.right.buttons.selectSubset = uicontrol(...
                'Parent',           this.gui.right.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Select subset...' ...
              , 'Callback',         @(h, e) this.onButtonSelectSubsetClick(h, e) ...
              );
            this.gui.right.buttons.exportToWorkspace = uicontrol(...
                'Parent',           this.gui.right.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Export to workspace...' ...
              , 'Callback',         @(h, e) this.onButtonExportToWorkspaceClick(h, e) ...
              );
            this.gui.right.buttons.removeFromCollection = uicontrol(...
                'Parent',           this.gui.right.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Remove from collection' ...
              , 'Callback',         @(h, e) this.onButtonRemoveFromCollectionClick(h, e) ...
              );

            % Metadata table
            this.gui.right.metadata.panel = uiextras.VBoxFlex('Parent', this.gui.right.panel);
            this.gui.right.metadata.label = uicontrol(...
                'Parent',           this.gui.right.metadata.panel ...
              , 'Style',            'text' ...
              , 'String',           'Metadata:' ...
              );
            this.gui.right.metadata.table = uitable(...
                'Parent',           this.gui.right.metadata.panel ...
              , 'Data',             {'-', '-'} ...
              , 'ColumnEditable',   [false false] ...
              , 'ColumnFormat',     {'char', 'char'} ...
              , 'ColumnName',       {'Name', 'Value'} ...
              , 'ColumnWidth',      {145 145} ...
              , 'RowName',          [] ...
              , 'RowStriping',      'on' ...
              , 'CellSelectionCallback', @(h, e) this.onMetaDataCellSelection(h, e) ...
              );
            this.gui.right.metadata.edit = uicontrol(...
                'Parent',           this.gui.right.metadata.panel ...
              , 'Style',            'edit' ...
              , 'Min',              0 ...
              , 'Max',              2 ...   % multi-line
              , 'String',           '' ...
              , 'Enable',           'inactive' ...  % read-only
              , 'HorizontalAlignment', 'left' ...
              );
            set(this.gui.right.metadata.panel, 'Sizes', [20 -4 -1]);

            % Tags list for current item
            this.gui.right.tags.panel = uiextras.VBox('Parent', this.gui.right.panel);
            this.gui.right.tags.label = uicontrol(...
                'Parent',           this.gui.right.tags.panel ...
              , 'Style',            'text' ...
              , 'String',           'Tags:' ...
              );
            this.gui.right.tags.list = uicontrol(...
                'Parent',           this.gui.right.tags.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {} ...
              , 'Min',              0 ...
              , 'Max',              2 ...   % allow multi-selection
              );
            this.gui.right.tags.buttons.panel = uiextras.VButtonBox(...
                'Parent',           this.gui.right.tags.panel ...
              , 'VerticalAlignment','top' ...
              , 'ButtonSize',       [200 24] ...
              , 'Spacing',          2 ...
              );
            this.gui.right.tags.buttons.addTag = uicontrol(...
                'Parent',           this.gui.right.tags.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Add tag...' ...
              , 'Callback',         @(h, e) this.onButtonAddTagClick(h, e) ...
              );
            this.gui.right.tags.buttons.removeTag = uicontrol(...
                'Parent',           this.gui.right.tags.buttons.panel ...
              , 'Style',            'pushbutton' ...
              , 'String',           'Remove tag(s)' ...
              , 'Callback',         @(h, e) this.onButtonRemoveTagClick(h, e) ...
              );
            set(this.gui.right.tags.panel, 'Sizes', [20 -1 (26*(length(fieldnames(this.gui.right.tags.buttons))-1))]);

            % History
            this.gui.right.history.panel = uiextras.VBox('Parent', this.gui.right.panel);
            this.gui.right.history.label = uicontrol(...
                'Parent',           this.gui.right.history.panel ...
              , 'Style',            'text' ...
              , 'String',           'History:' ...
              );
            this.gui.right.history.list = uicontrol(...
                'Parent',           this.gui.right.history.panel ...
              , 'Style',            'listbox' ...
              , 'String',           {} ...
              );
            set(this.gui.right.history.panel, 'Sizes', [20 -1]);

            % Sizing
            set(this.gui.main.panel, 'Sizes', [300 -1 300]);
            set(this.gui.right.panel, 'Sizes', [20 (32*(length(fieldnames(this.gui.right.buttons))-1)) -3 -1.5 -1]);
        end

        function loadData(this, data)
            % LOADDATA Load the FdDataCollection contents into the user interface.

            % Draw the F,d graph.
            cla(this.gui.center.axes);
            legend(this.gui.center.axes, 'off');
            if isempty(this.plotFcn)
                plotfd(this.gui.center.axes, data);
            else
                this.plotFcn(this.gui.center.axes, data);
            end

            % Load the metadata properties.
            this.loadMetaData(data);

            % Load the tags.
            this.loadItemTags(data);

            % Load the history.
            this.loadItemHistory(data);

            % Update item index label, if one single item selected.
            if data.length == 1
                set(this.gui.left.list.bottomInfo.itemIdxLabel, 'String', sprintf('Item %d', this.c.indexOf(data.items{1})));
            else
                set(this.gui.left.list.bottomInfo.itemIdxLabel, 'String', '');
            end
        end

        function loadDataShown(this, dataShown)
            % LOADDATASHOWN Update to UI to reflect the "dataShown" property.

            listOfNames = cell(1,dataShown.length);
            for i = 1:dataShown.length
                listOfNames{i} = dataShown.items{i}.name;
            end

            set(this.gui.left.list.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(this.gui.left.list.list, 'String', listOfNames);
            set(this.gui.left.list.bottomInfo.itemCountLabel, 'String', sprintf('%d item(s)', dataShown.length));
        end

        function loadFilterTags(this, collection)
            % LOADFILTERTAGS Load the "filter by tags" listbox.

            this.availableTags = collection.getAllTags();

            set(this.gui.left.tagsList.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(this.gui.left.tagsList.list, 'String', [{'(Show all)'} this.availableTags]);
        end

        function loadItemHistory(this, data)
            % LOADITEMHISTORY Load the history list of the given item into the UI.

            if data.length > 1
                hist = {''};
            else
                hist = data.items{1}.history;
            end

            set(this.gui.right.history.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(this.gui.right.history.list, ...
                'String', hist ...
                );
        end

        function loadItemTags(this, data)
            % LOADITEMTAGS Load the tags of the given item into the UI.

            if data.length > 1
                tags = data.getCommonTags();
            else
                tags = data.items{1}.tags;
            end

            set(this.gui.right.tags.list, 'Value', 1);       % http://www.mathworks.nl/support/solutions/en/data/1-Y4TJB/?solution=1-Y4TJB
            set(this.gui.right.tags.list, ...
                'String', tags ...
                );
        end

        function loadMetaData(this, data)
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

            set(this.gui.right.metadata.table ...
              , 'Data', data ...
                );
            set(this.gui.right.metadata.edit, 'String', '');
        end

    end

    % ------------------------------------------------------------------------

    methods (Access=private)

        % ----- CALLBACK METHODS

        function onFileExit(this, ~, ~)
            delete(this.gui.window);
        end

        function onButtonRemoveTagClick(this, ~, ~)
            listItems = get(this.gui.right.tags.list, 'String');
            itemsSelected = get(this.gui.right.tags.list, 'Value');

            if ~isempty(this.dataSelected) && ~isempty(itemsSelected)
                for i = itemsSelected
                    this.dataSelected.forAll(@(x) x.removeTag(listItems{i}));
                end

                this.loadFilterTags(this.c);
                this.loadItemTags(this.dataSelected);
            end
        end

        function onButtonAddTagClick(this, ~, ~)
            if ~isempty(this.dataSelected)
                dlgAns = inputdlg(...
                    ['Please enter one or more tags to add. ' ...
                     'You can separate multiple tags with commas.'], ...
                    'Add tag');
                if ~isempty(dlgAns)
                    tagsToAdd = strsplit(dlgAns{1}, ',');
                    for tag = tagsToAdd
                        this.dataSelected.forAll(@(x) x.addTag(strtrim(tag{:})));
                    end
                end

                this.loadFilterTags(this.c);
                this.loadItemTags(this.dataSelected);
            end
        end

        function onButtonExportToWorkspaceClick(this, ~, ~)
            if ~isempty(this.dataSelected)
                exportVarName = inputdlg(...
                    'Please enter a name for the variable to be exported.', ...
                    'Export to workspace', ...
                    1, {'fd'} ...
                    );
                if ~isempty(exportVarName)
                    if this.dataSelected.length > 1
                        assignin('base', exportVarName{1}, this.dataSelected.copy());
                    else
                        assignin('base', exportVarName{1}, this.dataSelected.items{1});
                    end
                end
            end
        end

        function onButtonRemoveFromCollectionClick(this, ~, ~)
            if ~isempty(this.dataSelected)
                listSelectionBeforeDelete = get(this.gui.left.list.list, 'Value');

                this.dataShown.remove(this.dataSelected);
                this.c.remove(this.dataSelected);

                this.dataSelected = [];
                this.loadDataShown(this.dataShown);
                this.loadFilterTags(this.c);

                % Try to restore item selection
                set(this.gui.left.list.list, 'Value', ...
                    min([ min(listSelectionBeforeDelete)-1 length(get(this.gui.left.list.list, 'String')) ]) ...
                    );
            end
        end

        function onButtonSelectSubsetClick(this, ~, ~)
            if ~isempty(this.dataSelected)
                for i = 1:this.dataSelected.length
                    oldItem = this.dataSelected.items{i};
                    newItem = trimfd(oldItem);
                    if eq(oldItem, newItem)  % dialog cancelled
                        return
                    end

                    this.c.replace(oldItem, newItem);
                    this.dataShown.replace(oldItem, newItem);
                end

                this.dataSelected = [];
            end
        end

        function onListItemChange(this, ~, ~)
            itemsSelected = get(this.gui.left.list.list, 'Value');

            this.dataSelected = FdDataCollection();
            for i = 1:length(itemsSelected)
                this.dataSelected.add('skipduplicatecheck', this.dataShown.items{itemsSelected(i)});
            end

            this.loadData(this.dataSelected);
        end

        function onMetaDataCellSelection(this, ~, e)
            if ~isempty(this.dataSelected) && ~isempty(e.Indices)
                fn = fieldnames(this.dataSelected.items{1}.metaData);

                val = this.dataSelected.items{1}.metaData.(fn{e.Indices(1,1)});
            else
                val = '';
            end

            set(this.gui.right.metadata.edit, 'String', val);
        end

        function onTagsListItemChange(this, ~, ~)
            itemsSelected = get(this.gui.left.tagsList.list, 'Value');
            andFilter = get(this.gui.left.tagsList.options.AND, 'Value');
            notSelected = get(this.gui.left.tagsList.options.NOT, 'Value');

            % Remove "(Show all)" item, and correct indices
            itemsSelected(itemsSelected == 1) = [];
            itemsSelected = itemsSelected - 1;

            % Apply filter
            if isempty(itemsSelected)
                this.dataShown = FdDataCollection('skipduplicatecheck', this.c);
            else
                % Filter items shown on tags selected
                if andFilter
                    this.dataShown = FdDataCollection('skipduplicatecheck', this.c);
                else
                    this.dataShown = FdDataCollection();
                end

                for i = 1:length(itemsSelected)
                    if andFilter
                        this.dataShown = this.dataShown.intersect(...
                                                this.c.getByTag(...
                                                        this.availableTags{itemsSelected(i)} ...
                                                        ));
                    else
                        this.dataShown = this.dataShown.union(...
                                                this.c.getByTag(...
                                                        this.availableTags{itemsSelected(i)} ...
                                                        ));
                    end
                end

                if notSelected
                    this.dataShown = this.c.subtract(this.dataShown);
                end
            end

            this.loadDataShown(this.dataShown);
        end

        function onTagsListOptionsChange(this, ~, ~, option)
            switch option
                case 'AND'
                    set(this.gui.left.tagsList.options.OR, 'Value', false);
                    set(this.gui.left.tagsList.options.AND, 'Value', true);
                case 'OR'
                    set(this.gui.left.tagsList.options.OR, 'Value', true);
                    set(this.gui.left.tagsList.options.AND, 'Value', false);
                case 'NOT'
                    % nothing to update in UI in this case
                otherwise
                    error('Invalid "option" argument "%s" in onTagsListOptionsChange', option);
            end

            this.onTagsListItemChange([], []);
        end

    end

end

