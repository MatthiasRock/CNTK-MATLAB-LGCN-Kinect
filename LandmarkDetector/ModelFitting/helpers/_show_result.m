function show_result_reg(images,pred,gtx,gty,predx,predy,id,lmid,figure_id)

if nargin>8
    figure(figure_id);
end

nx = 3;
ny = 3;

for i=1:ny*nx;
    j = min(lmid+i-1,size(gtx,1));
    subplot(nx+1,ny,i);
    imshow(fliplr(imrotate(squeeze(max1(pred(:,:,j,id))),-90))); colormap(jet);
    hold on;
    scatter(gtx(j,id),gty(j,id),'b');
    scatter(predx(j,id),predy(j,id),'r');
end

i = 1:size(gtx,1);
inside = i>= lmid & i<= lmid+8;
outside = i & ~inside;

%% Pred
subplot(nx+1,ny,nx*ny+1);
imshow(squeeze(images(id,:,:))./255);
hold on;
scatter(predx(inside,id),predy(inside,id),'y');
scatter(predx(outside,id),predy(outside,id),'r');
title('Prediction');

%% GT
subplot(nx+1,ny,nx*ny+2);
imshow(squeeze(images(id,:,:))./255);
hold on;
scatter(gtx(inside,id),gty(inside,id),'c');
scatter(gtx(outside,id),gty(outside,id),'b');
title('Ground Truth');

%% Error Hist
subplot(nx+1,ny,nx*ny+3);
stem(1:size(gtx,1),sqrt((gtx(:,id)-predx(:,id)).^2 + (gty(:,id)-predy(:,id)).^2));
title('Error Histogram');
xlabel('landmark ID');
ylabel('absolute error');