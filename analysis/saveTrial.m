clear all;
close all;

% pool = gcp('nocreate');
% if isempty(pool)
%     disp('No active parallel pool.');
%     numWorkers = 10;
%     parpool('local', numWorkers);
% else
%     disp(['Parallel pool with ', num2str(pool.NumWorkers), ' workers is active and will be closed']);
%     delete(gcp('nocreate'));
%     numWorkers = 10;
%     parpool('local', numWorkers);
% end

%% =========================================================
% INPUT FILES
%% =========================================================

% Instead of loading one Ie_prime block, now load individual IePrime files
fIn1_dir = "V:\202311\w318\LIF-Processing\outputs\IePrime_ray_and_camera";
selected_frames_in = (15000:20:15100).';

fIn2 = "V:\202311\w318\LIF-Processing\inputs\CamC_black.dfi";
fIn3 = fIn2;

% Bright image is now a MAT file
fIn4 = "V:\202311\w318\LIF-Processing\inputs\CamC_bright_corrected_frame_70000.mat";
fIn5 = fIn4;

bright_tif_value_max = 1.2;

x_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_x_map.txt";
y_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_y_map.txt";

x_map_lab = "V:\202311\w318\LIF-Processing\inputs\w318_target_x_map.txt";
y_map_lab = "V:\202311\w318\LIF-Processing\inputs\w318_target_y_map.txt";

%% =========================================================
% READ INPUT FILES
%% =========================================================

% Black images are still DFI.
blackBright = read_background_image_auto(fIn2, 1);
blackDark   = read_background_image_auto(fIn3, 1);

% Bright image is now MAT.
% For MAT files, the function will try to find the image variable automatically.
DyeBright = read_background_image_auto(fIn4, bright_tif_value_max);
DyeDark   = read_background_image_auto(fIn5, bright_tif_value_max);

% Force double
blackBright = double(blackBright);
blackDark   = double(blackDark);
DyeBright   = double(DyeBright);
DyeDark     = double(DyeDark);

C0 = 0.5; % Try 0.8

yMin = 0;
yMax = 1024;
xMin = 0;
xMax = 3320;
w = xMax - xMin;
h = yMax - yMin;

% Size check
% if size(blackBright,1) ~= h || size(blackBright,2) ~= w
%     error('blackBright size mismatch: got %d x %d, expected %d x %d.', ...
%         size(blackBright,1), size(blackBright,2), h, w);
% end
%
% if size(DyeBright,1) ~= h || size(DyeBright,2) ~= w
%     error('DyeBright size mismatch: got %d x %d, expected %d x %d.', ...
%         size(DyeBright,1), size(DyeBright,2), h, w);
% end

% Stefan's original background subtraction logic
backBright = DyeBright - blackBright;
backDark   = DyeDark   - blackDark;

fprintf('\n===== Stefan background/reference stats =====\n');
print_stats_local('blackBright', blackBright);
print_stats_local('DyeBright corrected', DyeBright);
print_stats_local('backBright = DyeBright - blackBright', backBright);
print_stats_local('blackDark', blackDark);
print_stats_local('DyeDark corrected', DyeDark);
print_stats_local('backDark = DyeDark - blackDark', backDark);

%% =========================================================
% LOAD Ie_prime STACK FROM INDIVIDUAL MAT FILES
%% =========================================================

nFramesInput = numel(selected_frames_in);

fprintf('\n===== Loading individual IePrime MAT files =====\n');
fprintf('Frame range: %d to %d, step %d\n', ...
    selected_frames_in(1), selected_frames_in(end), ...
    selected_frames_in(2) - selected_frames_in(1));

% Read first frame to determine size
firstFrame = selected_frames_in(1);
firstFile = fullfile(fIn1_dir, sprintf("IePrime_%05d.mat", firstFrame));
if ~isfile(firstFile)
    error('First IePrime file not found:\n%s', firstFile);
end

firstImg = read_IePrime_frame_auto(firstFile);
firstImg = single(firstImg);

[h_in, w_in] = size(firstImg);

Ie_prime_stack = zeros(h_in, w_in, nFramesInput, 'single');
Ie_prime_stack(:,:,1) = firstImg;

fprintf('Loaded frame %d from:\n%s\n', firstFrame, firstFile);

% Load remaining frames
for kk = 2:nFramesInput

    frameIndex = selected_frames_in(kk);
    thisFile = fullfile(fIn1_dir, sprintf("IePrime_%05d.mat", frameIndex));

    if ~isfile(thisFile)
        error('IePrime file not found for frame %d:\n%s', frameIndex, thisFile);
    end

    thisImg = read_IePrime_frame_auto(thisFile);
    thisImg = single(thisImg);

    if size(thisImg,1) ~= h_in || size(thisImg,2) ~= w_in
        error('IePrime size mismatch at frame %d: got %d x %d, expected %d x %d.', ...
            frameIndex, size(thisImg,1), size(thisImg,2), h_in, w_in);
    end

    Ie_prime_stack(:,:,kk) = thisImg;

    fprintf('Loaded frame %d from:\n%s\n', frameIndex, thisFile);
