% Low-light enhancement: Original, LIME, and SSIF + CLAHE

clc;
clear;
close all;

root = fileparts(mfilename('fullpath'));

assert(~isempty(root), ...
    'Save this script as Master_Project.m first.');

addpath(root);

assert(exist(fullfile(root,'SSIF.m'),'file') ~= 0, ...
    'Keep SSIF.m beside Master_Project.m.');

assert(exist('niqe','file') ~= 0, ...
    'NIQE requires the Image Processing Toolbox.');

%% 1. Choose dataset folder

datasetNames = {'LIME','NPE','Own','Provided'};

choice = menu('Choose a dataset folder', datasetNames{:});

if choice == 0
    return;
end

dataset = datasetNames{choice};
folder = fullfile(root, dataset);

assert(exist(folder,'dir') ~= 0, ...
    'Missing dataset folder: %s', folder);

files = image_files(folder);

if isempty(files)
    fprintf('No images found in %s.\n', folder);
    return;
end

%% 2. Choose one image or all images

runChoice = menu('What do you want to run?', ...
    'Select one image', 'All images');

if runChoice == 0
    return;
end

if runChoice == 1

    [index, confirmed] = listdlg( ...
        'PromptString', 'Select an image:', ...
        'SelectionMode', 'single', ...
        'ListString', {files.name}, ...
        'ListSize', [420 300]);

    if ~confirmed
        return;
    end

    files = files(index);
end

%% 3. Parameters

% SSIF + CLAHE settings
cfg.radius = 19;
cfg.epsilon = 0.001;
cfg.kappa = 2;
cfg.scale = 0.1;
cfg.numTiles = [2 2];
cfg.clipLimit = 0.01;

% Unofficial LIME settings
cfg.limeAlpha = 0.08;
cfg.limeMu = 0.01;
cfg.limeRho = 1.2;
cfg.limeGamma = 0.8;

% Kappa study
cfg.runKappaStudy = true;
cfg.kappaValues = [0.5 1 1.5 2 2.5 3 4];

% In "All images" mode, study the first 3 images alphabetically.
% Change to Inf to study every image.
% In single-image mode, study the selected image.
cfg.kappaImages = 3;

rows = cell(0,5);
krows = cell(0,5);

methods = {'Original', 'LIME', 'SSIF + CLAHE'};

%% 4. Process selected images

for i = 1:numel(files)

    name = files(i).name;

    fprintf('\n[%s %d/%d] %s\n', ...
        dataset, i, numel(files), name);

    % Read RGB image
    try
        [original, map] = imread(fullfile(folder,name));

        assert(isempty(map) && size(original,3) == 3, ...
            'Input must be an RGB colour image.');

        original = im2double(original);

        assert(all(isfinite(original(:))), ...
            'Input contains nonfinite pixels.');

    catch err
        warning('Skipping %s: %s', name, err.message);
        continue;
    end

    % Apply both enhancement methods
    outputs = {original, [], []};

    for m = 2:3
        try
            if m == 2
                outputs{m} = enhance_lime(original,cfg);
            else
                outputs{m} = enhance_ssif(original,cfg,cfg.kappa);
            end

        catch err
            warning('%s failed for %s: %s', ...
                methods{m}, name, err.message);
        end
    end

    %% 5. Show original and enhanced images with NIQE

    scores = NaN(1,3);

    figure( ...
        'Color','w', ...
        'Name',name, ...
        'NumberTitle','off', ...
        'Position',[100 100 1400 550]);

    for m = 1:3

        subplot(1,3,m);

        if isempty(outputs{m})
            axis off;
            text(0.1,0.5,'Enhancement failed');

        else
            scores(m) = image_niqe(outputs{m});
            imshow(outputs{m});
        end

        title(sprintf('%s\nNIQE: %.3f', ...
            methods{m}, scores(m)));

        rows(end+1,:) = { ...
            dataset, name, methods{m}, scores(m), ...
            ~isempty(outputs{m})};
    end

    sgtitle([dataset ': ' name], 'Interpreter','none');
    drawnow;

    disp(table(string(methods(:)), scores(:), ...
        'VariableNames', {'Method','NIQE'}));

    %% 6. Kappa study: visual comparison and NIQE graph

    if cfg.runKappaStudy && i <= cfg.kappaImages

        kScores = NaN(size(cfg.kappaValues));

        figure( ...
            'Color','w', ...
            'Name',['Kappa images: ' name], ...
            'NumberTitle','off', ...
            'Position',[50 50 1400 800]);

        nCols = 4;
        nRows = ceil((numel(cfg.kappaValues)+1)/nCols);

        subplot(nRows,nCols,1);
        imshow(original);
        title('Original');

        for k = 1:numel(cfg.kappaValues)

            kap = cfg.kappaValues(k);

            subplot(nRows,nCols,k+1);

            try
                % Reuse the default result when kappa is unchanged
                if kap == cfg.kappa && ~isempty(outputs{3})
                    result = outputs{3};
                    kScores(k) = scores(3);

                else
                    result = enhance_ssif(original,cfg,kap);
                    kScores(k) = image_niqe(result);
                end

                imshow(result);

            catch err
                axis off;
                text(0.1,0.5,'Enhancement failed');

                warning('Kappa %g failed for %s: %s', ...
                    kap, name, err.message);
            end

            title(sprintf('Kappa = %g\nNIQE: %.3f', ...
                kap, kScores(k)));

            krows(end+1,:) = { ...
                dataset, name, kap, kScores(k), ...
                isfinite(kScores(k))};
        end

        sgtitle(['SSIF parameter study: ' name], ...
            'Interpreter','none');

        % One graph: kappa versus NIQE
        figure( ...
            'Color','w', ...
            'Name',['Kappa NIQE: ' name], ...
            'NumberTitle','off');

        plot(cfg.kappaValues, kScores, ...
            'o-', 'LineWidth',1.5);

        xlabel('\kappa');
        ylabel('NIQE (lower is better)');
        title(['SSIF: ' name], 'Interpreter','none');

        grid on;
        xticks(cfg.kappaValues);
        drawnow;
    end
