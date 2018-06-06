%% This function detects the landmarks of a minibatch of grayscale images
%
%  Images(Height,Width,numImages)
%
%  Recommended: MATLAB R2016b + CNTK 2.3.1
%
function [landmarks,framerates] = mb_detect_landmarks(Images,ModelFitting,MaxMinibatchSize)
    %% Initialization

    t1 = tic; 
    
    % Static variables
    persistent Device;
    persistent ModelPath;
    persistent ImgSize;
    persistent nLandmarks;
    persistent max_minibatch_size;
    persistent pred;
    
    % If this function is called the first time
    if isempty(Device)
        
        % You can change this
        Device = 'GPU';        % 'GPU' / 'CPU'
        
        % If you want to use a BrainScript model:
        %   The kernel must have the shape 45x45x1 and NOT 1x45x45, otherwise this will not work
        ModelFileName = 'model_128_filters.21';
        
        % Get absolute model file path
        CurrentPath         = mfilename('fullpath');
        [CurrentPath,~,~]   = fileparts(CurrentPath);
        AddPath             = fullfile(CurrentPath,'ModelFitting');
        addpath(AddPath);
        
        ModelPath           = fullfile(CurrentPath,ModelFileName);
        ImgSize           	= size(Images(:,:,1));
        nLandmarks          = 68;
        max_minibatch_size  = MaxMinibatchSize;
        pred                = zeros([ImgSize,nLandmarks,max_minibatch_size]);
    end
    
    % If the maximum minibatch size has changed
    if MaxMinibatchSize ~= max_minibatch_size
        max_minibatch_size  = MaxMinibatchSize;
        pred                = zeros([ImgSize,nLandmarks,max_minibatch_size]);
    end
    
    minibatch_size = size(Images,3);

    %% Heatmap creation with CNTK

    t2 = tic;
    pred(:,:,:,1:minibatch_size) = EvaluationMex(Images,ModelPath,Device); % 96x96x68xMB
    
    t = toc(t2);
    framerates(2) = minibatch_size/t;
    
    %% Landmark Extraction
    
    pred(pred<0) = 0;
    
    landmarks = zeros(nLandmarks,2,minibatch_size);

    % Compute global maximum per heatmap (no sub-pixel accuracy!)
    for im = 1:minibatch_size
       for lm = 1:nLandmarks
           [~,maxpos]   = max(reshape(pred(:,:,lm,im),[],1));
           [xmax, ymax] = ind2sub(ImgSize,maxpos);
           landmarks(lm,:,im) = [xmax, ymax];
       end
    end
    
    %% Landmark refinement
    
    % Perform PCA based model fitting
    if ModelFitting
        landmarks = pca_improve_landmarks(pred(:,:,:,1:minibatch_size),landmarks);
    end
    
    t = toc(t1);
    framerates(1) = minibatch_size/t;
    
end