end

fprintf('\nLoaded Ie_prime stack:\n');
fprintf('  class  = %s\n', class(Ie_prime_stack));
fprintf('  size   = %d x %d x %d\n', h_in, w_in, nFramesInput);
fprintf('  frames = %d to %d\n', selected_frames_in(1), selected_frames_in(end));

% if h_in ~= h || w_in ~= w
%     error('Ie_prime stack size mismatch: got %d x %d, expected %d x %d.', ...
%         h_in, w_in, h, w);
% end

% ---------------------------------------------------------
% Decide whether Ie_prime needs /255 scaling
% ---------------------------------------------------------
testMin  = min(Ie_prime_stack(:), [], 'omitnan');
testMax  = max(Ie_prime_stack(:), [], 'omitnan');
testMean = mean(Ie_prime_stack(:), 'omitnan');

fprintf('\n===== Ie_prime scale check =====\n');
fprintf('Ie_prime: min = %.6g, max = %.6g, mean = %.6g\n', ...
    testMin, testMax, testMean);

if testMax > 2
    scaleFactor = 255;
    fprintf('Using scaleFactor = 255 because Ie_prime appears to be raw-intensity scale.\n');
else
    scaleFactor = 1;
    fprintf('Using scaleFactor = 1 because Ie_prime appears to be already in 0-1 scale.\n');
end

%% =========================================================
% BUFFER SETTINGS
%% =========================================================
tic

buffLen = 50;
nBuff = ceil(nFramesInput / buffLen);

% IMPORTANT:
% Do not preallocate corr_stack as h x w x frame range.
% The frame labels are not continuous, and the array would be enormous.

%% =========================================================
% OUTPUT FOLDER
%% =========================================================
outDir = "V:\202311\w318\LIF-Processing\outputs\Ieprime_Stefan_corr";

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% =========================================================
% MAIN LOOP
%% =========================================================
for n = 1:nBuff

    idx0 = (n-1)*buffLen + 1;
    idx1 = min(n*buffLen, nFramesInput);

    idxStack = idx0:idx1;
    frms1 = selected_frames_in(idxStack);

    Len = numel(idxStack);

    fprintf('\nProcessing buffer %d / %d: stack indices %d to %d, frames %d to %d\n', ...
        n, nBuff, idx0, idx1, frms1(1), frms1(end));

    %% -----------------------------------------------------
    % Parallel processing
    %% -----------------------------------------------------
    for ii = 1:Len

        stackIndex = idxStack(ii);
        frameIndex = frms1(ii);

        % Read Ie_prime frame from stack
        im0 = double(Ie_prime_stack(:,:,stackIndex)) / scaleFactor;

        % Keep Stefan's original region handling
        im = dfiRegion(im0, xMin, xMax, yMin, yMax);

        % In Stefan's original code, even/odd raw frames may correspond
        % to bright/dark illumination states.
        % Here frameIndex is the original movie frame label.
        if mod(frameIndex, 2) == 0
            rhoI = double(im) - blackBright;
            back = backBright;
        else
            rhoI = double(im) - blackDark;
            back = backDark;
        end

        rhoI(rhoI < 0) = 0;
        rhoI = filtWindow(rhoI, 15, 1, 2);

        % -------------------------------------------------
        % Stefan correction function
        % -------------------------------------------------
        corr_stripe = corr_PLIF_20250906( ...
            rhoI, back, ...
            x_map_file, y_map_file, ...
            w, h, C0, ...
            true, true, ...
            200, 5, 1, 10, 4);

        % Written by Star
        window_size = 8;
        filtType = 3;
        corr_filt = filtWindow(corr_stripe, window_size, filtType);

        % Stefan mapping to lab coordinates
        corr = mapTo(corr_filt, x_map_lab, y_map_lab, h, w, false);

        % -------------------------------------------------
        % Save output
        % -------------------------------------------------
        outTifFile = fullfile(outDir, sprintf('Ieprime_test4_%05d.tif', frameIndex));
        outMatFile = fullfile(outDir, sprintf('Ieprime_test4_%05d.mat', frameIndex));

        corr_save = corr;
        corr_save(~isfinite(corr_save)) = 0;

        % For preview image
        corr_tif = uint16(65535 * mat2gray(corr_save));
        imwrite(corr_tif, outTifFile, 'tif');

        % For quantitative analysis
        corr_single = single(corr_save);
        parsave_corr(outMatFile, corr_single, frameIndex);
    end
end

