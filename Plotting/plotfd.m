function plotfd (varargin)
% PLOTFD Plot force-extension data.
%
% SYNTAX:
% plotfd(fd)
% plotfd(ax, fd)
% plotfd(..., 'ParamName', ParamValue, ...)
%
% INPUT:
% ax = axes handle (optional). If not given, used the current axes to create
%       the plot.
% fd = FdData or FdDataCollection object.
%
% KEY-VALUE PAIR ARGUMENTS:
% style = plot style. Available styles:
%         - 'normal' (default)
%         - 'semilog' (logarithmic force axis)
%         - 'log' (log-log scale)
%         - 'inv' (swap distance and force axes)
%         - 'fdt' (plot both F,t and d,t graphs in one figure)
% frange = axis range [min max] for the F axis (optional).
% drange = axis range [min max] for the d axis (optional).
%
% FLAG ARGUMENTS:
% newFigure = open a new figure window for the plot.
%             (If plotting an FdDataCollection, opens one window per plot).
%             (Note: if an axes handle was given, this option causes 'plotfd'
%             to ignore the axes handle).
% showMarks = Show data marks in the plot (only supported for 'fdt'
%       style at the moment).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parse & validate input

fd            = [];
axesHandle    = [];

if isempty(varargin)
    error('plotfd:InvalidArgument', 'Invalid arguments: no arguments given.');
end

if ishghandle(varargin{1})
    axesHandle = varargin{1};
    varargin(1) = []; % pop
end

if isempty(varargin)
    error('plotfd:InvalidArgument', 'Invalid arguments: missing data.');
end

if isa(varargin{1}, 'FdData') || isa(varargin{1}, 'FdDataCollection')
    fd = varargin{1};
    varargin(1) = []; % pop
end

defArgs = struct(...
                  'style',          'normal' ...
                , 'newFigure',      false ...
                , 'showMarks',      false ...
                , 'frange',         [] ...
                , 'drange',         [] ...
                );
args = parseArgs(varargin, defArgs, {'newFigure','showMarks'});

if isempty(axesHandle) && ~args.newFigure
    axesHandle = gca();
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Make plot

if isa(fd, 'FdDataCollection')
    if strcmpi(args.style, 'fdt')
        error('plotfd:StyleNotSupported', '"fdt" style is not supported for plotting FdDataCollections.');
    end

    for i = 1:fd.length
        plotfd(axesHandle, fd.items{i}, varargin{:});
        if ~args.newFigure && i==1
            hold(axesHandle, 'on');
        end
    end
    if ~args.newFigure
        hold(axesHandle, 'off');
    end

    title(axesHandle, '');
else
    if args.newFigure
        figure;
        axesHandle = gca();
    end

    data_d = fd.d;
    data_f = fd.f;
    data_t = fd.t;

    switch args.style
        case 'semilog'
            stripNegativeData;
            semilogy(axesHandle, data_d, data_f, '.');
        case 'log'
            stripNegativeData;
            loglog(axesHandle, data_d, data_f, '.');
        case 'inv'
            plot(axesHandle, data_f, data_d, '.');
        case 'normal'
            plot(axesHandle, data_d, data_f, '.');
        case 'fdt'
            axesHandle = subplot(2,1,1);
                plot(axesHandle, data_t, data_f, '.');
                if args.showMarks
                    plotFdtDataMarkAnnotations();
                end
                if ~isempty(args.frange)
                    ylim(axesHandle, args.frange);
                end
                ylabel(axesHandle, 'Force (pN)');

            axesHandle2 = subplot(2,1,2);
                plot(axesHandle2, data_t, data_d, '.');
                if args.showMarks
                    plotFdtDataMarkAnnotations();
                end
                if ~isempty(args.drange)
                    ylim(axesHandle2, args.drange);
                end
                xlabel(axesHandle2, 'Time (ms)');
                ylabel(axesHandle2, 'Distance ({\mu}m)');

        otherwise
            error('Invalid style "%s"', args.style);
    end

    if ~isempty(args.frange) || ~isempty(args.drange)
        if isempty(args.frange)
            args.frange = [min(data_f) max(data_f)];
        end
        if isempty(args.drange)
            args.drange = [min(data_d) max(data_d)];
        end
        switch args.style
            case 'fdt'
                % already done above
            case 'inv'
                xlim(axesHandle, args.frange);
                ylim(axesHandle, args.drange);
            otherwise
                xlim(axesHandle, args.drange);
                ylim(axesHandle, args.frange);
        end
    end

    switch args.style
        case 'fdt'
            % already done above
        case 'inv'
            xlabel(axesHandle, 'Force (pN)');
            ylabel(axesHandle, 'Distance ({\mu}m)');
        otherwise
            xlabel(axesHandle, 'Distance ({\mu}m)');
            ylabel(axesHandle, 'Force (pN)');
    end

    title(axesHandle, fd.name);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function plotFdtDataMarkAnnotations
        yrange = get(gca, 'YLim');
        for iMark = 1:length(fd.marks)
            markT  = fd.marks(iMark).time;
            markNo = fd.marks(iMark).mark;
            [point1, point2] = dsxy2figxy([markT yrange(1)], [markT yrange(2)]);
            annotation('line', [point1(1) point1(1)], [point1(2) point2(2)], 'Color', [0 0.6 0]);
            annotation('textbox', [point1(1) (point1(2)+point2(2))/2 0.1 0.1], ...
                       'String', num2str(markNo), 'Color', [0 0.6 0], 'EdgeColor', 'none');
        end
    end

    function stripNegativeData
        removeIdx = find(data_f < 0);
        data_d(removeIdx) = [];
        data_f(removeIdx) = [];
        data_t(removeIdx) = [];
    end

end

