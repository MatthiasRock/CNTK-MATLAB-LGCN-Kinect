%% This function detects the landmarks of a minibatch of grayscale images
%
%  Images(Height,Width,numImages)
%  BBoxes(numImages,1:3) = [X_min,Y_min,size];
%
%  Recommended: MATLAB R2016b + CNTK 2.3.1
%
function [landmarks,varargout] = mb_detect_landmarks(Images,BBoxes,ModelFitting,ShowResults,MaxMinibatchSize)
    %% Initialization

    t1 = tic;
    
    % Static variables
    persistent PrintFramerate;
    persistent Device;
    persistent ModelPath;
    persistent ImgResizeTo;
    persistent nLandmarks;
    persistent default_padding;
    persistent grey_color;
    persistent padded_image;
    persistent number_all_samples;
    persistent time_all_samples;
    persistent current_framerates;
    persistent max_minibatch_size;
    persistent images_processed;
    persistent bbox_min;
    persistent bbox_max;
    persistent padding_pre;
    persistent padding_post;
    persistent img_size_padded;
    persistent scale_factor;
    persistent pred;
    persistent image_size;
    
    % If this function is called the first time
    if isempty(Device)
        
        % You can change this
        PrintFramerate  = true;
        Device          = 'GPU';        % 'GPU' / 'CPU'
        
        % If you want to use a BrainScript model:
        %   The kernel must have the shape 45x45x1 and NOT 1x45x45, otherwise this will not work
        ModelFileName   = 'model_128_filters.21';
        
        % Get absolute model file path
        CurrentPath         = mfilename('fullpath');
        [CurrentPath,~,~]   = fileparts(CurrentPath);
        AddPath             = fullfile(CurrentPath,'ModelFitting');
        addpath(AddPath);
        
        ModelPath           = fullfile(CurrentPath,ModelFileName);
        ImgResizeTo         = [96 96];  % Height and width must be the same
        nLandmarks          = 68;
        default_padding     = 200;
        grey_color          = 127;
        image_size          = size(Images(:,:,1));
        padded_image        = grey_color*ones([image_size+2*default_padding,1],'uint8');
        number_all_samples 	= 0;
        time_all_samples	= zeros(1,6);
        current_framerates  = zeros(1,6);
        max_minibatch_size  = MaxMinibatchSize;
        images_processed    = zeros([ImgResizeTo,max_minibatch_size],'uint8');
        bbox_min            = zeros(max_minibatch_size,2);
        bbox_max            = zeros(max_minibatch_size,2);
        padding_pre         = zeros(max_minibatch_size,2);
        padding_post        = zeros(max_minibatch_size,2);
        img_size_padded     = zeros(max_minibatch_size,2);
        scale_factor        = zeros(max_minibatch_size);
        pred                = zeros([ImgResizeTo,nLandmarks,max_minibatch_size]);
    end
    
    % If the image size has changed
    if size(Images(:,:,1)) ~= image_size
        image_size    	= size(Images(:,:,1));
        padded_image	= grey_color*ones([image_size+2*default_padding,1],'uint8');
    end
    
    % If the maximum minibatch size has changed
    if MaxMinibatchSize ~= max_minibatch_size
        max_minibatch_size  = MaxMinibatchSize;
        images_processed    = zeros([ImgResizeTo,max_minibatch_size],'uint8');
        bbox_min            = zeros(max_minibatch_size,2);
        bbox_max            = zeros(max_minibatch_size,2);
        padding_pre         = zeros(max_minibatch_size,2);
        padding_post        = zeros(max_minibatch_size,2);
        img_size_padded     = zeros(max_minibatch_size,2);
        scale_factor        = zeros(max_minibatch_size);
        pred                = zeros([ImgResizeTo,nLandmarks,max_minibatch_size]);
    end

    %% Input handling
    
    if size(Images,3) < 1
       error('Wrong input image format!')
    end
    if ~isa(Images,'uint8')
       error('This is not a 8 bit image!') 
    end

    if nargin > 1
        if size(BBoxes,2) ~= 3
           error('The second dimension of "BBoxes" must consist of 3 elements (x,y,size)!') 
        end    
        if size(Images,3) ~= size(BBoxes,1)
           error('You must provide a bounding box for each image!') 
        end
    else
        if size(Images,1) ~= size(Images,2)
           error('Height and width of the image must be the same when no bounding boxes are provided!') 
        end
        BBoxes = false;
    end

    %% Preprocessing

    t2 = tic;
    
    minibatch_size = size(Images,3);
    
    if minibatch_size > MaxMinibatchSize
       error('The minibatch size is greater than the maximum size!'); 
    end
    
    bbox_min(1:minibatch_size,:) = BBoxes(:,1:2);
    bbox_max(1:minibatch_size,:) = BBoxes(:,1:2) + BBoxes(:,3);
    
    % Grey padding
    padding_pre     = max(0,1 - bbox_min);
    padding_post  	= max(0,bbox_max - flip(image_size));
    
    bbox_min        = bbox_min + padding_pre;
    bbox_max        = bbox_max + padding_pre;
    
    img_size_padded = padding_pre + padding_post + flip(image_size);
    scale_factor    = (bbox_max(:,2) - bbox_min(:,2) + 1)/ImgResizeTo(1);

    % Crop and resize all images
    for k = 1:minibatch_size
        
        % If the default array for the padded image is too small
        if img_size_padded > flip(size(padded_image))
           padded_image = grey_color*ones(img_size_padded(2),img_size_padded(1),1,'uint8'); 
        end
        
        % Grey padding of the image
        padded_image(padding_pre(k,2)+1:img_size_padded(k,2)-padding_post(k,2),padding_pre(k,1)+1:img_size_padded(k,1)-padding_post(k,1),:) = Images(:,:,k);

        % Crop and scale image
        images_processed(:,:,k) = imresize(padded_image(bbox_min(k,2):bbox_max(k,2),bbox_min(k,1):bbox_max(k,1),:),ImgResizeTo);
    end
    
    t = toc(t2);
    current_framerates(2) = minibatch_size/t;
    time_all_samples(2)   = time_all_samples(2) + t;

    %% Heatmap creation with CNTK

    t3 =  tic;
    pred(:,:,:,1:minibatch_size) = EvaluationMex(images_processed(:,:,1:minibatch_size),ModelPath,Device); % 96x96x68xMB
    
    t = toc(t3);
    current_framerates(3) = minibatch_size/t;
    time_all_samples(3)   = time_all_samples(3) + t;
    
    %% Landmark Extraction
    
    t4 = tic;
    
    pred(pred<0) = 0;
    
    landmarks = zeros(nLandmarks,2,minibatch_size);

    % Compute global maximum per heatmap (no sub-pixel accuracy!)
    for im = 1:minibatch_size
       for lm = 1:nLandmarks
           [~,maxpos]   = max(reshape(pred(:,:,lm,im),[],1));
           [xmax, ymax] = ind2sub(ImgResizeTo,maxpos);
           landmarks(lm,:,im) = [xmax, ymax];
           
           % Show heatmap with detected landmark
           %imshow(fliplr(imrotate(pred(:,:,lm,im),-90))); hold on; plot(xmax,ymax,'-r*'); hold off;waitforbuttonpress;
       end
    end
    
    t = toc(t4);
    current_framerates(4) = minibatch_size/t;
    time_all_samples(4)   = time_all_samples(4) + t;
    
    % Plot cropped images with landmarks
    %for im = 1:minibatch_size
    %   imshow(images_processed(:,:,im)); hold on; scatter(landmarks(:,1,im),landmarks(:,2,im),'r','*'); hold off; waitforbuttonpress;
    %end
    
    %% Landmark refinement
    
    t5 = tic;
    
    % Perform PCA based model fitting
    if ModelFitting
        landmarks = pca_improve_landmarks(pred(:,:,:,1:minibatch_size),landmarks);
    end
    
    t = toc(t5);
    current_framerates(5) = minibatch_size/t;
    time_all_samples(5)   = time_all_samples(5) + t;

    %% Postprocessing
    
    t6 = tic;

    for k = 1:minibatch_size
        landmarks(:,:,k) = landmarks(:,:,k)*scale_factor(k) - padding_pre(k,:) + bbox_min(k,:) - 1;
    end
    
    t = toc(t6);
    current_framerates(6) = minibatch_size/t;
    time_all_samples(6)   = time_all_samples(6) + t;
    
    % Plot original images with landmarks
    if ShowResults
        for im = 1:minibatch_size
           imshow(Images(:,:,im)); hold on; scatter(landmarks(:,1,im),landmarks(:,2,im),'r','*'); hold off; waitforbuttonpress;
        end
    end
    
    %% Print speed
    
    t = toc(t1);
    current_framerates(1) = minibatch_size/t;
    time_all_samples(1)   = time_all_samples(1) + t;
    
    if PrintFramerate
        number_all_samples  = number_all_samples + minibatch_size;

        fprintf('Total number of samples: %d\n', number_all_samples);
        fprintf('Total processing:        %.2f Samples/s\n', number_all_samples/time_all_samples(1));
        fprintf('Preprocessing:           %.2f Samples/s\n', number_all_samples/time_all_samples(2));
        fprintf('CNTK:                    %.2f Samples/s\n', number_all_samples/time_all_samples(3));
        fprintf('Landmark extraction:     %.2f Samples/s\n', number_all_samples/time_all_samples(4));
        
        if ModelFitting
            fprintf('Model fitting:           %.2f Samples/s\n', number_all_samples/time_all_samples(5));
        end
        
        fprintf('Postprocessing:          %.2f Samples/s\n\n', number_all_samples/time_all_samples(6));
    end
    
    %% Framerates as optional output argument
    if nargout == 2
       varargout{1} = current_framerates; 
    end
    
end