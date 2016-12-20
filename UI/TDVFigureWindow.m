classdef TDVFigureWindow

    properties (Constant)

        figureTag          = 'twomdv-plot';
        plotContextMenuTag = 'twomdv-plot-cm';

    end

    % ------------------------------------------------------------------------

    methods (Static)

        function addData(h, fd)
            TDVFigureWindow.checkValidFigureWindow(h);

            figure(h);

            figFdc = get(h, 'UserData');
            if isa(fd, 'FdData')
                fd = FdDataCollection(fd);
            end
            if isa(fd, 'FdDataCollection')
                for i = 1:fd.length
                    figFdc.add(fd.items{i});
                    hPlot = plot(fd.items{i}.d, fd.items{i}.f);
                    TDVFigureWindow.setPlotProperties(hPlot, fd.items{i});
                end
            else
                error('Invalid argument "fd".');
            end
        end

        function [hFig] = create()
            hFig = figure(...
                      'Tag',            TDVFigureWindow.figureTag ...
                    , 'UserData',       FdDataCollection() ...
                    );
            TDVFigureWindow.switchDisplay(hFig, 'fd');

            % Context menu for plots
            hMenu = uicontextmenu(hFig, 'Tag', TDVFigureWindow.plotContextMenuTag);
            uimenu(hMenu ...
                , 'Label',          'Export This Plot''s Data to Workspace' ...
                , 'Callback',       @(h,e) TDVFigureWindow.exportData(hFig, 'selected') ...
                );
            uimenu(hMenu ...
                , 'Separator',      'on' ...
                , 'Label',          'Delete This Plot' ...
                , 'Callback',       @(h,e) TDVFigureWindow.deleteSelectedData(hFig) ...
                );

            % Main menu items
            hDataMenu = uimenu('Label', 'Data');

            hDataShowAsMenu = uimenu(hDataMenu, 'Label', 'Show As');
            for item = {{'F,d', 'fd'}, {'F,t', 'ft'}, {'d,t', 'dt'}}
                uimenu(hDataShowAsMenu ...
                    , 'Label',          sprintf('%s Plot', item{1}{1}) ...
                    , 'Callback',       @(h,e) TDVFigureWindow.switchDisplay(hFig, item{1}{2}) ...
                    );
            end

            uimenu(hDataMenu ...
                , 'Label',          'Duplicate to New Window' ...
                , 'Callback',       @(h,e) TDVFigureWindow.duplicate(hFig) ...
                );
            uimenu(hDataMenu ...
                , 'Label',          'Export All Data to Workspace' ...
                , 'Callback',       @(h,e) TDVFigureWindow.exportData(hFig, 'all') ...
                );
        end

        function deleteSelectedData(h)
            TDVFigureWindow.checkValidFigureWindow(h);
            fd = get(gco(h), 'UserData');
            if strcmp(get(gco(h), 'Type'), 'line') && isa(fd, 'FdData')
                fdc = get(h, 'UserData');
                fdc.remove(fd);
                delete(gco(h));
            end
        end

        function duplicate(h)
            TDVFigureWindow.checkValidFigureWindow(h);
            h2 = TDVFigureWindow.create();
            TDVFigureWindow.addData(h2, get(h, 'UserData'));
        end

        function exportData(h, whatToExport)
            TDVFigureWindow.checkValidFigureWindow(h);
            switch whatToExport
                case 'all'
                    fd = get(h, 'UserData');    % FdDataCollection
                case 'selected'
                    fd = get(gco(h), 'UserData');
                    if ~isa(fd, 'FdData')
                        return
                    end
                otherwise
                    error('Invalid argument "whatToExport".');
            end

            name = inputdlg('Please enter a name for the workspace variable:');
            if ~isempty(name) && ischar(name{1}) && ~isempty(name{1})
                name = name{1};
                if isvarname(name)
                    assignin('base', name, fd);
                    fprintf('The variable "%s" now contains the exported data:\n', name);
                    disp(fd);
                else
                    errordlg(sprintf('The name "%s" is not a valid variable name.', name));
                end
            else
                disp('Export cancelled');
            end
        end

        function [h] = findAll()
            h = findobj(...
                      'Type',           'figure' ...
                    , 'Tag',            TDVFigureWindow.figureTag ...
                    );
        end

        function [b] = isValidFigureWindow(h)
            b = false;
            if isgraphics(h, 'figure')
                b = strcmp(get(h, 'Tag'), TDVFigureWindow.figureTag) ...
                    && isa(get(h, 'UserData'), 'FdDataCollection');
            end
        end

        function switchDisplay(h, newMode)
            TDVFigureWindow.checkValidFigureWindow(h);

            figure(h);
            cla();

            switch newMode
                case 'fd'
                    xlabel('Distance (um)');
                    ylabel('Force (pN)');
                case 'ft'
                    xlabel('Time (s)');
                    ylabel('Force (pN)');
                case 'dt'
                    xlabel('Time (s)');
                    ylabel('Distance (um)');
                otherwise
                    error('Invalid display mode "%s".', newMode);
            end
            hold('on');

            fdc = get(h, 'UserData');
            if ~fdc.isempty
                % Plot data
                for i = 1:fdc.length
                    switch newMode
                        case 'fd'
                            hPlot = plot(fdc.items{i}.d, fdc.items{i}.f);
                        case 'ft'
                            hPlot = plot(fdc.items{i}.t, fdc.items{i}.f);
                        case 'dt'
                            hPlot = plot(fdc.items{i}.t, fdc.items{i}.d);
                    end
                    TDVFigureWindow.setPlotProperties(hPlot, fdc.items{i});
                end
            end
        end

    end

    % ------------------------------------------------------------------------

    methods (Static, Access=private)

        function checkValidFigureWindow(h)
            if ~TDVFigureWindow.isValidFigureWindow(h)
                error('Invalid TWOMDV Figure Window handle');
            end
        end

        function [hMenu] = getContextMenu(h)
            TDVFigureWindow.checkValidFigureWindow(h);
            hMenu = findobj(h, 'Type', 'uicontextmenu', ...
                            'Tag', TDVFigureWindow.plotContextMenuTag);
        end

        function setPlotProperties(hPlot, fd)
            set(hPlot ...
                , 'DisplayName',        fd.name ...
                , 'UserData',           fd ...
                , 'UIContextMenu',      TDVFigureWindow.getContextMenu(ancestor(hPlot, 'figure')) ...
                );
        end

    end

end

