%% This function processes the Kinect frames with CNTK and shows the landmarks etc...
%
% See README.txt
%
function main(Handles)
%% Initialization

    % You can change this
    MiniBatchSize       = 8;      	% Minibatch size for landmark detection with CNTK
  	bbox_scale_factor   = 1.17;     % Scale factor of Kinect tight bounding box
    MaxExtBBoxes        = 2;        % Numer of frames where the bounding box is extrapolated when the Kinect does not detect it anymore
    ModelFitting        = false;
    ShowLandmarks       = true;
    ShowKinectLMs       = false;
    ShowFramerate       = true;
    ShowBoundingBoxes   = true;
    
    % If this function is not called from the GUI
    if nargin == 0
        Handle_Figure   = figure;
        Handle_Axes     = axes;
        
        setappdata(Handle_Figure,'enable_ModelFitting', ModelFitting);
        setappdata(Handle_Figure,'show_Landmarks',      ShowLandmarks);
        setappdata(Handle_Figure,'show_KinLandmarks',   ShowKinectLMs);
        setappdata(Handle_Figure,'show_framerates',     ShowFramerate);
        setappdata(Handle_Figure,'show_BoundingBoxes',  ShowBoundingBoxes);
        setappdata(Handle_Figure,'bboxes_ScaleFactor',  bbox_scale_factor);
        setappdata(Handle_Figure,'maxExtBBoxes',        MaxExtBBoxes);
        setappdata(Handle_Figure,'minibatchSize',       MiniBatchSize);
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
  	clear mb_detect_landmarks;
    
    % Create Kinect 2 object and initialize it
    k2 = Kin2('color','HDface');
    
    img_size        = [1080,1920,3];
    max_numFaces    = 6;
    default_padding	= [200 200];
    grey_color    	= 127;
    ImgResizeTo   	= [96 96];
    numExtBBoxes    = zeros(1,max_numFaces);
    
    buf1_size       = 2*MaxMinibatchSize;
    buf1_img        = zeros([img_size,buf1_size],'uint8');
    buf1_bboxes     = zeros(max_numFaces,3,buf1_size);
    buf1_scaleFactor= zeros(max_numFaces,buf1_size);
    buf1_numFaces   = zeros(1,buf1_size);
    buf1_kinFaces   = cell(buf1_size,1);
    buf1_time       = zeros(1,buf1_size,'uint64');
    buf1_indexPush  = 1;
    buf1_indexPop   = 1;
    buf1_numElem    = 0;
    
    buf2_size       = buf1_size*max_numFaces;
    buf2_faces      = zeros([96,96,buf2_size],'uint8');
    buf2_indexPush  = 1;
    buf2_indexPop   = 1;
    buf2_numElem    = 0;
    
    buf3_size       = buf2_size;
    buf3_landmarks  = zeros([68,2,buf3_size]);
    buf3_indexPush  = 1;
    buf3_indexPop   = 1;
    buf3_numElem    = 0;
    
    noface_inTurn   = 0;
    numFrames       = 0;
    frame_delay     = 0.95;
    
    framerate_EntireSubFunction = 0;
    framerate_CNTK              = 0;
    framerate_current           = 0;
    frames_per_time             = 0;
    
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

    %% Run the first two minibatches with CNTK in the background
    
    % Get the current parallel pool
    p = gcp();

    % Run two minibatches
    for i = 1:2
        F = parfeval(p,@mb_detect_landmarks,2,buf2_faces(:,:,1:MaxMinibatchSize),false,MaxMinibatchSize);
    
        % Wait until it has finished
        while ~strcmp(F.State,'finished'), end
        
        [~,~] = fetchOutputs(F);
    end
    
    minibatch_size = getappdata(Handle_Figure,'minibatchSize');

    %%
    
    t1 = tic;
    t2 = t1;

    while isvalid(Handle_Figure)      
        %% Framerate
        
        if numFrames < 1
            framerate_current   = 20;
            t1                  = tic;
        % Determine the current framerate
        elseif toc(t1) >= 1
            framerate_current	= frames_per_time/toc(t1);
            frames_per_time     = 0;
            t1                  = tic;
        end
        
        % Determine if the current frame from the kinect shall be processed
        if toc(t2) >= frame_delay/(framerate_current+1)
            t2 = tic;
            process_frame = true;
            pause_interval = 0.007;
        else
            process_frame = false;
            pause_interval = 0.0001;
        end

        %% Fill buffer with data
        
        if process_frame && buf1_numElem < 2*minibatch_size %&& buf2_numElem < 2*minibatch_size
            
            % Until a valid frame was acquired
            while ~k2.updateData, end
        
            % Get current frame
            image = k2.getColor;
            
            buf1_time(buf1_indexPush) = tic;

            % Store current frame in buffer
            buf1_img(:,:,:,buf1_indexPush) = image;
            
            img_gray = rgb2gray(image);

            % Get the HDfaces data
            faces = k2.getHDFaces('WithVertices','true'); 

            numFaces = 0;
                
            % For all Kinect faces
            for fa = 1:size(faces,2)

                % If the size of the bounding box is zero
                if faces(fa).FaceBox(3)-faces(fa).FaceBox(1) == 0 || faces(fa).FaceBox(4)-faces(fa).FaceBox(2) == 0
                    continue;
                end
                
                numFaces = numFaces + 1;

                buf1_kinFaces{buf1_indexPush}(numFaces) = faces(fa);

                % Determine tight bounding box of the face
                bbox_tight_min  = [faces(fa).FaceBox(1),faces(fa).FaceBox(2)];
                bbox_tight_max  = [faces(fa).FaceBox(3),faces(fa).FaceBox(4)];
                bbox_tight_size = bbox_tight_max - bbox_tight_min;

                % Get squared scaled bounding box
                bbox_center     = (bbox_tight_min + bbox_tight_max)/2;
                bbox_size       = ceil(getappdata(Handle_Figure,'bboxes_ScaleFactor')*max(bbox_tight_size));
                bbox_size_half  = bbox_size/2;
                bbox_min        = floor(bbox_center - bbox_size_half);
                
                buf1_bboxes(numFaces,:,buf1_indexPush) = [bbox_min,bbox_size];

                numExtBBoxes(numFaces) = 0;
            end
            
            maxExtBBoxes = getappdata(Handle_Figure,'maxExtBBoxes');
                    
            % For all other possible faces
            for fa = numFaces+1:max_numFaces
                % If there are at least two valid images in the buffer
                if buf1_numElem >= 2 && numExtBBoxes(fa) < maxExtBBoxes 
                    index_prev1 = mod(buf1_indexPush-2,buf1_size) + 1;
                    index_prev2 = mod(buf1_indexPush-3,buf1_size) + 1;
                    % If this bounding box was already provided by the previous two images
                    if fa <= buf1_numFaces(index_prev1) && fa <= buf1_numFaces(index_prev2)
                        % Extrapolate bounding box
                        ext_factor = 1;
                        bbox_center_prev1 = buf1_bboxes(fa,1:2,index_prev1) + buf1_bboxes(fa,3,index_prev1)/2;
                        bbox_center_prev2 = buf1_bboxes(fa,1:2,index_prev2) + buf1_bboxes(fa,3,index_prev2)/2;

                        bbox_size	= ceil((1+ext_factor)*buf1_bboxes(fa,3,index_prev1)-ext_factor*buf1_bboxes(fa,3,index_prev2));
                        bbox_min  	= ceil((1+ext_factor)*bbox_center_prev1-ext_factor*bbox_center_prev2-bbox_size/2);

                        % If the extrapolated bounding box is not useful
                        if bbox_size < 20 || bbox_size > 800 || any(bbox_min < -100) || bbox_min(1)+bbox_size > 2020 || bbox_min(2)+bbox_size > 1180
                            break;
                        end

                        buf1_kinFaces{buf1_indexPush}(fa) = buf1_kinFaces{index_prev1}(fa);
                        numExtBBoxes(fa) = numExtBBoxes(fa) + 1;

                        buf1_bboxes(fa,:,buf1_indexPush) = [bbox_min,bbox_size];
                        
                        numFaces = numFaces + 1;
                    else
                        break;
                    end
                else
                    break;
                end
            end
            
            % For all bounding boxes
            for fa = 1:numFaces
            
                bbox_min    = buf1_bboxes(fa,1:2,buf1_indexPush);
                bbox_size   = buf1_bboxes(fa,3,buf1_indexPush);
                bbox_max    = bbox_min + bbox_size;

                % Grey padding
                padding_pre     = max(0,1 - bbox_min);
                padding_post  	= max(0,bbox_max - img_size([2,1]));

                % If the default padding is too small for the image
                if any(padding_pre > default_padding) || any(padding_post > default_padding)
                    padding = [max(padding_pre(1),padding_post(1)),max(padding_pre(2),padding_post(2))];
                else
                    padding = default_padding;
                end

                % Grey padding of the image
                padded_image = padarray(img_gray,flip(padding),grey_color);

                % Crop and resize image
                buf2_faces(:,:,buf2_indexPush) = imresize(padded_image(bbox_min(2)+padding(2):bbox_max(2)+padding(2),bbox_min(1)+padding(1):bbox_max(1)+padding(1)),ImgResizeTo);

                buf1_scaleFactor(fa,buf1_indexPush) = (bbox_size + 1)/ImgResizeTo(1);

                buf2_indexPush  = mod(buf2_indexPush,buf2_size) + 1;
                buf2_numElem  	= buf2_numElem + 1;
            end

            % If there is no face
            if numFaces < 1
                buf1_numFaces(buf1_indexPush) = 0;

                noface_inTurn = noface_inTurn + 1;

            % If at least one face was detected
            else
                buf1_numFaces(buf1_indexPush) = numFaces;

                noface_inTurn = 0;
            end

            buf1_indexPush  = mod(buf1_indexPush,buf1_size) + 1;
            buf1_numElem  	= buf1_numElem + 1;        
        end
        
        %% Extract landmarks
        
        % If the last detection has finished
        if strcmp(F.State,'finished')
            % If these data were not read before
            if ~F.Read
                indices = buf3_indexPush:buf3_indexPush+numLastImages-1;
                indices = bsxfun(@(x,s) mod(x-1,s)+1,indices,buf3_size);
                
                [buf3_landmarks(:,:,indices),current_framerates] = fetchOutputs(F);
                
                buf3_indexPush = mod(buf3_indexPush+numLastImages-1,buf3_size) + 1;
                buf3_numElem = buf3_numElem + numLastImages;

                framerate_EntireSubFunction = current_framerates(1);
                framerate_CNTK = current_framerates(2);

                minibatch_size = getappdata(Handle_Figure,'minibatchSize');
            end
            
            % If there is a full minibatch of faces in the buffer
            if buf2_numElem >= minibatch_size
                
                indices = buf2_indexPop:buf2_indexPop+minibatch_size-1;
                indices = bsxfun(@(x,s) mod(x-1,s)+1,indices,buf2_size);

                F = parfeval(p,@mb_detect_landmarks,2,buf2_faces(:,:,indices),getappdata(Handle_Figure,'enable_ModelFitting'),MaxMinibatchSize);

                buf2_indexPop   = mod(buf2_indexPop+minibatch_size-1,buf2_size) + 1;
                numLastImages   = minibatch_size;
                buf2_numElem    = buf2_numElem - minibatch_size;
            % Avoid blocking
            elseif buf2_numElem > 0 && (noface_inTurn > 5 || buf3_numElem < buf1_numFaces(buf1_indexPop))
                
                indices = buf2_indexPop:buf2_indexPop+buf2_numElem-1;
                indices = bsxfun(@(x,s) mod(x-1,s)+1,indices,buf2_size);

                F = parfeval(p,@mb_detect_landmarks,2,buf2_faces(:,:,indices),getappdata(Handle_Figure,'enable_ModelFitting'),MaxMinibatchSize);

                buf2_indexPop   = mod(buf2_indexPop+buf2_numElem-1,buf2_size) + 1;
                numLastImages   = buf2_numElem;
                buf2_numElem    = 0;
            end
        end

        %% Show output
        
        % If the buffer is not full OR if the frame shall not be processed
        if buf1_numElem < 2*minibatch_size || ~process_frame
            pause(pause_interval)
            continue;
        end
            
        % If a face was detected on the current buffered frame
        if buf1_numFaces(buf1_indexPop) > 0
            % If the landmarks of this frame have already been detected
            if buf3_numElem >= buf1_numFaces(buf1_indexPop)
                image = buf1_img(:,:,:,buf1_indexPop);

                set(c.im,'CData',image);    % Show current image

                info_initText.String = '';

                % If we want to show the framerates
                if getappdata(Handle_Figure,'show_framerates')
                    info_framerates.String = sprintf('Current delay: %.1f Seconds\nCurrent framerate: %.1f Frames/s\nEntire subfunction: %.1f Frames/s\nCNTK: %.1f Frames/s',toc(buf1_time(buf1_indexPop)),framerate_current,framerate_EntireSubFunction,framerate_CNTK);
                else
                    info_framerates.String = '';
                end

                % For all faces
                for fa = 1:buf1_numFaces(buf1_indexPop)

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

                        % Backtransformation of the coordinates
                        landmarks = buf3_landmarks(:,:,buf3_indexPop)*buf1_scaleFactor(fa,buf1_indexPop) + buf1_bboxes(fa,1:2,buf1_indexPop) - 1;

                        h_landmarks{fa}.XData = landmarks(:,1);
                        h_landmarks{fa}.YData = landmarks(:,2);
                    else
                        h_landmarks{fa}.XData = 0;
                        h_landmarks{fa}.YData = 0;
                    end
                    buf3_indexPop = mod(buf3_indexPop,buf3_size) + 1;
                    buf3_numElem  = buf3_numElem - 1;
                end

                % Hide bounding boxes and faces for all of the other possible faces
                for fa = fa+1:max_numFaces
                    h_rect{fa}.Position = [0,0,0,0];
                    h_landmarksKin{fa}.XData = 0;
                    h_landmarksKin{fa}.YData = 0;
                    h_landmarks{fa}.XData = 0;
                    h_landmarks{fa}.YData = 0;
                end
                frames_per_time = frames_per_time + 1;

                buf1_numFaces(buf1_indexPop) = 0;
                buf1_indexPop = mod(buf1_indexPop,buf1_size) + 1;
                buf1_numElem  = buf1_numElem - 1;
            end
        % If no face was detected on the current frame
        else
            set(c.im,'CData',buf1_img(:,:,:,buf1_indexPop));
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

            buf1_indexPop = mod(buf1_indexPop,buf1_size) + 1;
            buf1_numElem  = buf1_numElem - 1;
        end
        numFrames = numFrames + 1;
        pause(pause_interval)
    end
    
    if isvalid(Handle_Figure)
        close(Handle_Figure);   % Close figure
    end
    k2.delete;              % Delete Kinect object
    delete(p);              % Delete parallel pool
    clear EvaluationMex
end