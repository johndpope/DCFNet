function test_dcf()
addpath('../utils');
run vl_setupnn();
normalize = @(x,y)  ((double(x)/255) - mean(double(x(:)))/255).*y  ;

image_file = dir('./Fish/img/*.jpg');
image_file = sort({image_file.name});
image_file = fullfile('./Fish/img/',image_file);

gt = dlmread('./Fish/groundtruth_rect.txt');
start_frame = 1;
next_frame = 20;

target_sz = gt(start_frame,[4,3]);
pos = gt(start_frame,[2,1])+floor(target_sz/2);
window_sz = floor(target_sz * (1 + 1.5));
cos_window = single(hann(window_sz(1))) * single(hann(window_sz(2)))';
sigma = sqrt(prod(target_sz))/10;

target_sz_2 = gt(next_frame,[4,3]);
pos_2 = gt(next_frame,[2,1])+floor(target_sz_2/2);

label_shift = pos_2 - pos;

im = imread(image_file{start_frame});
x = get_subwindow(im, pos, window_sz);
subplot(2,3,1),imshow(repmat(x,[1,1,3]));hold on;
plot(window_sz(2)/2,window_sz(1)/2,'r*');title('target');
x = normalize(x,cos_window);

im = imread(image_file{next_frame});
z = get_subwindow(im, pos, window_sz);
subplot(2,3,2),imshow(repmat(z,[1,1,3]));hold on;
plot(window_sz(2)/2+label_shift(2),window_sz(1)/2+label_shift(1),'r*');title('search');
z = normalize(z,cos_window);


net = dagnn.DagNN() ;
dcfBlock = dagnn.DCF('win_size', window_sz,'sigma',sigma) ;
net.addLayer('dcf', dcfBlock, {'x','z'}, {'response'}) ;

net.eval({'x',x,'z',z});

response = net.vars(net.getVarIndex('response')).value ;

subplot(2,3,3),imagesc(response);title('predic response');

[vert_delta, horiz_delta] = find(response == max(response(:)), 1);
if vert_delta > size(response,1) / 2,  %wrap around to negative half-space of vertical axis
    vert_delta = vert_delta - size(response,1);
end
if horiz_delta > size(response,2) / 2,  %same for horizontal axis
    horiz_delta = horiz_delta - size(response,2);
end

predic_pos = pos + [vert_delta - 1, horiz_delta - 1];
predic_rect = [predic_pos([2,1]) - target_sz([2,1])/2, target_sz([2,1])];

subplot(2,3,4),imshow(repmat(im,[1,1,3]));
rectangle('Position',predic_rect,'EdgeColor',[0,1,1]);
rectangle('Position',gt(next_frame,:),'EdgeColor',[0,1,0]);
title('predic rect');

% sz = [100,100];
% sigma = sqrt(prod(sz/2.5))/10;
% label_shift = [0,0];
% response = gaussian_shaped_labels_shift(sigma, sz, label_shift);
% subplot(2,3,5);imagesc(response);
net.eval({'x',x,'z',x});
response = net.vars(net.getVarIndex('response')).value ;
subplot(2,3,5);imagesc(response);title('learnt response');

response = gaussian_shaped_labels_shift(sigma, window_sz, label_shift);
subplot(2,3,6);imagesc(response);title('idea predict response');

saveas(gcf,'gray_dcf','pdf')
end


function labels = gaussian_shaped_labels_shift(sigma, sz,label_shift)

[rs, cs] = ndgrid((1:sz(1)) - floor(sz(1)/2), (1:sz(2)) - floor(sz(2)/2));
labels = exp(-0.5 / sigma^2 * (rs.^2 + cs.^2));

labels = circshift(labels, -floor(sz(1:2) / 2) + 1+label_shift);

% assert(labels(1,1) == 1)

end