% landmarks_PCA = fit_compl(SM,pred,landmarks,window_sizes,model_constraints,image_boundary_constraints,thresh);
function landmarks_PCA = fit_compl(SM,pred,landmarks,window_sizes,model_constraints,image_boundary_constraints,thresh)
%FIT_COMPL fits the model to a set of heatmaps and returns predicted coordinates

x = squeeze(landmarks(:,1,:));
y = squeeze(landmarks(:,2,:));

lmn     = size(pred,3);
imgn    = size(pred,4);
imgszx  = size(pred,1);
imgszy  = size(pred,2);

%% First (global) fit
for k = 1:imgn
    p = pred(:,:,:,k);
    
    centroid = [imgszx/2+0.5, imgszy/2+0.5];
    
    ploc = p(sub2ind(size(p),minmax(round(x(:,k)),1,imgszx),minmax(round(y(:,k)),1,imgszy),(1:lmn).'));
    certain = ploc >= thresh;
    if sum(certain) < 2     % Too defensive (not enough points), use the most certain landmarks
        [~,ord] = sort(ploc);
        certain = ord(end-max(4,round(1.0/thresh)):end);
    end
    theta = kabsch([x(certain,k), y(certain,k)],SM.mean_face(certain,:));

    tmp = fit_transrotated_model(SM, p, model_constraints, image_boundary_constraints, centroid, theta);
    x(:,k) = tmp(1:2:end);
    y(:,k) = tmp(2:2:end);
    
end

%% Iterative (local) fitting
window_sizes = round(window_sizes);
x2 = x;
y2 = y;

for iter=1:size(window_sizes,2)
    dxy = window_sizes(iter);
    xtmp = permute(reshape(min(max(cell2mat(arrayfun(@(z) z-dxy:z+dxy,round(x2),'UniformOutput',false)),1),imgszx),[lmn,1+2*dxy,imgn]),[1,3,2]);
    ytmp = permute(reshape(min(max(cell2mat(arrayfun(@(z) z-dxy:z+dxy,round(y2),'UniformOutput',false)),1),imgszy),[lmn,1+2*dxy,imgn]),[1,3,2]);

    selector = false(size(pred));

    for i = 1:size(x2,1)
       for j = 1:size(y2,2)
           selector(xtmp(i,j,:),ytmp(i,j,:),i,j) = true;    % Mark weights to keep
       end
    end

    for k = 1:imgn
        predloc = pred(:,:,:,k);
        predloc(~selector(:,:,:,k)) = 0;                    % Set all outlier weights to zero
        p = pred(:,:,:,k);
        
        centroid = [imgszx/2+0.5, imgszy/2+0.5];

        ploc = p(sub2ind(size(p),minmax(round(x(:,k)),1,imgszx),minmax(round(y(:,k)),1,imgszy),(1:lmn).'));
        certain = ploc >= thresh;
        if sum(certain) < 2     % Too defensive (not enough points), use the most certain landmarks
            [~,ord] = sort(ploc);
            certain = ord(end-max(4,round(1.0/thresh)):end);
        end
        theta = kabsch([x(certain,k), y(certain,k)],SM.mean_face(certain,:));
            
        tmp = fit_transrotated_model(SM, predloc, model_constraints, image_boundary_constraints, centroid, theta);
        x2(:,k) = tmp(1:2:end);
        y2(:,k) = tmp(2:2:end);

    end
end

landmarks_PCA = landmarks;
landmarks_PCA(:,1,:) = x2;
landmarks_PCA(:,2,:) = y2;

end

