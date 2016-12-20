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
                    set(hPlot ...
                        , 'UserData',           fd.items{i} ...
                        , 'UIContextMenu',      TDVFigureWindow.getContextMenu(h) ...
                        );
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
            xlabel('Distance (um)');
            ylabel('Force (pN)');
            hold('on');

            % Context menu for plots
            hMenu = uicontextmenu(hFig, 'Tag', TDVFigureWindow.plotContextMenuTag);
            uimenu(hMenu ...
                , 'Label',          'Delete This Plot' ...
                , 'Callback',       @(h,e) TDVFigureWindow.deleteSelectedData(hFig) ...
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

    end

end