end

%% 7. Results tables

metrics = cell2table(rows, 'VariableNames', ...
    {'Dataset','Image','Method','NIQE','EnhancementSucceeded'});

kappa = cell2table(krows, 'VariableNames', ...
    {'Dataset','Image','Kappa','NIQE','ValidNIQE'});

disp(metrics);

% Calculate means using the same images for all three methods.
% Exclude an image if any method has an unavailable NIQE score.
if ~isempty(rows)

    allScores = reshape(cell2mat(rows(:,4)),3,[]).';
    valid = all(isfinite(allScores),2);

    means = NaN(3,1);

    if any(valid)
        means = mean(allScores(valid,:),1).';
    end

    summary = table( ...
        string(methods(:)), ...
        repmat(sum(valid),3,1), ...
        means, ...
        'VariableNames', ...
        {'Method','CommonImageCount','MeanNIQE'});

    disp(summary);
end

if ~isempty(krows)
    disp(kappa);
end

fprintf('\nFinished. No output files were saved.\n');
fprintf('NaN means that a valid NIQE score was unavailable.\n');

%% Local function: find image files

function files = image_files(folder)

files = dir(folder);
keep = false(size(files));

for j = 1:numel(files)

    [~,~,ext] = fileparts(files(j).name);

    keep(j) = ~files(j).isdir && any(strcmpi(ext, ...
        {'.jpg','.jpeg','.png','.bmp','.tif','.tiff'}));
end

files = files(keep);

[~,order] = sort(lower(string({files.name})));
files = files(order);

end

%% Local function: NIQE

function value = image_niqe(image)

value = NaN;

try
    value = niqe(rgb2gray(image));

    if ~isfinite(value)
        value = NaN;
    end

catch err
    warning('NIQE unavailable for this image: %s',err.message);
end

end

%% Local function: SSIF + CLAHE enhancement

function result = enhance_ssif(image,cfg,kappa)

[h,s,v] = rgb2hsv(image);

% Handle a completely constant brightness channel
if max(v(:)) == min(v(:))
    level1 = v;
    level2 = v;

else
    level1 = SSIF(v,v, ...
        cfg.radius,cfg.epsilon,kappa,cfg.scale);

    level2 = SSIF(level1,level1, ...
        cfg.radius,cfg.epsilon,kappa,cfg.scale);
end

assert(all(isfinite(level2(:))), ...
    'SSIF returned nonfinite pixels.');

% Two detail layers
detail1 = v-level1;
detail2 = level1-level2;

% CLAHE on the final approximation
enhancedBase = adapthisteq(level2, ...
    'NumTiles',cfg.numTiles, ...
    'ClipLimit',cfg.clipLimit);

% Reconstruction with unit detail weights
vFinal = detail1+detail2+enhancedBase;

% Keep reconstructed brightness within the valid range
vFinal = min(max(vFinal,0),1);

result = hsv2rgb(cat(3,h,s,vFinal));

assert(all(isfinite(result(:))), ...
    'SSIF output contains nonfinite pixels.');

end

%% Local function: unofficial LIME enhancement

function result = enhance_lime(image,cfg)

[T,~] = lime(image, ...
    cfg.limeAlpha,cfg.limeMu,cfg.limeRho,cfg.limeGamma);

assert(all(isfinite(T(:))), ...
    'LIME returned a nonfinite illumination map.');

T = max(real(T),1e-6);

result = min(max(image./T,0),1);

assert(all(isfinite(result(:))), ...
    'LIME output contains nonfinite pixels.');

end

%% Unofficial LIME helpers
% Calculations retained from the previous implementation.

function [output,ini_map] = lime(input_image,alpha,mu,rho,gamma)

