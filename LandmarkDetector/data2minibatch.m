%% This function splits the data into minibatches and detects the landmarks with a subfunction
%
%  Images(Height,Width,Channels,numImages)
%  BoundingBoxes(numFaces,1:3,numImages) = [X_min,Y_min,size];
%
function [landmarks,varargout] = data2minibatch(Images,BoundingBoxes,NumFaces,MiniBatchSize,MaxMinibatchSize,MaxNumImages,MaxNumFaces,ModelFitting,ShowResults)
    %% Initialization
    
    t1 = tic;
    
    persistent minibatch_size;
    persistent max_minibatch_size;
    persistent max_num_images;
    persistent max_num_faces;
    persistent model_fitting;
    persistent show_results;
    persistent image_size;
    persistent mb_images;
    persistent mb_bboxes;
    persistent landmarks_prev;
    persistent time_proc;
    persistent buf1_size;
    persistent buf1_imagesGray;
    persistent buf1_BBoxes;
    persistent buf1_numFaces;
    persistent buf1_indexPush;
    persistent buf1_indexPop;
    persistent buf1_numElem;
    persistent buf1_numFaces_sav;
    persistent buf1_indexPop_sav;
    persistent landmarks_tmp;
    
    % If this function is called the first time
    if isempty(max_minibatch_size)
        
        max_minibatch_size  = MaxMinibatchSize;
        max_num_images      = MaxNumImages;
        max_num_faces       = MaxNumFaces;
        image_size          = size(Images(:,:,1,1));
        mb_images           = zeros([image_size,max_minibatch_size],'uint8');
        mb_bboxes           = zeros(max_minibatch_size,3);
        landmarks_prev      = cell(0);
        time_proc           = 0;
        buf1_size           = max_num_images + max_minibatch_size - 1;
        buf1_imagesGray     = zeros([image_size,buf1_size],'uint8');
        buf1_BBoxes         = zeros(max_num_faces,3,buf1_size);
        buf1_numFaces       = zeros(1,buf1_size);
        buf1_indexPush      = 1;
        buf1_indexPop       = 1;
        buf1_numElem        = 0;
        landmarks_tmp       = zeros(68,2,buf1_size*max_num_faces);
        
        % Delete static variables of the function
        clear mb_detect_landmarks;
    end
    
    %% Input & Error handling
    
    % If we want to get the landmarks altough we have no full minibatch
    if nargin < 1
        FlushBuffer = true; 
    else
        FlushBuffer = false;
       
        minibatch_size   = MiniBatchSize;
        model_fitting    = ModelFitting;
        show_results     = ShowResults;
       
        if minibatch_size > max_minibatch_size
        	error('The minibatch size is greater than the maximum size!'); 
        end
       
       % If the image size has changed
        if size(Images(:,:,1,1)) ~= image_size
            error('It is not allowed to change the image size!');
        end
        
        % If the maximum minibatch size has changed
        if MaxMinibatchSize ~= max_minibatch_size
           error('It is not allowed to change the maximum minibatch size!'); 
        end
        
        % If the maximum number of images has changed
        if MaxNumImages ~= max_num_images
           error('It is not allowed to change the maximum number of images!'); 
        end
        
        % If the maximum number of faces per image has changed
        if MaxNumFaces ~= max_num_faces
           error('It is not allowed to change the maximum number of faces per image!'); 
        end
        
        % If there are too many input images
        if size(Images,4) > max_num_images
           error('There are too many input images!') 
        end
        
        % If there are too many faces
        if size(BoundingBoxes,1) > max_num_faces
           error('There are too many faces!'); 
        end
        
    end

    %% Input processing
    
    if FlushBuffer
        number_minibatches  = 1;
        number_proc_faces   = sum(buf1_numFaces);
    else
        % Convert all images to grayscale and copy bounding boxes into buffer
        for im = 1:size(Images,4)
            if size(Images,3) == 3
                buf1_imagesGray(:,:,buf1_indexPush) = rgb2gray(Images(:,:,:,im));  % Convert to grayscale
            else
                buf1_imagesGray(:,:,buf1_indexPush) = Images(:,:,:,im);
            end
            
            num_faces = NumFaces(im);
            buf1_numFaces(buf1_indexPush) = num_faces;

            % Copy all bounding boxes
            buf1_BBoxes(1:num_faces,:,buf1_indexPush) = BoundingBoxes(1:num_faces,:,im);

            buf1_indexPush  = mod(buf1_indexPush,buf1_size) + 1;
            buf1_numElem    = buf1_numElem + 1;
        end
        
        buf1_numFaces_sav = buf1_numFaces;
        buf1_indexPop_sav = buf1_indexPop;
        
        if buf1_numElem > buf1_size
           error('Buffer overflow!'); 
        end
        
        number_minibatches  = floor(sum(buf1_numFaces)/minibatch_size);
        number_proc_faces   = number_minibatches*minibatch_size;
    end
    
    %% Landmark detection

    number_out_imgs     = buf1_numElem;
    current_framerates  = zeros(max(number_minibatches,1),6);
                   
    index_start_tmp     = 1;
    cnt                 = 0;
    mb_cnt              = 0;
    mb                  = 1;
    pop_buf1            = true;
    
    % For all images
	for im = 1:buf1_numElem
        
        % If this image will not be processed
        if cnt > number_proc_faces
            break;
        end

        % For all detected faces of this image
        for fa = 1:buf1_numFaces(buf1_indexPop)
           cnt      = cnt + 1;
           mb_cnt   = mb_cnt + 1;

            % If this face will be processed
            if cnt <= number_proc_faces
               mb_images(:,:,mb_cnt) = buf1_imagesGray(:,:,buf1_indexPop);
               mb_bboxes(mb_cnt,:)   = buf1_BBoxes(fa,:,buf1_indexPop);

               % If we have a full minibatch
               if ~FlushBuffer && mb_cnt == minibatch_size
                   index_end_tmp = index_start_tmp + minibatch_size - 1;

                   % Detect landmarks
                   [landmarks_tmp(:,:,index_start_tmp:index_end_tmp),current_framerates(mb,:)] = mb_detect_landmarks(mb_images(:,:,1:minibatch_size),mb_bboxes(1:minibatch_size,:),model_fitting,show_results,max_minibatch_size);

                   index_start_tmp = index_end_tmp + 1;
                   mb_cnt = 0;
                   mb = mb + 1;
               % If we want to flush the buffer
               elseif FlushBuffer && mb_cnt == number_proc_faces
                   index_end_tmp = index_start_tmp + number_proc_faces - 1;

                   % Detect landmarks
                   [landmarks_tmp(:,:,index_start_tmp:index_end_tmp),current_framerates(mb,:)] = mb_detect_landmarks(mb_images(:,:,index_start_tmp:index_end_tmp),mb_bboxes(index_start_tmp:index_end_tmp,:),model_fitting,show_results,max_minibatch_size);
               end
               buf1_numFaces(buf1_indexPop) = buf1_numFaces(buf1_indexPop) - 1;

            % If this face will not be processed    
            else
               number_out_imgs	= im - 1;
               pop_buf1      	= false;

               % Copy all remaining faces of this image to the beginning
               num_faces = buf1_numFaces(buf1_indexPop);
               buf1_BBoxes(1:num_faces,:,buf1_indexPop) = buf1_BBoxes(fa:fa+num_faces-1,:,buf1_indexPop);

               break;
            end
        end
        if pop_buf1
            buf1_indexPop = mod(buf1_indexPop,buf1_size) + 1;
            buf1_numElem  = buf1_numElem - 1;
        end
	end
    
    if buf1_numElem < 0
       error('Buffer error!'); 
    end
    
    %% Copy landmarks into output variable
    
    index_tmp = 1;
    landmarks = cell(number_out_imgs,1);
    
    % For all images which were processed completely
    for im = 1:number_out_imgs
        number_bboxes = buf1_numFaces_sav(buf1_indexPop_sav);
        landmarks{im} = cell(number_bboxes,1);
        
        for fa = 1:number_bboxes
           landmarks{im}{fa} = landmarks_tmp(:,:,index_tmp);
           index_tmp = index_tmp + 1;
        end
        buf1_indexPop_sav = mod(buf1_indexPop_sav,buf1_size) + 1;
    end
    number_out_faces = index_tmp - 1;
    
    if number_out_imgs > 0
        landmarks{1} = [landmarks_prev;landmarks{1}];
    else
        landmarks = cell(0);
    end
    
    %% Save the remaining landmarks for the next function call
    
    number_landmarks_prev = number_proc_faces - number_out_faces;
    landmarks_prev_tmp = cell(number_landmarks_prev,1);
        
    for fa = 1:number_landmarks_prev
       landmarks_prev_tmp{fa} = landmarks_tmp(:,:,index_tmp);
       index_tmp = index_tmp + 1;
    end
    
    time_proc = time_proc + toc(t1);
    t = time_proc;
    
    if number_out_imgs > 0
        landmarks_prev = landmarks_prev_tmp;
        time_proc = 0;
    else
        landmarks_prev = [landmarks_prev;landmarks_prev_tmp];
    end
    
    %% Framerates as optional output argument

    if nargout == 2
        % If there are several minibatches
        if number_minibatches > 1
           current_framerates = mean(current_framerates); 
        end
        
        if number_out_imgs > 0
            current_framerates = current_framerates*number_out_imgs/number_out_faces;
        else
            current_framerates = current_framerates*0;
        end
        varargout{1} = [number_out_imgs/t,current_framerates]; % Samples/s: EntireFunction,TotalProcessing,Preprocessing,CNTK,LandmarkExtraction,ModelFitting,Postprocessing
    end
    
end