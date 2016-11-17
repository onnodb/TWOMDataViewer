classdef cursors < handle
  % CURSORS - Cursor object for MATLAB graphics
  %-----------------------------------------------------------------------------
  % File name  : cursors.m
  % Created on : 16-Jan-2009
  % Description: Cursor object for MATLAB graphics
  %
  % Copyright 2008-2009 T. Montagnon
  %-----------------------------------------------------------------------------
  %
  
  properties
    HdlAxes              = []; % HG of the axes on which the cursors are plotted
    FcnPostAction        = []; % Function executed when the cursor stops movings
  end
  
  properties (Access = private)
    HdlFig                = []; % HG of the figure containing the axes
    HdlCursors            = []; % HG of the cursors
    HdlCurrentCursor      = []; % HG of the currently selected cursor
    FcnWindowButtonMotion = []; % Stores the WindowButtonMotionFcn callback set for the figure before modifying it for cursor motion control
    FcnWindowButtonUpFcn  = []; % Stores the WindowButtonUpFcn callback set for the figure before modifying it for cursor motion control
    InitialYLim           = []; % Stores the YLim property of the axe where the cursor is added in order to update the height of the cursor lines accordingly
  end
  
  properties (Access = private)
    CursorPositions  = [];  % Position of the cursors
    CursorColor      = 'r'; % Color of the cursors
  end
  
  
  properties (Dependent = true)
    Positions
    Color
  end
  
  properties (Constant)
    CursorHotSpot = [8 8]; % Hot spot position for the cursor icon
    CursorPointer = [ ...  % Cursor icon definition
      NaN NaN NaN NaN NaN   2   2   2   2   2 NaN NaN NaN NaN NaN NaN
      NaN NaN NaN NaN NaN   2   1   2   1   2 NaN NaN NaN NaN NaN NaN
      NaN NaN NaN NaN NaN   2   1   2   1   2 NaN NaN NaN NaN NaN NaN
      NaN NaN NaN NaN   2   2   1   2   1   2   2 NaN NaN NaN NaN NaN
      NaN NaN NaN   2   1   2   1   2   1   2   1   2 NaN NaN NaN NaN
      NaN NaN   2   1   1   2   1   2   1   2   1   1   2 NaN NaN NaN
      NaN   2   1   1   1   1   1   2   1   1   1   1   1   2 NaN NaN
        2   1   1   1   1   1   1   2   1   1   1   1   1   1   2 NaN
      NaN   2   1   1   1   1   1   2   1   1   1   1   1   2 NaN NaN
      NaN NaN   2   1   1   2   1   2   1   2   1   1   2 NaN NaN NaN
      NaN NaN NaN   2   1   2   1   2   1   2   1   2 NaN NaN NaN NaN
      NaN NaN NaN NaN   2   2   1   2   1   2   2 NaN NaN NaN NaN NaN
      NaN NaN NaN NaN NaN   2   1   2   1   2 NaN NaN NaN NaN NaN NaN
      NaN NaN NaN NaN NaN   2   1   2   1   2 NaN NaN NaN NaN NaN NaN
      NaN NaN NaN NaN NaN   2   2   2   2   2 NaN NaN NaN NaN NaN NaN
      NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN NaN
      ];
  end
  
  events
    onStartDrag % Event notified when the user click on a cursor line
    onDrag      % Event notified as the user drag the cursor line over the axe
    onReleased  % Event notified when the user release the cursor line
  end
  
  methods
    
    function this = cursors(HdlAxes,color)
      % Create a CURSORS object attached to the HDLAXES axes with the color COLOR
      
      this.HdlAxes     = HdlAxes;
      this.HdlFig      = ancestor(this.HdlAxes,'figure');
      this.CursorColor       = color;
      this.InitialYLim = ylim(this.HdlAxes);
      
    end
    
    function add(this,pos)
      % Add a cursor to the referenced axes at the specified position POS

      % Check input to define default cursor position
      if ~nargin
        this.CursorPositions(end+1) = diff(xlim(axeH)) / 2;
      else
        this.CursorPositions(end+1) = pos;
      end
      
      % Get axes limits
      yLim2 = ylim(this.HdlAxes);
      
      % Create Cursor Line
      this.HdlCursors(end+1) = line( ...
        [this.CursorPositions(end) this.CursorPositions(end)], ...
        yLim2, ...
        'Color',this.CursorColor, ...
        'LineWidth',2, ...
        'Parent',this.HdlAxes);
      
      % Set the WindowButtonDownFcn
      set(this.HdlCursors(end),'ButtonDownFcn',@this.ButtonDownFcn)
      
      % Call the action function with all cursor positions
      if length(this.HdlCursors) > 1
        notify(this,'onDrag',cursorsData(this.CursorPositions));
      end
      
    end
    
    function remove(this,idxCursor)
      % Remove the specified IDXCURSOR cursor
      % IDXCURSOR is the position of the cursor list HdlCursors
      % To find the IDXCURSOR based on the position of the cursor you can run
      % the following command:
      % >> idxCursor = find(cursor.Positions == myValue)
      
      % Execute only if there is a cursor
      if ~isempty(this.HdlCursors)
        
        if ~isempty(idxCursor)
          
          if isnumeric(idxCursor)
            ind2del = idxCursor;
            ind2del(ind2del>length(this.HdlCursors)) = []; % Remove indices outside the range
            ind2del(ind2del<1) = []; % Remove indices outside the range
          end
          
          % Delete specified cursor and associated label
          delete(this.HdlCursors(ind2del));
          
          % Remove cursor and label handles from vectors
          this.HdlCursors(ind2del) = [];
          
          % Remove position of the deleted cursor
          this.CursorPositions(ind2del) = [];
          
        else
          
          % Remove all cursors and all associated labels
          delete(this.HdlCursors);
          
          % Remove cursor and label handles from vectors
          this.HdlCursors = [];
          
          % Remove position of the deleted cursors
          this.CursorPositions = [];
          
        end
        
      end
      
    end
    
  end
  
  methods
    
    function set.Positions(this,value)
      
      % If last element of VALUE is NaN then do not notify events
      if isnan(value(end))
        notifyEvents = false;
        value(end) = [];
      else
        notifyEvents = true;
      end
        
      
      % Throw error if value isn't the same size as this.CursorPositions
      if length(value) ~= length(this.CursorPositions)
        error('cursors:setPositions:dimensionsMismatch','The value of the Positions property must have the same length as the Positions vector');
      end
      
      % Look for modified positions
      idxChange = find(~ismember(this.CursorPositions,value));
      idxValue  = find(~ismember(value,this.CursorPositions));
      
      % Update graphic if needed
      if ~isempty(idxChange)
        
        for ind=1:length(idxChange)
          
          % New position
          newPos = value(idxValue(ind));
          
          % Get axes limits
          yLim2 = ylim(this.HdlAxes);
          
          % Update cursor position
          set(this.HdlCursors(idxChange(ind)),'XData',[newPos newPos],'YData',[min(this.InitialYLim(1),yLim2(1)) max(this.InitialYLim(2),yLim2(2))]);
          
          % Stores the position of the cursor
          this.CursorPositions(idxChange(ind)) = newPos;
          
        end
        
        % Move the cursor on top of all other objects
        uistack(this.HdlCursors,'top');
        
        % Call the action function with all cursor positions
        if notifyEvents
          notify(this,'onDrag',cursorsData(this.CursorPositions));
          notify(this,'onReleased',cursorsData(this.CursorPositions));
        end
        
        % Refresh Display
        drawnow;
        
      end
      
    end
    function value = get.Positions(this)
      value = this.CursorPositions;
    end
    
    function set.Color(this,value)
      
      % Update property
      this.CursorColor = value;
      
      % Update cursors color
      set(this.HdlCursors,'Color',this.CursorColor)
      
    end
    function value = get.Color(this)
      value = this.CursorColor;
    end
    
  end
  
  
  methods
    
    function ButtonDownFcn(this,varargin)
      % Cursor ButtonDownFcn callback used to start the dragging mode
      
      % Update current cursor handle
      this.HdlCurrentCursor = varargin{1};
      
      if ~isempty(this.HdlCurrentCursor)
        
        % Change cursor pointer
        set(this.HdlFig,'Pointer','custom','PointerShapeCData',this.CursorPointer,'PointerShapeHotSpot',this.CursorHotSpot)
        
        % Update EraseMode property for the current Cursor
        set(this.HdlCurrentCursor,'EraseMode','xor')
        
        % Stores the current WindowButtonMotionFcn callback
        this.FcnWindowButtonMotion = get(this.HdlFig,'WindowButtonMotionFcn');
        this.FcnWindowButtonUpFcn  = get(this.HdlFig,'WindowButtonUpFcn');
        
        % Update figure callbacks
        set(this.HdlFig,'WindowButtonMotionFcn',@this.ButtonMotionFcn)
        set(this.HdlFig,'WindowButtonUpFcn',@this.ButtonUpFcn)
        
        % Notify the onStartDrag event
        notify(this,'onStartDrag',cursorsData(this.CursorPositions));
        
      end
      
    end
    
    function ButtonUpFcn(this,varargin)
      % Cursor ButtonUpFcn callback used to exit the dragging mode
      
      % Change cursor pointer
      set(this.HdlFig,'Pointer','arrow')
      
      % Update EraseMode property for the current Cursor
      set(this.HdlCurrentCursor,'EraseMode','normal')
      
      % Update Figure Callbacks
      set(this.HdlFig,'WindowButtonMotionFcn',this.FcnWindowButtonMotion)
      
      % Unset current Cursor and label
      this.HdlCurrentCursor = [];
      
      % Execute the post action function
      notify(this,'onReleased',cursorsData(this.CursorPositions));
      
      % Move the cursor on top of all other objects
      uistack(this.HdlCursors,'top');
      
    end
    
    function ButtonMotionFcn(this,varargin)
      % Figure WindowButtonMotionFcn used to handle the cursor dragging effects
      
      % Get current point
      curP = get(this.HdlAxes,'CurrentPoint');
      
      % Get axes limits
      yLim2 = ylim(this.HdlAxes);
      xLim2 = xlim(this.HdlAxes);
      
      % Make sure the cursor is not moving outside the axes
      curP(1) = min(curP(1),xLim2(2));
      curP(1) = max(curP(1),xLim2(1));
      
      % Update cursor position
      set(this.HdlCurrentCursor,'XData',[curP(1) curP(1)],'YData',[min(this.InitialYLim(1),yLim2(1)) max(this.InitialYLim(2),yLim2(2))]);
      
      % Stores the position of the cursor
      this.CursorPositions(this.HdlCursors == this.HdlCurrentCursor) = curP(1);
      
      % Call the action function with all cursor positions
      notify(this,'onDrag',cursorsData(this.CursorPositions));
      
      % Refresh Display
      drawnow;
      
    end
    
  end
  
end