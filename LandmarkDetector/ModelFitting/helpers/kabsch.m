function [theta,t] = kabsch(A, B)
% Simple implementation of the Kabsch algorithm without reflection detection
% Finds the rotation angle and translation vector between two 2D point sets
% Input dimension: N x 2
    assert(all(size(A) == size(B)) && size(A,2) == 2)

    meanA = mean(A);
    meanB = mean(B);
    
    [U,~,V] = svd(bsxfun(@minus,A,meanA).' * bsxfun(@minus,B,meanB));

    % rotation matrix (2x2)
    R = V*U';
    
    % rotation angle (1x1)
    theta = asind(R(2,1));
    
    % translation vector (2x1)
    t = -R*meanA.' + meanB.';
end