B_norm = im2double(input_image);
ini_map = initial_map(B_norm);

ref_map = lime_trial(ini_map,alpha,mu,rho);

abs_ref_map = abs(ref_map);
T_gamma = gamma_corr(abs_ref_map,gamma);

Topt(:,:,1) = T_gamma;
Topt(:,:,2) = T_gamma;
Topt(:,:,3) = T_gamma;

output = Topt;

end

function Topt = lime_trial(Ti,alpha,mu0,rho)

[m,n] = size(Ti);

k0 = 50;
Z = zeros(2*m,n);
G = Z;
k = 0;
mu = mu0;

W = make_weight_matrix(Ti,5);

while k < k0

    U = Z/mu;
    A = alpha*W/mu;

    T = updateT(Ti,mu,G,U);
    delT = multiplyd(T);

    G = shrinkage(A,delT+U);

    B = delT-G;
    Z = mu*(B+U);

    mu = mu*rho;
    k = k+1;
end

Topt = T;

end

function test_mask = initial_map(test_norm)

y = size(test_norm);
a = zeros(y(1),y(2));

for i = 1:y(1)
    for j = 1:y(2)

        b = [test_norm(i,j,1), ...
             test_norm(i,j,2), ...
             test_norm(i,j,3)];

        if max(b) == 0
            a(i,j) = 0.000001;
        else
            a(i,j) = max(b);
        end
    end
end

test_mask = a;

end

function out = gamma_corr(a,gamma)

out = a.^gamma;

end

function W = make_weight_matrix(Ti,ker_size)

[m,n] = size(Ti);
p = m*n;

delTi = multiplyd(Ti);
dtvec = reshape(delTi,[2*p,1]);

dtx = dtvec(1:p);
dty = dtvec(p+1:2*p);

w_gauss = fspecial('gaussian',[ker_size,1],2);

convl_x = conv(dtx,w_gauss,'same');
convl_y = conv(dty,w_gauss,'same');

W_x = 1./(abs(convl_x)+0.0001);
W_y = 1./(abs(convl_y)+0.0001);

W_vec = vertcat(W_x,W_y);
W = reshape(W_vec,[2*m,n]);

end

function T = updateT(Ti,mu,G,U)

X = G-U;
delX = multiplydtrans(X);

Tnum = 2*Ti+mu*delX;
Tn = fftshift(fft2(Tnum));

[m,n] = size(Ti);
Td = Tdenom(m,n,mu);

Tnd = Tn./Td;
T = ifft2(ifftshift(Tnd));

end

function Td = Tdenom(m,n,mu)

dxe = zeros(m,n);
dye = zeros(m,n);

dxe(2,2) = -1;
dxe(2,3) = 1;

dye(2,2) = -1;
dye(3,2) = 1;

dxf = fftshift(fft2(dxe));
dxc = dxf.'';
dx_mod = dxc.*dxf;

dyf = fftshift(fft2(dye));
dyc = dyf.'';
dy_mod = dyc.*dyf;

Td = 2+mu*(dx_mod+dy_mod);

end

function delT = multiplyd(T)

[m,n] = size(T);

Dy = maked_alt(m);
Dxt = maked_alt(n);
Dx = Dxt';

altTy = zeros(m+1,n);
altTy(1:m,1:n) = T;
altTy(m+1,1:n-1) = T(1,2:n);
altTy(m+1,n) = T(1,1);

delTy = Dy*altTy;

altTx = zeros(m,n+1);
altTx(1:m,1:n) = T;
altTx(1:m,n+1) = T(1:m,1);

delTx = altTx*Dx;

dtx = reshape(delTx,[m*n,1]);
dty = reshape(delTy,[m*n,1]);

dt = [dtx;dty];
delT = reshape(dt,[2*m,n]);

end

function delG = multiplydtrans(G)

[p,n] = size(G);
m = floor(p/2);

g = reshape(G,[p*n,1]);

Gx = reshape(g(1:m*n),[m,n]);
Gy = reshape(g(m*n+1:p*n),[m,n]);

Dyi = maked_alt(m);
Dy = -Dyi;

Dxi = maked_alt(n);
Dx = Dxi(1:n,1:n);
Dx(1:n,1) = Dx(1:n,1)+Dxi(1:n,n+1);

altGy = zeros(m+1,n);
altGy(2:m+1,1:n) = Gy;
altGy(1,2:n) = Gy(m,1:n-1);
altGy(1,1) = Gy(m,n);

delGy = Dy*altGy;
delGx = Gx*Dx;

delG = delGx+delGy;

end

function S = shrinkage(A,X)

[m,n] = size(A);
Z = zeros(m,n);

S = sign(X).*max(abs(X)-A,Z);

end

function D = maked_alt(m)

A = zeros(m,m+1);

for i = 1:m
    A(i,i) = -1;
    A(i,i+1) = 1;
end

D = A;

end