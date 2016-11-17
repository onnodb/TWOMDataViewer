function [fd_trimmed] = trimfd(fd)
% TRIMFD Shows a user interface for selecting a subset of FdData
%
% Call this function with an FdData as input, and it will show you a simple
% dialog window that allows you to select just a subset of the data. Useful
% to, for example, extract an F,d curve out of a raw data file.
%
% Drag the cursors to select the range of data to include, and press "OK"
% to proceed. The trimmed FdData object is output as the function's only
% output argument. The trimming step is stored to the output object's "history"
% property.
%
% SYNTAX:
% fd_trimmed = trimfd(fd);
%
% INPUT:
% fd = FdData object
%
% OUTPUT:
% fd_trimmed = FdData object with the selected subset of data
%              (or the original object if the dialog was cancelled)

% Global variable for the data range (indices in "t" array) that has been
% selected
dataRangeSelected = [1 length(fd.t)];
fd_trimmed = fd;

% Create the dialog window
hDlg = makeDialog;

% Create "cursors" objects that take care of the draggable cursors
% (see 'Lib\cursors.m')
cur1 = cursors(get(findobj('Tag', 'Plot.Ft'), 'Parent'), [1 0 0]);
cur2 = cursors(get(findobj('Tag', 'Plot.dt'), 'Parent'), [1 0 0]);

% Add cursors at initial positions
minT = min(fd.t);
maxT = max(fd.t);
cur1.add(minT + (maxT-minT)/100);        % make sure cursor is visible
cur1.add(maxT);
cur2.add(minT + (maxT-minT)/100);
cur2.add(maxT);

% Hook up event handlers
addlistener(cur1, 'onDrag', @cursor_drag);
addlistener(cur2, 'onDrag', @cursor_drag);

% Wait for the user to finish
uiwait;

% Cleanup
delete(cur1);
delete(cur2);
delete(hDlg);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function [handle] = makeDialog
        handle = figure('Units',            'normalized' ...
                       , 'OuterPosition',    [0.05 0.05 0.9 0.9] ...
                       , 'Name',             ['Trim F,d Data - ' fd.name] ...
                       , 'NumberTitle',      'off' ...
                       , 'MenuBar',          'none' ...
                       , 'Toolbar',          'none' ...
                       , 'KeyPressFcn',      @dlg_keypress ...
                       , 'CloseRequestFcn',  @dlg_closerequest ...
                       );

        % F,t graph (right top)
        subplot(2,2,2);
        plot(fd.t, fd.f, 'Tag', 'Plot.Ft');
        ylabel('Force (pN)');

        % d,t graph (right bottom)
        subplot(2,2,4);
        plot(fd.t, fd.d, 'Tag', 'Plot.dt');
        xlabel('Time (ms)');
        ylabel('Distance ({\mu}m)');

        % F,d graph (left)
        subplot(2,2,[1 3]);
        plot(fd.d, fd.f, '.', 'Tag', 'Plot.Fd', 'MarkerSize', 4);
        xlabel('Distance ({\mu}m)');
        ylabel('Force(pN)');

        % Add "Select" button (bottom left corner)
        uicontrol(handle, 'Style', 'pushbutton', 'String', 'Select', ...
                  'Position', [10 10 100 30], 'Tag', 'OkBtn', ...
                  'Callback', @okbtn_callback);
        % Add "Cancel" button
        uicontrol(handle, 'Style', 'pushbutton', 'String', 'Cancel', ...
                  'Position', [130 10 100 30], 'Tag', 'CancelBtn', ...
                  'Callback', @cancelbtn_callback);
    end

    function updateFdGraph
        % This function is called to actually update the F,d graph with the
        % currently selected range of data (taken from the global
        % "dataRangeSelected" variable).
        fd_trimmed = fd.fragment(dataRangeSelected(1), dataRangeSelected(2));
        hFd = findobj(hDlg, 'Tag', 'Plot.Fd');
        set(hFd, 'XData', fd_trimmed.d, 'YData', fd_trimmed.f);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function cursor_drag(hObj, event)
        cursorPos = sort(event.Positions)';

        iStart = find(cursorPos(1) >= fd.t, 1, 'last');
        if isempty(iStart)
            iStart = 1;
        end
        iEnd = find(cursorPos(2) <= fd.t, 1, 'first');
        if isempty(iEnd)
            iEnd = length(fd.t);
        end

        dataRangeSelected = [iStart iEnd];
        updateFdGraph;

        % Sync with cursors in other graph
        if hObj == cur1
            cur2.Positions = event.Positions;
        else
            cur1.Positions = event.Positions;
        end
    end

    function dlg_closerequest(hObj, event)      %#ok
        uiresume;
    end

    function dlg_keypress(hObj, event)          %#ok
        % Make "return" and escape close the dialog
        switch event.Key
            case 'return'
                okbtn_callback();
            case 'escape'
                cancelbtn_callback();
        end
    end

    function okbtn_callback(hObj, event)        %#ok
        close(hDlg);
    end

    function cancelbtn_callback(hObj, event)    %#ok
        fd_trimmed = fd;
        close(hDlg);
    end

end
