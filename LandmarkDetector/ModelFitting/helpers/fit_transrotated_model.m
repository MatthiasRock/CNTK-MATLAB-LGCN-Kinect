function [landmarks] = fit_transrotated_model(ShapeModel, prediction, model_constraints, image_boundary_constraints, centroid, theta, eps)
%FIT_TRANSROTATED_MODEL returns landmarks after a single constrained model fitting
%the types of constraints to be used can be set
%the face centroid and tilt can be passed as arguments or estimated from the heatmaps

imgszx = size(prediction,1);
imgszy = size(prediction,2);
lmn = size(prediction,3);

prediction = squeeze(permute(prediction,[4,3,1,2])); % lmn y x
eps = 0.01;
n = ShapeModel.n;

% solve A*x=b, weighted by the heatmap pixel values, using the highest n
% components of the model.
% higher n means more accurate fitting but more noise as well

% the solution x are the coefficients for best fitting landmark coordinates
% applying the coefficients to the EVs yields the landmarks (x1,y1,...,xN,yN)

% weights:
w = repmat(prediction,[1,1,1,2]);
w = permute(w,[4,1,2,3]); % size == [2, lmn, x, y]
w = w(:);

%rotation matrix:
ROT = kron(eye(lmn),rotmat(theta));

% 2n equations per pixel:
A = repmat(ROT*ShapeModel.EVs(:,1:n),imgszx*imgszy,1);
A = bsxfun(@times,A,w);
A(w<=eps,:) = [];

average = bsxfun(@plus,reshape(ROT*tocol(bsxfun(@minus,reshape(ShapeModel.avg,2,lmn),centroid.')),2,lmn),centroid.');

% target values
[px,py] = ndgrid(1:imgszx,1:imgszy);
b = bsxfun(@minus,repmat([px(:).';py(:).'],lmn,1),average(:));

b = b(:).*w;
b(w<=eps) = [];

%% create & solve the system:
%constraints: (1) C*x <= d AND (2) F*x <= g

% (1) only allow landmark constraints that are true for all of the training data,
%for example, if x1 < x2 on all training images, enforce this during testing
C=[];
d=[];
if model_constraints
    ShapeModel.C = ShapeModel.C(ShapeModel.diffs>=1, :);

    C = ShapeModel.C*ShapeModel.EVs(:,1:n);
    d = -ShapeModel.C*(ShapeModel.avg.');
end

% (2) landmarks should be inside the picture:
%landmarks >= 0 and landmarks <= [imgszx, imgszy, imgszx, imgszy, ...]
%
%=> 
%center + ROT*(ShapeModel.avg.') + ROT*ShapeModel.EVs(:,1:n)*x >= 0   AND
%center + ROT*(ShapeModel.avg.') + ROT*ShapeModel.EVs(:,1:n)*x <= bound
%
%<=>
%-ROT*ShapeModel.EVs(:,1:n)*x <= center + ROT*(ShapeModel.avg.')   AND
%ROT*ShapeModel.EVs(:,1:n)*x <= bound -(center + ROT*(ShapeModel.avg.'))
F=[];
g=[];
if image_boundary_constraints
    bound = repmat([imgszx imgszy].', [lmn, 1]);
    F=[-ROT*ShapeModel.EVs(:,1:n); ROT*ShapeModel.EVs(:,1:n)];
    g = [average(:); bound - average(:)];
end

CF=[C;F];
dg=[d;g];

% constrained LLSQ fitting
options = optimoptions('lsqlin','Algorithm','interior-point');
% evalc to supress output
[~, x] = evalc('lsqlin(A,b,CF,dg,[],[],[],[],[],options);'); %#ok<*NASGU>


landmarks = average(:) + ROT*ShapeModel.EVs(:,1:n)*x;

end
