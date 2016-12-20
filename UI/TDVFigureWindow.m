classdef TDVFigureWindow

    properties (Constant)

        figureTag = 'twomdv-plot';

    end

    % ------------------------------------------------------------------------

    methods (Static)

        function addData(h, fd)
            if ~TDVFigureWindow.isValidFigureWindow(h)
                error('Invalid TWOMDV Figure Window handle');
            end

            figure(h);

            figFdc = get(h, 'UserData');
            if isa(fd, 'FdData')
                fd = FdDataCollection(fd);
            end
            if isa(fd, 'FdDataCollection')
                for i = 1:fd.length
                    figFdc.add(fd.items{i});
                    plot(fd.items{i}.d, fd.items{i}.f);
                end
            else
                error('Invalid argument "fd".');
            end
        end

        function [h] = create()
            h = figure(...
                      'Tag',            TDVFigureWindow.figureTag ...
                    , 'UserData',       FdDataCollection() ...
                    );
            xlabel('Distance (um)');
            ylabel('Force (pN)');
            hold('on');
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

end

