classdef cursorsData < event.EventData
  properties
    Positions;
  end
  methods
    function this = cursorsData(positions)
      this.Positions = positions;
    end
  end
end