
addpath(genpath("/Volumes/TIZIANO/Project1917/code/LGNstatistics"))
%%
path2img = "~/Desktop/leonia.jpg"
img = imread(path2img);
%%
img_len = size(img)
n_squares = 3; % height, width
square_size = [floor(img_len(1)/n_squares), floor(img_len(2)/ n_squares)]; % floor to make sure we don't overshoot with the indexing
%%

onsets = zeros(2, n_squares); % onset rows on the 1st row, onset cols on the 2nd row
onsets(:, 1) = 1;  % initializing the onsets
for i = 2:n_squares
    onsets(:, i) = onsets(:, i-1) + square_size'; % adding square_size as a column vector on the rows of onsets
end % for i = 1:n_squares

%%
% in order the columns are : CE (contrast energy), SC (spatial coherence), beta (Weibull paramt), gamma (Weibull paramt)
res_mat = zeros(n_squares(1)* n_squares(2), 4);  
CE_mat = zeros(n_squares(1)* n_squares(2), 1);
beta_mat = zeros(n_squares(1)* n_squares(2), 1);
gamma_mat = zeros(n_squares(1)* n_squares(2), 1);
%%
count_row = 0;
count_col = 0;
for i_row = onsets(1,:)
    disp(i_row)
    for i_col = onsets(2,:)
        img_sq = img(i_row: i_row+square_size(1)-1,i_col:i_col+square_size(2)-1, :);
        imshow(img_sq)
        LGNstatistics(img_sq); % res_mat(i_sq, :) = % it outputs a 1x4 vec of 1x3 arrays
    end %for i_row = 1: n_squares
end %for i_col = 1: n_squares