toc
fclose('all');

%% =========================================================
% LOCAL FUNCTIONS
%% =========================================================

function parsave_corr(filename, corr_single, frameIndex)
    save(filename, 'corr_single', 'frameIndex', '-v7.3');
end


function img = read_background_image_auto(filename, tif_value_max)

    [~,~,ext] = fileparts(filename);
    ext = lower(ext);

    switch ext

        case '.dfi'
            S = dfi2mat(filename);
            img = double(S.image);

        case {'.tif', '.tiff'}
            raw = imread(filename);

            if isa(raw, 'uint16')
                img = double(raw) / 65535 * tif_value_max;

            elseif isa(raw, 'uint8')
                img = double(raw) / 255 * tif_value_max;

            else
                img = double(raw);
            end

        case '.mat'
            S = load(filename);

            % Try likely variable names first.
            preferredNames = { ...
                'DyeBright', ...
                'DyeDark', ...
                'bright_corrected', ...
                'Bright_corrected', ...
                'CamC_bright_corrected', ...
                'bright', ...
                'Bright', ...
                'img', ...
                'image', ...
                'I', ...
                'A'};

            img = pick_image_from_mat_struct(S, preferredNames, filename);

            % For MAT files, normally we preserve the saved quantitative scale.
            % But if someone saved it as uint16/uint8, convert it like TIFF.
            if isa(img, 'uint16')
                img = double(img) / 65535 * tif_value_max;

            elseif isa(img, 'uint8')
                img = double(img) / 255 * tif_value_max;

            else
                img = double(img);
            end

        otherwise
            error('Unsupported image format: %s', ext);
    end

    img(~isfinite(img)) = 0;
end


function img = read_IePrime_frame_auto(filename)

    S = load(filename);

    % Because the folder name is IePrime_ray_and_camera, the file may contain
    % both camera-space and ray-space variables.
    %
    % Stefan's code expects the camera-space image as fIn1 replacement,
    % so camera-space variable names are prioritised here.
    preferredNames = { ...
        'Ie_prime_cam', ...
        'IePrime_cam', ...
        'Ie_prime_camera', ...
        'IePrime_camera', ...
        'Ie_prime_cam_single', ...
        'IePrime_cam_single', ...
        'Ie_prime_frame_cam', ...
        'IePrime_frame_cam', ...
        'Ie_prime', ...
        'IePrime', ...
        'Ie_prime_single', ...
        'IePrime_single', ...
        'Ie_prime_frame', ...
        'IePrime_frame', ...
        'Ie', ...
        'I_e_prime', ...
        'Iep', ...
        'img', ...
        'image', ...
        'I'};

    img = pick_image_from_mat_struct(S, preferredNames, filename);

    img = double(img);
    img(~isfinite(img)) = 0;
end


function img = pick_image_from_mat_struct(S, preferredNames, filename)

    fn = fieldnames(S);

    % First try preferred variable names.
    for k = 1:numel(preferredNames)
        name = preferredNames{k};

        if isfield(S, name)
            candidate = S.(name);

            if isnumeric(candidate) && ismatrix(candidate)
                img = candidate;
                fprintf('Using variable "%s" from:\n%s\n', name, filename);
                return;
            end
        end
    end

    % If none of the preferred names exists, pick the largest numeric 2-D array.
    bestName = "";
    bestNumel = 0;
    bestImg = [];

    for k = 1:numel(fn)
        name = fn{k};
        candidate = S.(name);

        if isnumeric(candidate) && ismatrix(candidate)
            n = numel(candidate);

            if n > bestNumel
                bestNumel = n;
                bestName = string(name);
                bestImg = candidate;
            end
        end
    end

    if isempty(bestImg)
        fprintf('\nVariables found in MAT file:\n');
        disp(fn);
        error('No numeric 2-D image variable found in MAT file:\n%s', filename);
    end

    fprintf('No preferred variable name found. Using largest 2-D numeric variable "%s" from:\n%s\n', ...
        bestName, filename);

    img = bestImg;
end


function print_stats_local(name, A)

    A = double(A);
    valid = isfinite(A);

    if ~any(valid(:))
        fprintf('%s: all values are non-finite.\n', name);
        return;
    end

    Av = A(valid);

    fprintf('\n%s\n', name);
    fprintf('  size  = %d x %d\n', size(A,1), size(A,2));
    fprintf('  min   = %.6g\n', min(Av));
    fprintf('  max   = %.6g\n', max(Av));
    fprintf('  mean  = %.6g\n', mean(Av));
    fprintf('  std   = %.6g\n', std(Av));
    fprintf('  p01   = %.6g\n', prctile(Av, 1));
    fprintf('  p50   = %.6g\n', prctile(Av, 50));
    fprintf('  p99   = %.6g\n', prctile(Av, 99));
end