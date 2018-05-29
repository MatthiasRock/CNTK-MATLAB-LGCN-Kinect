%% This function performs the PCA model fitting
%
%  You should use MATLAB R2016b. All newer versions are MUCH slower due to a
%  different implementation of the function 'lsqlin'.
% 
function landmarks_final = pca_improve_landmarks(pred,landmarks)
    %% Parameters for model fitting
    
    % Add path
    CurrentPath       = mfilename('fullpath');
    [CurrentPath,~,~] = fileparts(CurrentPath);
    addpath(fullfile(CurrentPath,'helpers'));

    thresh                      = 0.1;      % Lower => consider more landmarks (depending on network certainty) for Kabsch alignment; should be between 0 and 1.
    nEVs                        = 12;       % Number of eigenvectors to consider for fitting
    window_sizes                = [20 7];  	% Local fit window sizes, empty vector to disable local fitting
    model_constraints           = true;    	% Constrain the fitting to "plausible" shapes according to the training set
    image_boundary_constraints  = false;    % Constrain the fitting to regions within the image boundary
    
    %% Load trained model
    
    % Static variables
    persistent SM;
    persistent mean_face;
    
    % If this function is called the first time
    if isempty(SM)
        load('trained_PCA_model','SM','mean_face');
        SM.n = nEVs;
        SM.mean_face = mean_face; % This is actually the same as SM.avg just in different format
    end

    %% Fit the model
    % Landmarks are only needed for Kabsch alignment, not for fitting
    landmarks_PCA = fit_compl(SM,pred,landmarks,window_sizes,model_constraints,image_boundary_constraints,thresh);
    
    %% Find nearest local maxima to the model predictions (within each heatmap)
    landmarks_local = zeros(size(landmarks));
    
    for lm = 1:size(landmarks,1)
       for im = 1:size(landmarks,3)
            [a,b]= ind2sub([size(pred,2),size(pred,1)],find(imregionalmax(squeeze(pred(:,:,lm,im)))));
            [~,closest] = min(bsxfun(@minus,landmarks_PCA(lm,1,im),a).^2+bsxfun(@minus,landmarks_PCA(lm,2,im),b).^2);
            landmarks_local(lm,1,im) = a(closest);
            landmarks_local(lm,2,im) = b(closest);
       end
    end

    %% Determine the final coordinates
    % Refine the local maxima to sub-pixel accuracy and determine the weighted
    % mean between model predictions and local maxima. The more certain the
    % network is, the more weight is put on the local maxima. The less certain
    % the network is, the more weight is put on the model fitting results.
    
    landmarks_final = zeros(size(landmarks));
    
    xlocal = squeeze(landmarks_local(:,1,:));
    ylocal = squeeze(landmarks_local(:,2,:));
    
    dxy = 2; % radius around the local maxima to consider in order to find sub-pixel maxima
    xtmp = permute(reshape(min(max(cell2mat(arrayfun(@(z) z-dxy:z+dxy,xlocal,'UniformOutput',false)),1),size(pred,2)),[size(landmarks,1),1+2*dxy,size(landmarks,3)]),[1,3,2]);
    ytmp = permute(reshape(min(max(cell2mat(arrayfun(@(z) z-dxy:z+dxy,ylocal,'UniformOutput',false)),1),size(pred,1)),[size(landmarks,1),1+2*dxy,size(landmarks,3)]),[1,3,2]);
    for lm = 1:size(landmarks,1)
       for im = 1:size(landmarks,3)
            w = pred(xlocal(lm,im),ylocal(lm,im),lm,im);
            landmarks_final(lm,1,im) = landmarks_PCA(lm,1,im).*(1-w) + w.*sum(sum(bsxfun(@times,squeeze(xtmp(lm,im,:)),sum1(diff1(pred(xtmp(lm,im,:),ytmp(lm,im,:),lm,im))))));
            landmarks_final(lm,2,im) = landmarks_PCA(lm,2,im).*(1-w) + w.*sum(sum(bsxfun(@times,squeeze(ytmp(lm,im,:)).',sum1(diff1(pred(xtmp(lm,im,:),ytmp(lm,im,:),lm,im))))));
        end
    end
    
end