% clear; clc; close all;

%% =========================================================
% SCRIPT 3:
% Read saved I_e' MAT frames and run Stefan-style PLIF correction
%% =========================================================

%% ---------------- parallel pool ----------------
pool = gcp('nocreate');
if isempty(pool)
    disp('No active parallel pool.');
    numWorkers = 10;
    parpool('local', numWorkers);
else
    disp(['Parallel pool with ', num2str(pool.NumWorkers), ...
        ' workers is active and will be closed']);
    delete(gcp('nocreate'));
    numWorkers = 10;
    parpool('local', numWorkers);
end

cfg = struct();

%% ---------------- input folders/files ----------------
cfg.ieprime_dir = "V:\202311\w318\LIF-Processing\outputs\IePrime_ray_and_camera";
cfg.manifest_file = fullfile(cfg.ieprime_dir, 'IePrime_manifest.mat');

cfg.brightMatFile = "V:\202311\w318\LIF-Processing\inputs\CamC_bright_corrected_frame_70000.mat";

cfg.x_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_x_map.txt";
cfg.y_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_y_map.txt";

% If you have target/lab map, fill them here
cfg.use_lab_map = false;
cfg.x_map_lab = "";
cfg.y_map_lab = "";

%% ---------------- geometry ----------------
cfg.C0 = 0.5;
cfg.yMin = 0;
cfg.yMax = 1024;
cfg.xMin = 0;
cfg.xMax = 3320;
cfg.w = cfg.xMax - cfg.xMin;
cfg.h = cfg.yMax - cfg.yMin;

%% ---------------- function handle ----------------
% IMPORTANT:
% If your actual function name is correct_Plif_MI_20250906, change it here.
cfg.corrfun = @corr_PLIF_20250906;

%% ---------------- correction settings ----------------
cfg.preFilterInput = true;
cfg.preFilt_window = 15;
cfg.preFilt_arg2 = 1;
cfg.preFilt_arg3 = 2;

cfg.streaks = true;
cfg.synthetic_laser = true;
cfg.Level = 200;
cfg.Sigma = 5;
cfg.LS = 1;
cfg.LE = 10;
cfg.resize = 4;
cfg.fftPad = 4;

cfg.postFilter = true;
cfg.post_window_size = 8;
cfg.post_filtType = 3;

%% ---------------- output ----------------
cfg.output_dir = "V:\202311\w318\LIF-Processing\outputs\Final_processed_from_IePrime";
if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

cfg.save_tif = true;
cfg.save_mat = true;

%% ---------------- debuggging ----------------
cfg.debug = true;
cfg.debug_frames = [15000];  
cfg.debug_dir = fullfile(cfg.output_dir, 'debug_processOne');

if ~exist(cfg.debug_dir, 'dir')
    mkdir(cfg.debug_dir);
end

%% =========================================================
% LOAD BRIGHT CORRECTED MAT
%% =========================================================
Sbright = load(cfg.brightMatFile);

if ~isfield(Sbright, 'Bright_corrected')
    error('Bright_corrected not found in %s', cfg.brightMatFile);
end

back = double(Sbright.Bright_corrected);

if ~isequal(size(back), [cfg.h cfg.w])
    error('Bright_corrected size mismatch. Expected [%d %d].', cfg.h, cfg.w);
end

%% =========================================================
% LOAD MANIFEST / FILE LIST
%% =========================================================
if exist(cfg.manifest_file, 'file')
    Sm = load(cfg.manifest_file, 'saved_files', 'selected_frames');
    fileList = cellstr(Sm.saved_files);
    frameList = Sm.selected_frames;
else
    d = dir(fullfile(cfg.ieprime_dir, 'Ie_prime_cam_frame_*.mat'));
    fileList = fullfile({d.folder}, {d.name});
    fileList = fileList(:);
    frameList = nan(numel(fileList),1);
end

nFiles = numel(fileList);
fprintf('Number of IePrime frame files = %d\n', nFiles);

%% =========================================================
% PROCESS ALL FRAMES
%% =========================================================
parfor k = 1:nFiles
    inFile = fileList{k};

    S = load(inFile);

    if ~isfield(S, 'Ie_prime_cam')
        warning('Ie_prime_cam not found in %s. Skipping.', inFile);
        continue;
    end

    rhoI = double(S.Ie_prime_cam);

    if isfield(S, 'frameIndex')
        frameIndex = S.frameIndex;
    else
        frameIndex = k;
    end

    % replace NaN / invalid
    rhoI(~isfinite(rhoI)) = 0;
    rhoI(rhoI < 0) = 0;

    % optional input pre-filter
    if cfg.preFilterInput
        rhoI = filtWindow(rhoI, cfg.preFilt_window, cfg.preFilt_arg2, cfg.preFilt_arg3);
    end

    % ---- your / Stefan style correction function ----
    corr_stripe = cfg.corrfun( ...
        rhoI, ...
        back, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.w, ...
        cfg.h, ...
        cfg.C0, ...
        cfg.streaks, ...
        cfg.synthetic_laser, ...
        cfg.Level, ...
        cfg.Sigma, ...
        cfg.LS, ...
        cfg.LE, ...
        cfg.resize, ...
        cfg.fftPad);

    if do_debug
        saveDebugImage(mapped, ...
            fullfile(cfg.debug_dir, sprintf('07_mapped_from_corrPLIF_%05d.png', frameIndex)), ...
            sprintf('07 mapped from corr PLIF, frame %d', frameIndex));
    
        saveDebugImage(laser, ...
            fullfile(cfg.debug_dir, sprintf('08_laser_%05d.png', frameIndex)), ...
            sprintf('08 laser, frame %d', frameIndex));
    
        saveDebugImage(laserRhoI, ...
            fullfile(cfg.debug_dir, sprintf('09_laserRhoI_%05d.png', frameIndex)), ...
            sprintf('09 laserRhoI, frame %d', frameIndex));
    
        saveDebugImage(corr_stripe, ...
            fullfile(cfg.debug_dir, sprintf('10_corr_stripe_%05d.png', frameIndex)), ...
            sprintf('10 corr stripe output, frame %d', frameIndex));
    end

    % optional post filter
    if cfg.postFilter
        corr_filt = filtWindow(corr_stripe, cfg.post_window_size, cfg.post_filtType);
    else
        corr_filt = corr_stripe;
    end

    % optional map to lab/target space
    if cfg.use_lab_map
        corr_final = mapTo(corr_filt, cfg.x_map_lab, cfg.y_map_lab, cfg.h, cfg.w, false);
    else
        corr_final = corr_filt;
    end
    if do_debug
        saveDebugImage(corr_final, ...
            fullfile(cfg.debug_dir, sprintf('11_corr_final_%05d.png', frameIndex)), ...
            sprintf('11 corr final, frame %d', frameIndex));
    end

    % ---- save outputs ----
    if cfg.save_mat
        outMat = fullfile(cfg.output_dir, sprintf('final_corr_frame_%05d.mat', frameIndex));
        save(outMat, ...
            'frameIndex', ...
            'rhoI', ...
            'corr_stripe', ...
            'corr_filt', ...
            'corr_final', ...
            '-v7.3');
    end

    if cfg.save_tif
        outTif = fullfile(cfg.output_dir, sprintf('final_corr_frame_%05d.tif', frameIndex));

        imgToWrite = corr_final;
        imgToWrite(~isfinite(imgToWrite)) = 0;
        imgToWrite = mat2gray(imgToWrite);

        imwrite(imgToWrite, outTif);
    end
end

fprintf('\nDone. Final processed images saved to:\n%s\n', cfg.output_dir);

delete(gcp('nocreate'));