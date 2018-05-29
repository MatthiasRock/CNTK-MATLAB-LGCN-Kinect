function [ new_labels ] = allign_training_set( train_labels, noisedeg, imsz, compat)

if nargin < 2
    noisedeg = 0;
end
if nargin < 3
    imsz = 96;
end
if nargin < 4
    compat = false;
end

if compat
    % In the paper, we used very similar but slightly more elaborate method
    % with different offsets to align the data. The angles that were used
    % are provided below:
    load('train/theta.mat','theta2');
else
    load('train/300W_train.mat','mean_face');
end

new_labels = zeros(size(train_labels));

for k=1:size(train_labels,1)
    t = train_labels(k,:);
    t=t(:);
    
    %% Find rotation relative to mean face using Kabsch algorithm ...
    if compat
        theta = theta2(k);
    else
        theta = kabsch([t(1:2:end),t(2:2:end)],mean_face) + randi(1+2*noisedeg)-noisedeg-1;
    end
            
    %% ... and apply it
    R = kron(eye(size(t,1)/2), rotmat(-theta));
    t = R*(t-(imsz+1)/2)+(imsz+1)/2; % rotate around image center

    new_labels(k,1:2:end)=t(1:2:end);
    new_labels(k,2:2:end)=t(2:2:end);
end

end
