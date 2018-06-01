%% This function processes the Kinect frames with CNTK and shows the landmarks etc...
%
% See README.txt
%
function main(Handles)
%% Initialization

    % You can change this
    MiniBatchSize       = 3;      	% Minibatch size for landmark detection with CNTK
  	bbox_scale_factor   = 1.17;     % Scale factor of Kinect tight bounding box
    ModelFitting        = false;
    ShowLandmarks       = true;
    ShowKinectLMs       = false;
    ShowFramerate       = true;
    ShowBoundingBoxes   = true;
    
    % If this function is not called from the GUI
    if nargin == 0
        Handle_Figure   = figure;
        Handle_Axes     = axes;
        
        setappdata(Handle_Figure,'enable_ModelFitting',ModelFitting);
        setappdata(Handle_Figure,'show_Landmarks',ShowLandmarks);
        setappdata(Handle_Figure,'show_KinLandmarks',ShowKinectLMs);
        setappdata(Handle_Figure,'show_framerates',ShowFramerate);
        setappdata(Handle_Figure,'show_BoundingBoxes',ShowBoundingBoxes);
        setappdata(Handle_Figure,'bboxes_ScaleFactor',bbox_scale_factor);
        setappdata(Handle_Figure,'minibatchSize',MiniBatchSize);
        MaxMinibatchSize = MiniBatchSize;
        
        % Figure initialization
        set(Handle_Axes,'Unit','normalized','Position',[0 0 1 1]);            % Set the axes to full screen
        set(Handle_Figure,'menubar','none');                                  % Hide the toolbar
        set(Handle_Figure,'NumberTitle','off');                               % Hide the title

    % If this function is called from the GUI
    else
        Handle_Figure   = Handles.figure1;
        Handle_Axes     = Handles.axes1;
        
        MaxMinibatchSize = getappdata(Handle_Figure,'MaxMinibatchSize');
    end
  
    addpath('Kin2_toolbox');
    addpath('./../LandmarkDetector');
        
 	% Delete static variables of the subfunction
  	clear data2minibatch;
    
    % Get the indices of the most relevant kinect landmarks
    %load('kinect_relevant_LMs.mat');
    %relevant_LMs = sort([kinect_ginline,kinect_lefteye,kinect_righteye,kinect_lefteyebrow,kinect_righteyebrow,kinect_mouth,kinect_nose])';
    
    % Create Kinect 2 object and initialize it
    k2 = Kin2('color','HDface');
    
    img_size        = [1080,1920,3];
    max_numFaces    = 6;
    init_numImages  = 2*MaxMinibatchSize;
    
    buf_size        = 2*MaxMinibatchSize;
    buf1_img        = zeros([img_size,buf_size],'uint8');
    buf1_imgGray    = zeros([img_size(1),img_size(2),1,buf_size],'uint8');
    buf1_imgInfo    = zeros(buf_size,1,'uint8');
    buf1_bboxes     = zeros(max_numFaces,3,buf_size);
    buf1_numFaces   = zeros(1,buf_size);
    buf1_kinFaces   = cell(buf_size,1);
    buf1_time       = zeros(1,buf_size,'uint64');
    buf1_indexPush  = 1;
    buf1_indexPop   = 1;
    buf1_numElem    = 0;
    
    buf2_landmarks  = cell(buf_size,1);
    buf2_indexPush  = 1;
    buf2_indexPop   = 1;
    buf2_numElem    = 0;
    
    numberFrames    = 1;
    iteration       = 1;
    noface_inTurn   = 0;
    faceImg_inProg  = 0;
    
    framerate_EntireFunction  = 0;
    framerate_TotalProcessing = 0;
    framerate_CNTK            = 0;
    framerate_current         = 0;
    frames_per_time           = 0;
    
    %% Figure initialization
    
    c.im = imshow(255*ones(img_size,'uint8'),'Parent',Handle_Axes);
    
    % Figure initialization
    set(Handle_Figure,'units','normalized','outerposition',[0 0 1 1]);    % Set the figure to full screen
    
    info_initText   = text(Handle_Axes,img_size(2)/2,img_size(1)/2,'Initializing...','FontSize',25,'HorizontalAlignment','center','VerticalAlignment','middle');
    info_framerates = text(Handle_Axes,10,10,'','FontSize',20,'Color','yellow','HorizontalAlignment','left','VerticalAlignment','top');
    
    % Initialize bounding boxes
    h_rect          = cell(1,max_numFaces);
    h_landmarksKin  = cell(1,max_numFaces);
    h_landmarks     = cell(1,max_numFaces);
    
    for fa = 1:max_numFaces
        h_rect{fa} = rectangle(Handle_Axes,'Position',[0,0,0,0],'EdgeColor','y','LineWidth',4);
        hold(Handle_Axes,'on')
        h_landmarksKin{fa}  = plot(Handle_Axes,0,0,'y.');
        h_landmarks{fa}     = plot(Handle_Axes,0,0,'r*');
        hold(Handle_Axes,'off')
    end

    %% Load a test image (multiple times) into the buffer to run the first two minibatches with CNTK in the background
    
    minibatch_size = MaxMinibatchSize;
    
    load('test_img.mat');
    
    % Copy data into buffer
    for im = 1:init_numImages
       	buf1_img(:,:,:,buf1_indexPush)      = test_img;
        buf1_imgGray(:,:,:,buf1_indexPush)  = rgb2gray(test_img);
        buf1_bboxes(1,:,buf1_indexPush)     = test_bbox;
        buf1_imgInfo(buf1_indexPush)        = 1;
    	buf1_numFaces(buf1_indexPush)       = 1;
        buf1_time(buf1_indexPush)           = tic;
        
        buf1_indexPush  = mod(buf1_indexPush,buf_size) + 1;
     	buf1_numElem  	= buf1_numElem + 1; 
    end
    
    %%
    
    % Get the current parallel pool
    p = gcp();
    
    t1 = tic;
    t2 = t1;

    while isvalid(Handle_Figure)
        %% Framerate
        
        % Determine the framerate over the last 1 second
        if toc(t1) >= 1
            framerate_current	= frames_per_time/toc(t1);
            frames_per_time     = 0;
            t1                  = tic;
        end
        
        % Determine if the current frame from the kinect shall be processed
        if toc(t2) >= 0.8/(framerate_current+1)
            t2 = tic;
            process_frame = true;
        else
            process_frame = false;
        end
        
        %% Fill buffer with data
        
        if buf1_numElem < 2*minibatch_size && process_frame
            
            % Until a valid frame was acquired
            while ~k2.updateData, end
        
            % Get current frame
            image = k2.getColor;

            % Store current frame in buffer
            buf1_img(:,:,:,buf1_indexPush)      = image;
            buf1_imgGray(:,:,:,buf1_indexPush)  = rgb2gray(image);

            % Get the HDfaces data
            faces = k2.getHDFaces('WithVertices','true'); 

            buf1_time(buf1_indexPush) = tic;
            j = 0;
                
            % For all faces
            for fa = 1:size(faces,2)

                % If the size of the bounding box is zero
                if faces(fa).FaceBox(3)-faces(fa).FaceBox(1) == 0 || faces(fa).FaceBox(4)-faces(fa).FaceBox(2) == 0
                    continue;
                end
                j = j + 1;

                buf1_kinFaces{buf1_indexPush}(j) = faces(fa);

                % Determine tight bounding box of the face
                bbox_tight_min  = [faces(fa).FaceBox(1),faces(fa).FaceBox(2)];
                bbox_tight_max  = [faces(fa).FaceBox(3),faces(fa).FaceBox(4)];
                bbox_tight_size = bbox_tight_max - bbox_tight_min;

                % Get squared scaled bounding box
                bbox_center     = (bbox_tight_min + bbox_tight_max)/2;
                bbox_size       = ceil(getappdata(Handle_Figure,'bboxes_ScaleFactor')*max(bbox_tight_size));
                bbox_size_half  = bbox_size/2;
                bbox_min        = floor(bbox_center - bbox_size_half);

                buf1_bboxes(j,:,buf1_indexPush) = [bbox_min,bbox_size];
            end

            numFaces = j;

            % If there is no face
            if numFaces < 1
                buf1_imgInfo(buf1_indexPush)  = 0;
                buf1_numFaces(buf1_indexPush) = 0;

                noface_inTurn = noface_inTurn + 1;

            % If at least one face was detected
            else
                buf1_imgInfo(buf1_indexPush)  = 1;
                buf1_numFaces(buf1_indexPush) = numFaces;

                noface_inTurn = 0;
            end

            buf1_indexPush  = mod(buf1_indexPush,buf_size) + 1;
            buf1_numElem  	= buf1_numElem + 1;        
        end
        
        %% Extract landmarks
        
        % Get the indices of all unprocessed images with a face
        index_ImgWithFace = find(buf1_imgInfo);
        index_ImgWithFace = [index_ImgWithFace(index_ImgWithFace >= buf1_indexPop);index_ImgWithFace(index_ImgWithFace < buf1_indexPop)];
        
        % If the function 'data2minibatch' was called before
        if exist('F','var')
            % If the last detection has finished
            if strcmp(F.State,'finished')
                % If these data were not read before
                if ~F.Read
                    [landmarks,current_framerates] = fetchOutputs(F);
                    numImages = size(landmarks,1);
                    
                    if current_framerates(1) ~= 0
                        framerate_EntireFunction = current_framerates(1);
                    end
                    if current_framerates(2) ~= 0
                        framerate_TotalProcessing = current_framerates(2);
                    end
                    if current_framerates(4) ~= 0
                        framerate_CNTK = current_framerates(4);
                    end

                    % Copy landmarks of the images into buffer
                    for k = 1:numImages
                        buf2_landmarks(buf2_indexPush) = landmarks(k);
                        buf2_indexPush = mod(buf2_indexPush,buf_size) + 1;
                    end
                    buf2_numElem   = buf2_numElem + numImages;
                    faceImg_inProg = faceImg_inProg - numImages;
                    
                    minibatch_size = getappdata(Handle_Figure,'minibatchSize');
                end
                
                % If there is an image in the buffer with a face
                if ~isempty(index_ImgWithFace)
                    F = parfeval(p,@data2minibatch,2,buf1_imgGray(:,:,:,index_ImgWithFace),buf1_bboxes(:,:,index_ImgWithFace),buf1_numFaces(index_ImgWithFace),minibatch_size,MaxMinibatchSize,buf_size,max_numFaces,getappdata(Handle_Figure,'enable_ModelFitting'),false);
                    buf1_imgInfo(index_ImgWithFace) = 0;
                    faceImg_inProg = faceImg_inProg + numel(index_ImgWithFace);
                % If there are now several noface images in turn (avoids blocking)
                elseif faceImg_inProg > 0 && (noface_inTurn > 5 || (buf1_numElem == 2*minibatch_size && sum(buf1_numFaces) < minibatch_size))
                    F = parfeval(p,@data2minibatch,2);  % Fetch remaining data
                end
            end
        % If the function 'data2minibatch' was not called before
        else
            % If there is an image in the buffer with a face
            if ~isempty(index_ImgWithFace)
                F = parfeval(p,@data2minibatch,2,buf1_imgGray(:,:,:,index_ImgWithFace),buf1_bboxes(:,:,index_ImgWithFace),buf1_numFaces(index_ImgWithFace),minibatch_size,MaxMinibatchSize,buf_size,max_numFaces,getappdata(Handle_Figure,'enable_ModelFitting') ,false);
                buf1_imgInfo(index_ImgWithFace) = 0;
                faceImg_inProg = faceImg_inProg + numel(index_ImgWithFace);
            end
        end

        %% Show output
        
        % If a face was detected on the current buffered frame
        if buf1_numElem > 0 && process_frame && buf1_numFaces(buf1_indexPop) > 0
            % If the landmarks of this frame have already been detected
            if buf2_numElem > 0
                image = buf1_img(:,:,:,buf1_indexPop);
                
                % If this is not one of the initial images
                if numberFrames > init_numImages
                    %c.im  = imshow(image,'Parent',Handle_Axes);
                    set(c.im,'CData',image);    % Show current image
                    
                    info_initText.String    = '';
                    
                    % If we want to show the framerates
                    if getappdata(Handle_Figure,'show_framerates')
                        info_framerates.String = sprintf('Current delay: %.1f Seconds\nCurrent framerate: %.1f Frames/s\nEntire eval function: %.1f Frames/s\nTotal processing: %.1f Frames/s\nCNTK: %.1f Frames/s',toc(buf1_time(buf1_indexPop)),framerate_current,framerate_EntireFunction,framerate_TotalProcessing,framerate_CNTK);
                    else
                        info_framerates.String = '';
                    end
                    
                    landmarks_plt = buf2_landmarks{buf2_indexPop};

                    % For all faces
                    for fa = 1:size(landmarks_plt,1)
                        
                        % If the bounding boxes shall be displayed
                        if getappdata(Handle_Figure,'show_BoundingBoxes')
                            bbox = buf1_bboxes(fa,:,buf1_indexPop);
                            h_rect{fa}.Position = [bbox(1),bbox(2),bbox(3),bbox(3)];
                        else
                            h_rect{fa}.Position = [0,0,0,0];
                        end

                        % If the Kinect landmarks shall be displayed
                        if getappdata(Handle_Figure,'show_KinLandmarks') 
                            model = buf1_kinFaces{buf1_indexPop}(fa).FaceModel;
                            colorCoords = k2.mapCameraPoints2Color(model');
                            h_landmarksKin{fa}.XData = colorCoords(:,1);
                            h_landmarksKin{fa}.YData = colorCoords(:,2);
                        else
                            h_landmarksKin{fa}.XData = 0;
                            h_landmarksKin{fa}.YData = 0;
                        end
                        
                        % If the landmarks shall be displayed
                        if getappdata(Handle_Figure,'show_Landmarks') 
                            h_landmarks{fa}.XData = landmarks_plt{fa}(:,1);
                            h_landmarks{fa}.YData = landmarks_plt{fa}(:,2);
                        else
                            h_landmarks{fa}.XData = 0;
                            h_landmarks{fa}.YData = 0;
                        end
                    end
                    
                    % Hide bounding boxes and faces for all of the other possible faces
                    for fa = fa+1:max_numFaces
                        h_rect{fa}.Position = [0,0,0,0];
                        h_landmarksKin{fa}.XData = 0;
                        h_landmarksKin{fa}.YData = 0;
                        h_landmarks{fa}.XData = 0;
                        h_landmarks{fa}.YData = 0;
                    end
                end
                numberFrames    = numberFrames + 1;
                frames_per_time = frames_per_time + 1;
                
                buf1_numFaces(buf1_indexPop) = 0;
                buf1_indexPop = mod(buf1_indexPop,buf_size) + 1;
                buf2_indexPop = mod(buf2_indexPop,buf_size) + 1;
                buf1_numElem  = buf1_numElem - 1;
                buf2_numElem  = buf2_numElem - 1;
            end
        % If no face was detected on the current frame
        elseif buf1_numElem > 0 && process_frame
            set(c.im,'CData',buf1_img(:,:,:,buf1_indexPop));
            numberFrames    = numberFrames + 1;
            frames_per_time = frames_per_time + 1;
            
            info_initText.String    = '';
            
            % If we want to show the framerates
            if getappdata(Handle_Figure,'show_framerates')
                info_framerates.String  = sprintf('Current delay: %.1f Seconds\nCurrent framerate: %.1f Frames/s',toc(buf1_time(buf1_indexPop)),framerate_current);
            else
                info_framerates.String = '';
            end
            
            % Hide bounding boxes and faces for all of the possible faces
            for fa = 1:max_numFaces
                h_rect{fa}.Position = [0,0,0,0];
                h_landmarksKin{fa}.XData = 0;
                h_landmarksKin{fa}.YData = 0;
                h_landmarks{fa}.XData = 0;
                h_landmarks{fa}.YData = 0;
            end

            buf1_indexPop = mod(buf1_indexPop,buf_size) + 1;
            buf1_numElem  = buf1_numElem - 1;
        end

        pause(0.01)
        iteration = iteration + 1;
    end
    
    if isvalid(Handle_Figure)
        close(Handle_Figure);   % Close figure
    end
    k2.delete;              % Delete Kinect object
    delete(p);              % Delete parallel pool
    clear EvaluationMex
end