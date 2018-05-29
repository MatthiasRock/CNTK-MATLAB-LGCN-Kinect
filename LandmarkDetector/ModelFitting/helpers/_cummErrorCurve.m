function [x, y] = cummErrorCurve( errorVec )
%CUMMERRORCURVE Copyright by Zadeh et al.
% adapted by Daniel Merget based on https://github.com/A2Zadeh/CE-CLM
    spacing = 1e-5;       
    sampling = 0:spacing:1;

    x = sampling;
    y = zeros(numel(sampling,1));
  
    for i=1:numel(sampling)
        y(i) = sum(errorVec < sampling(i)) / numel(errorVec);
    end
end
