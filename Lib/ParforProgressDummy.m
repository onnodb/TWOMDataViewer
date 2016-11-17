classdef ParforProgressDummy < handle
    % Simple dummy class to replace the ParforProgress library, if this library
    % is not currently installed.
    properties
        ticId = []
    end

    methods
        function [obj] = ParforProgressDummy(msg, n)
            fprintf('%s (item count: %d)\n', msg, n);
            obj.ticId = tic;
        end

        function delete(self)
            toc(self.ticId)
        end

        function increment(~, ~)
            % Do nothing
        end
    end
end
