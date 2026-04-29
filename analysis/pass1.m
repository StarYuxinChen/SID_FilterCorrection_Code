clear; clc; close all;
fclose('all');

%% =========================================================
% PASS 1:
% Build <Corr> and std(Corr) for w318
%
% Correct physical definition:
%
%   I_e  = original raw camera intensity from CamC_dimmer.dfm
%   C_1  = inverse Beer-Lambert output from w318_test5_%05d.tif
%   C_k  = Star-model correction field
%   C_s  = C_1 / C_k
%   I_s  = forward Beer-Lambert sheet intensity from C_s
%   I_f  = I_s * C_s
%   Corr = I_f / I_e
%
% Important crop/mask rule:
%   Keep full image size: 1024 x 3320
%   Use valid camera crop:
%       x columns = 30:3300
%       y rows    = 20:1015
%   Outside this region is set to NaN, not physically deleted.
%
% IMPORTANT FIX IN THIS VERSION:
%   After crop masking, the physical bottom row is no longer row 1024.
%   The propagation boundary must be taken from the bottom of the valid
%   cropped/mapped region, normally around row 1015.
%% =========================================================

cfg = struct();

%% =========================================================
% BASIC CONFIG
%% =========================================================
cfg.px_per_mm = 22;

cfg.w_raw = 3320;
cfg.h_raw = 1024;

cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;

% Matrix row 1 is physical top.
% Physical z = 0 is bottom.
cfg.z_row_from_bottom_mm = ((cfg.h_raw-1):-1:0) / cfg.px_per_mm;

%% =========================================================
% CROP / VALID COMPUTATION REGION
%% =========================================================
cfg.use_crop_mask = true;

% MATLAB indices:
% x means columns.
% y means rows.
cfg.crop_x1 = 100;
cfg.crop_x2 = 3280;
cfg.crop_y1 = 20;
cfg.crop_y2 = 1015;

% When camera crop mask is mapped to ray space, interpolation can create
% fractional values around the boundary. A strict threshold protects the
% boundary from bad C1 values leaking into the valid region.
cfg.cropMask_ray_threshold = 0.999;

%% =========================================================
% ORIGINAL RAW CAMERA IMAGE: I_e
%% =========================================================
cfg.raw_input_type = 'dfm';

cfg.fRaw = "V:\202311\w318\LIF-Processing\inputs\CamC_dimmer.dfm";
cfg.fRaw_char = char(cfg.fRaw);

% Stefan/pass3 chain uses 0--1 scale.
cfg.raw_dfm_divide_by_255 = true;

%% =========================================================
% C1 INPUT: inverse Beer-Lambert output
%
% IMPORTANT:
% This is NOT raw I_e.
% This is C_1.
%% =========================================================
cfg.C1_input_type = 'tif_sequence';

cfg.C1_tif_dir = "V:\202311\w318\LIF-Processing\outputs";
cfg.C1_tif_name_fmt = "w318_test5_%05d.tif";

% C1 files are named directly by frame index:
% frame 11000 -> w318_test5_11000.tif
cfg.C1_uses_frame_index_as_file_number = true;

% Keep C1 in 0--1 scale.
cfg.C1_normalise_to_0_1 = true;

%% =========================================================
% TOP/BOTTOM FILES FOR STAR MODEL
%% =========================================================
% cfg.fileList_top = {
%     "V:\202311\w318\LIF-Processing\top_11000-17000.dfi"
%     "V:\202311\w318\LIF-Processing\top_17000-23000.dfi"
%     "V:\202311\w318\LIF-Processing\top_23000-29000.dfi"
%     "V:\202311\w318\LIF-Processing\top_29000-35000.dfi"
%     "V:\202311\w318\LIF-Processing\top_35000-41000.dfi"
%     "V:\202311\w318\LIF-Processing\top_41000-47000.dfi"
%     "V:\202311\w318\LIF-Processing\top_47000-53000.dfi"
%     "V:\202311\w318\LIF-Processing\top_53000-59000.dfi"
% };
% 
% cfg.fileList_bot = {
%     "V:\202311\w318\LIF-Processing\bot_11000-17000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_17000-23000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_23000-29000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_29000-35000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_35000-41000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_41000-47000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_47000-53000.dfi"
%     "V:\202311\w318\LIF-Processing\bot_53000-59000.dfi"
% };

cfg.fileList_top = {
    "V:\202311\w318\LIF-Processing\inputs\test5_11_17.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_17_23.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_23_29.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_29_35.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_35_41.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_41_47.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_47_53.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_53_59.dfi"
};

cfg.fileList_bot = {
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_11_17.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_17_23.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_23_29.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_29_35.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_35_41.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_41_47.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_47_53.dfi"
    "V:\202311\w318\LIF-Processing\inputs\test5_bot_53_59.dfi"
};

cfg.fit_frame_centers = [14000; 20000; 26000; 32000; 38000; 44000; 50000; 56000];

cfg.z_bot_mm = 4.22;
cfg.z_top_mm = 42.32;

%% =========================================================
% MAPPING FILES
%% =========================================================
cfg.x_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_x_map.txt";
cfg.y_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_y_map.txt";

cfg.mapfun = @mapTo;

%% =========================================================
% BEER-LAMBERT FORWARD MODEL
%% =========================================================
cfg.alpha_mean = 4e-5;

cfg.min_positive_value = 1e-10;

cfg.propagation_scheme = 'CN';
cfg.I0_boundary_mode = 'constant'; %'constant'(checking), 'smooth_x'(suggested) or 'observed'(original)

cfg.beta_min = 0;
cfg.beta_max = 1.5;

% w318: laser enters from physical bottom.
cfg.propagate_from_bottom = true;

% Use a small band at the valid bottom boundary to estimate I_s0.
% This is more robust than taking one single row.
cfg.boundary_band_rows = 5;

% Minimum row validity fraction used to identify the effective propagation
% top/bottom rows inside the ray-space crop mask.
cfg.min_boundary_valid_fraction = 0.05;

% If some columns have no finite boundary value but are valid above,
% fill their ghost boundary using the median boundary value.
cfg.fill_missing_boundary_I0 = true;

%% =========================================================
% SELECTED FRAMES FOR CORR
%% =========================================================
cfg.selected_frames = 11000:500:59000;
cfg.selected_frames = cfg.selected_frames(:);

cfg.N_sel = numel(cfg.selected_frames);

%% =========================================================
% NUMERICAL OPTIONS
%% =========================================================
cfg.pixel_chunk = 100000;

%% =========================================================
% OUTPUT
%% =========================================================
cfg.output_dir = "V:\202311\w318\LIF-Processing\outputs\Corr_model";

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

cfg.checkpoint_every = 5;

cfg.checkpoint_file = fullfile(cfg.output_dir, "Corr_checkpoint.mat");
cfg.final_corr_file = fullfile(cfg.output_dir, "Corr_model_w318.mat");

%% =========================================================
% DEBUG
%% =========================================================
cfg.debug = true;
cfg.debug_frames = [11000 20000 32000];

cfg.debug_dir = fullfile(cfg.output_dir, 'debug_pass1_IeRaw_C1_cropMasked');

if ~exist(cfg.debug_dir, 'dir')
    mkdir(cfg.debug_dir);
end

%% =========================================================
% CHECK C1 TIF FILES
%% =========================================================
fprintf('\nChecking selected C1 tif files...\n');

missingFiles = strings(0,1);

for kk = 1:numel(cfg.selected_frames)

    frameIndex = cfg.selected_frames(kk);
    fname = getC1TifFilename(frameIndex, cfg);

    if ~isfile(fname)
        missingFiles(end+1,1) = fname; %#ok<SAGROW>
    end
end

if ~isempty(missingFiles)
    fprintf('Missing C1 tif files:\n');
    disp(missingFiles);
    error('Some selected C1 tif files are missing. Please check filename numbering.');
else
    fprintf('All selected C1 tif files exist. Total = %d\n', numel(cfg.selected_frames));
end

%% =========================================================
% RAW DFM MOVIE INFO
%% =========================================================
fprintf('\nReading raw DFM movie info from:\n%s\n', cfg.fRaw);

pRaw = df_dfm_info(cfg.fRaw_char);

fidRaw = fopen(cfg.fRaw_char, 'r');

if fidRaw < 0
    error('Could not open raw movie file: %s', cfg.fRaw_char);
end

cleanupRaw = onCleanup(@() fclose(fidRaw));

I_e_test = readOriginalIeFromDfm_open(fidRaw, cfg.selected_frames(1), cfg, pRaw);

[cfg.h_raw, cfg.w_raw] = size(I_e_test);

cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;
cfg.z_row_from_bottom_mm = ((cfg.h_raw-1):-1:0) / cfg.px_per_mm;

fprintf('\nOriginal raw I_e configured as h = %d, w = %d\n', cfg.h_raw, cfg.w_raw);
fprintf('First selected raw frame read successfully: %d\n', cfg.selected_frames(1));
printImageStats('I_e_test from raw DFM', I_e_test);

C1_test = readC1FromTif(cfg.selected_frames(1), cfg);

fprintf('\nFirst selected C1 frame read successfully: %d\n', cfg.selected_frames(1));
printImageStats('C1_test from tif', C1_test);

if ~isequal(size(I_e_test), size(C1_test))
    error('I_e and C1 size mismatch. I_e is %d x %d, C1 is %d x %d.', ...
        size(I_e_test,1), size(I_e_test,2), size(C1_test,1), size(C1_test,2));
end

fprintf('\nNumber of selected frames = %d\n', cfg.N_sel);

%% =========================================================
% BUILD CAMERA-SPACE CROP MASK
%% =========================================================
fprintf('\nBuilding camera-space crop mask...\n');

cfg.cropMask_cam = false(cfg.h_raw, cfg.w_raw);
cfg.cropMask_cam(cfg.crop_y1:cfg.crop_y2, cfg.crop_x1:cfg.crop_x2) = true;

fprintf('Camera crop region:\n');
fprintf('  x columns = %d:%d\n', cfg.crop_x1, cfg.crop_x2);
fprintf('  y rows    = %d:%d\n', cfg.crop_y1, cfg.crop_y2);
fprintf('Camera crop valid fraction = %.4f\n', nnz(cfg.cropMask_cam) / numel(cfg.cropMask_cam));

%% =========================================================
% STEP 1: BUILD STAR MODEL
%% =========================================================
fprintf('\nSTEP 1: Building top/bottom temporal-spatial correction model...\n');

starModel = buildTopBottomCorrectionModel( ...
    cfg.fileList_top, ...
    cfg.fileList_bot, ...
    cfg.px_per_mm);

%% =========================================================
% STEP 2: BUILD C_fit ON RAW CAMERA GRID
%% =========================================================
fprintf('\nSTEP 2: Building C_fit on raw camera grid...\n');

C_fit = buildCameraCorrectionField( ...
    starModel, ...
    cfg.x_raw_mm, ...
    cfg.h_raw, ...
    cfg.w_raw, ...
    cfg.z_bot_mm, ...
    cfg.z_top_mm, ...
    cfg.min_positive_value);

fprintf('\nC_fit built.\n');
fprintf('C_fit size = ');
disp(size(C_fit));

%% =========================================================
% STEP 3: BUILD ROBUST RAY-SPACE VALID MASK
%% =========================================================
fprintf('\nSTEP 3: Building robust ray-space valid mask...\n');

rayMask = buildRaySpaceMask(cfg);

fprintf('Original ray-space valid fraction = %.4f\n', nnz(rayMask.valid) / numel(rayMask.valid));

if isfield(rayMask, 'col1') && isfield(rayMask, 'col2')
    fprintf('Original valid x columns = [%d, %d]\n', rayMask.col1, rayMask.col2);
end

%% =========================================================
% MAP CAMERA CROP MASK TO RAY SPACE AND COMBINE WITH rayMask.valid
%% =========================================================
fprintf('\nMapping crop mask to ray space...\n');

rayMask.valid_from_mapping = rayMask.valid;

cropMask_ray_raw = cfg.mapfun( ...
    double(cfg.cropMask_cam), ...
    cfg.x_map_file, ...
    cfg.y_map_file, ...
    cfg.h_raw, ...
    cfg.w_raw, ...
    false);

rayMask.cropMask_ray_raw = cropMask_ray_raw;
rayMask.cropMask_ray = isfinite(cropMask_ray_raw) & ...
    (cropMask_ray_raw >= cfg.cropMask_ray_threshold);

rayMask.valid = rayMask.valid_from_mapping & rayMask.cropMask_ray;

fprintf('Ray crop valid fraction       = %.4f\n', nnz(rayMask.cropMask_ray) / numel(rayMask.cropMask_ray));
fprintf('Combined final valid fraction = %.4f\n', nnz(rayMask.valid) / numel(rayMask.valid));

%% =========================================================
% SAVE MASK DEBUG FIGURES
%% =========================================================
saveDebugImage(double(cfg.cropMask_cam), ...
    fullfile(cfg.debug_dir, '00_cropMask_camera.png'), ...
    '00 camera-space crop mask', ...
    cfg, [0 1]);

saveDebugImage(double(rayMask.valid_from_mapping), ...
    fullfile(cfg.debug_dir, '00_rayMask_original.png'), ...
    '00 original ray-space valid mask', ...
    cfg, [0 1]);

saveDebugImage(double(rayMask.cropMask_ray), ...
    fullfile(cfg.debug_dir, '00_cropMask_ray.png'), ...
    '00 mapped crop mask in ray space', ...
    cfg, [0 1]);

saveDebugImage(double(rayMask.valid), ...
    fullfile(cfg.debug_dir, '00_rayMask_final_combined.png'), ...
    '00 final combined ray-space mask', ...
    cfg, [0 1]);

%% =========================================================
% STEP 4: ACCUMULATE CORR STATISTICS
%% =========================================================
fprintf('\nSTEP 4: Computing Corr_mean and Corr_std...\n');

Corr_sum   = zeros(cfg.h_raw, cfg.w_raw, 'double');
Corr_sumsq = zeros(cfg.h_raw, cfg.w_raw, 'double');
Corr_count = zeros(cfg.h_raw, cfg.w_raw, 'double');

processed_frames = [];

for k = 1:cfg.N_sel

    frameIndex = cfg.selected_frames(k);

    fprintf('\nProcessing frame %d (%d / %d)\n', frameIndex, k, cfg.N_sel);

    diag = computeFrameProducts_IeRaw_C1Model( ...
        frameIndex, ...
        cfg, ...
        fidRaw, ...
        pRaw, ...
        C_fit, ...
        rayMask);

    Corr = diag.Corr;

    Corr(~rayMask.valid) = NaN;
    Corr(~isfinite(Corr)) = NaN;

    validMask = isfinite(Corr);

    Corr_sum(validMask)   = Corr_sum(validMask)   + Corr(validMask);
    Corr_sumsq(validMask) = Corr_sumsq(validMask) + Corr(validMask).^2;
    Corr_count(validMask) = Corr_count(validMask) + 1;

    processed_frames(end+1,1) = frameIndex; %#ok<SAGROW>

    %% ---------------- Debug selected frames ----------------
    if cfg.debug && ismember(frameIndex, cfg.debug_frames)

        fprintf('\nDEBUG frame %d statistics:\n', frameIndex);

        if isfield(diag, 'propInfo')
            fprintf('\nPropagation domain used for frame %d:\n', frameIndex);
            fprintf('  topRow        = %d\n', diag.propInfo.topRow);
            fprintf('  bottomRow     = %d\n', diag.propInfo.bottomRow);
            fprintf('  boundaryRows  = %d:%d\n', ...
                diag.propInfo.boundaryRows(1), diag.propInfo.boundaryRows(end));
            fprintf('  boundary finite fraction = %.4f\n', ...
                diag.propInfo.boundaryFiniteFraction);
            fprintf('  I_s0 median   = %.6g\n', diag.propInfo.medI0);
            fprintf('  filled I_s0 columns = %d\n', diag.propInfo.nFilledBoundaryColumns);
        end

        printImageStats('I_e_cam', diag.I_e_cam);
        printImageStats('C1_cam', diag.C1_cam);
        printImageStats('Ck_cam', diag.Ck_cam);

        printImageStats('I_e_ray', diag.I_e_ray);
        printImageStats('C1_ray', diag.C1_ray);
        printImageStats('Ck_ray', diag.Ck_ray);

        printImageStats('Cs_ray = C1_ray / Ck_ray', diag.Cs_ray);
        printImageStats('Is_ray', diag.Is_ray);
        printImageStats('If_ray = Is_ray * Cs_ray', diag.If_ray);
        printImageStats('Corr = If_ray / I_e_ray', diag.Corr);

        saveDebugImage(diag.I_e_cam, ...
            fullfile(cfg.debug_dir, sprintf('01_Ie_cam_raw_cropMasked_%05d.png', frameIndex)), ...
            sprintf('01 I_e raw camera crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.I_e_cam));

        saveDebugImage(diag.C1_cam, ...
            fullfile(cfg.debug_dir, sprintf('02_C1_cam_cropMasked_%05d.png', frameIndex)), ...
            sprintf('02 C_1 camera crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.C1_cam));

        saveDebugImage(diag.Ck_cam, ...
            fullfile(cfg.debug_dir, sprintf('03_Ck_cam_cropMasked_%05d.png', frameIndex)), ...
            sprintf('03 C_k camera crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.Ck_cam));

        saveDebugImage(diag.I_e_ray, ...
            fullfile(cfg.debug_dir, sprintf('04_Ie_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('04 I_e ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.I_e_ray));

        saveDebugImage(diag.C1_ray, ...
            fullfile(cfg.debug_dir, sprintf('05_C1_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('05 C_1 ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.C1_ray));

        saveDebugImage(diag.Ck_ray, ...
            fullfile(cfg.debug_dir, sprintf('06_Ck_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('06 C_k ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.Ck_ray));

        saveDebugImage(diag.Cs_ray, ...
            fullfile(cfg.debug_dir, sprintf('07_Cs_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('07 C_s = C_1 / C_k ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.Cs_ray));

        saveDebugImage(diag.Is_ray, ...
            fullfile(cfg.debug_dir, sprintf('08_Is_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('08 I_s ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.Is_ray));

        saveDebugImage(diag.If_ray, ...
            fullfile(cfg.debug_dir, sprintf('09_If_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('09 I_f = I_s C_s ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.If_ray));

        saveDebugImage(diag.Corr, ...
            fullfile(cfg.debug_dir, sprintf('10_Corr_ray_cropMasked_%05d.png', frameIndex)), ...
            sprintf('10 Corr = I_f / I_e ray crop-masked, frame %d', frameIndex), ...
            cfg, robustClim(diag.Corr));

        saveDebugImage(double(rayMask.valid), ...
            fullfile(cfg.debug_dir, sprintf('11_rayMask_final_%05d.png', frameIndex)), ...
            sprintf('11 final ray-space valid mask, frame %d', frameIndex), ...
            cfg, [0 1]);
    end

    %% ---------------- checkpoint ----------------
    if mod(k, cfg.checkpoint_every) == 0 || k == cfg.N_sel

        [Corr_mean_tmp, Corr_std_tmp] = computeMeanStdFromSums( ...
            Corr_sum, Corr_sumsq, Corr_count);

        Corr_mean_tmp(~rayMask.valid) = NaN;
        Corr_std_tmp(~rayMask.valid)  = NaN;

        save(cfg.checkpoint_file, ...
            'Corr_sum', ...
            'Corr_sumsq', ...
            'Corr_count', ...
            'processed_frames', ...
            'Corr_mean_tmp', ...
            'Corr_std_tmp', ...
            'cfg', ...
            'rayMask', ...
            '-v7.3');

        fprintf('Checkpoint saved:\n%s\n', cfg.checkpoint_file);

        printImageStats('Corr_mean_tmp', Corr_mean_tmp);
        printImageStats('Corr_std_tmp', Corr_std_tmp);
    end
end

%% =========================================================
% STEP 5: FINAL CORR STATISTICS
%% =========================================================
[Corr_mean, Corr_std] = computeMeanStdFromSums( ...
    Corr_sum, Corr_sumsq, Corr_count);

Corr_mean(~rayMask.valid) = NaN;
Corr_std(~rayMask.valid)  = NaN;

starModelSummary = struct();

if isfield(starModel, 'gof_top')
    starModelSummary.gof_top = starModel.gof_top;
end

if isfield(starModel, 'gof_bot')
    starModelSummary.gof_bot = starModel.gof_bot;
end

starModelSummary.fit_frame_centers = cfg.fit_frame_centers;
starModelSummary.z_bot_mm = cfg.z_bot_mm;
starModelSummary.z_top_mm = cfg.z_top_mm;

save(cfg.final_corr_file, ...
    'Corr_mean', ...
    'Corr_std', ...
    'Corr_count', ...
    'processed_frames', ...
    'cfg', ...
    'rayMask', ...
    'starModelSummary', ...
    'C_fit', ...
    '-v7.3');

fprintf('\nSaved final Corr model:\n%s\n', cfg.final_corr_file);

printImageStats('Final Corr_mean', Corr_mean);
printImageStats('Final Corr_std', Corr_std);

if isfield(starModel, 'gof_top')
    fprintf('Top fit R^2    = %.6f\n', starModel.gof_top.rsquare);
end

if isfield(starModel, 'gof_bot')
    fprintf('Bottom fit R^2 = %.6f\n', starModel.gof_bot.rsquare);
end

fprintf('\nPASS 1 finished.\n');

%% =========================================================
% LOCAL FUNCTIONS
%% =========================================================

function diag = computeFrameProducts_IeRaw_C1Model(frameIndex, cfg, fidRaw, pRaw, C_fit, rayMask)

    %% ---------------------------------------------------------
    % 1. Read original raw camera image I_e
    %% ---------------------------------------------------------
    I_e_cam_full = readOriginalIeFromDfm_open(fidRaw, frameIndex, cfg, pRaw);

    %% ---------------------------------------------------------
    % 2. Read C1 image
    %
    % C1 is the image after one inverse Beer-Lambert correction.
    % It is NOT raw I_e.
    %% ---------------------------------------------------------
    C1_cam_full = readC1FromTif(frameIndex, cfg);

    %% ---------------------------------------------------------
    % 3. Get Star correction field C_k on camera grid
    %% ---------------------------------------------------------
    Ck_cam_full = interpolateCkFromCfit(frameIndex, cfg, C_fit);

    Ck_cam_full(Ck_cam_full < cfg.min_positive_value) = cfg.min_positive_value;

    %% ---------------------------------------------------------
    % 4. Camera-space masked versions for diagnostics and consistency
    %
    % Important:
    % We keep full size, but outside crop is NaN.
    %% ---------------------------------------------------------
    I_e_cam = I_e_cam_full;
    C1_cam  = C1_cam_full;
    Ck_cam  = Ck_cam_full;

    if isfield(cfg, 'use_crop_mask') && cfg.use_crop_mask
        I_e_cam(~cfg.cropMask_cam) = NaN;
        C1_cam(~cfg.cropMask_cam)  = NaN;
        Ck_cam(~cfg.cropMask_cam)  = NaN;
    end

    %% ---------------------------------------------------------
    % 5. Map full camera fields to ray space
    %
    % We map full fields first, then apply rayMask.valid.
    % This avoids NaNs from the camera crop boundary being interpolated
    % into the ray-space interior.
    %% ---------------------------------------------------------
    I_e_ray = cfg.mapfun( ...
        I_e_cam_full, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    C1_ray = cfg.mapfun( ...
        C1_cam_full, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    Ck_ray = cfg.mapfun( ...
        Ck_cam_full, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    I_e_ray(~rayMask.valid) = NaN;
    C1_ray(~rayMask.valid)  = NaN;
    Ck_ray(~rayMask.valid)  = NaN;

    %% ---------------------------------------------------------
    % 6. Build concentration proxy C_s
    %
    % Definition:
    %   C_s = C_1 / C_k
    %% ---------------------------------------------------------
    Ck_safe = Ck_ray;
    Ck_safe(Ck_safe < cfg.min_positive_value) = cfg.min_positive_value;

    Cs_ray = C1_ray ./ Ck_safe;

    Cs_ray(~rayMask.valid) = NaN;
    Cs_ray(~isfinite(Cs_ray)) = NaN;

    %% ---------------------------------------------------------
    % 7. Forward Beer-Lambert propagation to get I_s
    %% ---------------------------------------------------------
    [Is_ray, propInfo] = forwardBeerLambertSheetIntensity(Cs_ray, I_e_ray, cfg, rayMask);

    %% ---------------------------------------------------------
    % 8. Forward-predicted image
    %
    %   I_f = I_s * C_s
    %% ---------------------------------------------------------
    If_ray = Is_ray .* Cs_ray;

    If_ray(~rayMask.valid) = NaN;
    If_ray(~isfinite(If_ray)) = NaN;

    %% ---------------------------------------------------------
    % 9. Correction factor
    %
    %   Corr = I_f / I_e
    %% ---------------------------------------------------------
    I_e_safe = I_e_ray;
    I_e_safe(I_e_safe < cfg.min_positive_value) = cfg.min_positive_value;

    Corr = If_ray ./ I_e_safe;

    Corr(~rayMask.valid) = NaN;
    Corr(~isfinite(Corr)) = NaN;

    %% ---------------------------------------------------------
    % 10. Output diagnostics
    %% ---------------------------------------------------------
    diag = struct();

    diag.frameIndex = frameIndex;

    diag.I_e_cam = I_e_cam;
    diag.C1_cam  = C1_cam;
    diag.Ck_cam  = Ck_cam;

    diag.I_e_ray = I_e_ray;
    diag.C1_ray  = C1_ray;
    diag.Ck_ray  = Ck_ray;

    diag.Cs_ray = Cs_ray;
    diag.Is_ray = Is_ray;
    diag.If_ray = If_ray;
    diag.Corr   = Corr;

    diag.propInfo = propInfo;
end

function [Is_ray, propInfo] = forwardBeerLambertSheetIntensity(Cs_ray, I_e_ray, cfg, rayMask)

    Cs_ray = double(Cs_ray);
    I_e_ray = double(I_e_ray);

    [h, w] = size(Cs_ray);

    Is_ray = NaN(h, w);

    %% ---------------------------------------------------------
    % Valid pixels used for propagation
    %% ---------------------------------------------------------
    valid = rayMask.valid & isfinite(Cs_ray) & isfinite(I_e_ray);

    Cs_safe = Cs_ray;
    Cs_safe(~valid) = NaN;
    Cs_safe(Cs_safe < cfg.min_positive_value) = cfg.min_positive_value;

    %% ---------------------------------------------------------
    % Find effective propagation domain after crop/mapping.
    %
    % This is the key correction:
    %   Do NOT start from row h = 1024 after crop.
    %   Start from the bottom of the valid cropped/mapped region.
    %% ---------------------------------------------------------
    propInfo = findPropagationDomain(valid, cfg);

    topRow    = propInfo.topRow;
    bottomRow = propInfo.bottomRow;

    if cfg.propagate_from_bottom

        %% -----------------------------------------------------
        % Boundary condition at physical bottom:
        %
        %   I_f = I_s * C_s
        %
        % At incident boundary:
        %
        %   I_s0 = I_e_boundary / C_s_boundary
        %
        % Use a small valid bottom band instead of one single row.
        %% -----------------------------------------------------
        bandN = cfg.boundary_band_rows;
        boundaryRows = max(topRow, bottomRow - bandN + 1) : bottomRow;

        I0_samples = I_e_ray(boundaryRows, :) ./ Cs_safe(boundaryRows, :);

        validBoundary = valid(boundaryRows, :);
        I0_samples(~validBoundary) = NaN;


        I0_raw = median(I0_samples, 1, 'omitnan');

        validSomewhereInColumn = any(valid(topRow:bottomRow, :), 1);
        
        goodI0 = isfinite(I0_raw) & I0_raw > 0;
        vals = I0_raw(goodI0);
        
        if isempty(vals)
            medI0 = 1;
        else
            medI0 = median(vals);
        end
        
        switch lower(cfg.I0_boundary_mode)
        
            case 'constant'
        
                % Cleanest test case:
                % assume incident laser sheet is uniform along x.
                I0 = NaN(1, w);
                I0(validSomewhereInColumn) = medI0;
        
            case 'smooth_x'
        
                % Recommended final-ish version:
                % keep only slow x variation of the incident laser sheet.
                I0 = I0_raw;
        
                I0 = fillmissing(I0, 'linear', 2, 'EndValues', 'nearest');
        
                % Remove column-scale artefacts.
                I0 = smoothdata(I0, 2, 'movmedian', 101, 'omitnan');
        
                % Keep only broad laser-sheet envelope.
                I0 = smoothdata(I0, 2, 'movmean', 501, 'omitnan');
        
                % Optional: normalise so the median stays unchanged.
                I0_med_after = median(I0(isfinite(I0) & I0 > 0), 'omitnan');
                if isfinite(I0_med_after) && I0_med_after > 0
                    I0 = I0 / I0_med_after * medI0;
                end
        
                I0(~validSomewhereInColumn) = NaN;
        
            case 'observed'
        
                % Original version:
                % not recommended because it injects raw x-noise into I_s.
                I0 = I0_raw;
        
                fillCols = validSomewhereInColumn & (~isfinite(I0) | I0 <= 0);
                I0(fillCols) = medI0;
        
                I0(~validSomewhereInColumn) = NaN;
        
            otherwise
        
                error('Unknown cfg.I0_boundary_mode: %s', cfg.I0_boundary_mode);
        end
        
        nFilled = nnz(validSomewhereInColumn & (~isfinite(I0_raw) | I0_raw <= 0));
        
        % =========================================================
        % TEST MODE:
        % Force a constant incident laser boundary.
        % If I_s becomes smooth, the previous vertical stripes came from I0(x),
        % not from propagation direction.
        % =========================================================
        I0 = NaN(1, w);
        I0(validSomewhereInColumn) = medI0;
        
        nFilled = nnz(validSomewhereInColumn & (~isfinite(I0_raw) | I0_raw <= 0));
        
        I0(~validSomewhereInColumn) = NaN;

        Is_ray(bottomRow, :) = I0;

        %% -----------------------------------------------------
        % Bottom-to-top propagation.
        %
        % Matrix row index decreases when moving physically upward.
        %
        % Important:
        % Use Cs_safe(iz,:) for the row being entered.
        % This avoids the crop boundary ghost row problem.
        %% -----------------------------------------------------
        for iz = bottomRow-1 : -1 : topRow

            beta = computeBeerLambertBeta(Cs_safe(iz, :), cfg);

            row_new = Is_ray(iz+1, :) .* beta;

            bad = ~valid(iz, :);
            row_new(bad) = NaN;

            Is_ray(iz, :) = row_new;
        end

        propInfo.boundaryRows = boundaryRows;
        propInfo.boundaryFiniteFraction = nnz(isfinite(I0_samples)) / numel(I0_samples);
        propInfo.medI0 = medI0;
        propInfo.nFilledBoundaryColumns = nFilled;

    else

        %% -----------------------------------------------------
        % Top-to-bottom option, not normally used for w318.
        %% -----------------------------------------------------
        bandN = cfg.boundary_band_rows;
        boundaryRows = topRow : min(bottomRow, topRow + bandN - 1);

        I0_samples = I_e_ray(boundaryRows, :) ./ Cs_safe(boundaryRows, :);

        validBoundary = valid(boundaryRows, :);
        I0_samples(~validBoundary) = NaN;

        I0 = median(I0_samples, 1, 'omitnan');

        validSomewhereInColumn = any(valid(topRow:bottomRow, :), 1);

        goodI0 = isfinite(I0) & I0 > 0;
        vals = I0(goodI0);

        if isempty(vals)
            medI0 = 1;
        else
            medI0 = median(vals);
        end

        nFilled = 0;

        if isfield(cfg, 'fill_missing_boundary_I0') && cfg.fill_missing_boundary_I0
            fillCols = validSomewhereInColumn & (~isfinite(I0) | I0 <= 0);
            nFilled = nnz(fillCols);
            I0(fillCols) = medI0;
        end

        I0(~validSomewhereInColumn) = NaN;

        Is_ray(topRow, :) = I0;

        for iz = topRow+1 : bottomRow

            beta = computeBeerLambertBeta(Cs_safe(iz, :), cfg);

            row_new = Is_ray(iz-1, :) .* beta;

            bad = ~valid(iz, :);
            row_new(bad) = NaN;

            Is_ray(iz, :) = row_new;
        end
        
        propInfo.boundaryRows = boundaryRows;
        propInfo.boundaryFiniteFraction = nnz(isfinite(I0_samples)) / numel(I0_samples);
        propInfo.medI0 = medI0;
        propInfo.nFilledBoundaryColumns = nFilled;
    end
    
    %% ---------------------------------------------------------
    % Final mask
    %% ---------------------------------------------------------
    Is_ray(~rayMask.valid) = NaN;
    Is_ray(~isfinite(Is_ray)) = NaN;
end

function propInfo = findPropagationDomain(valid, cfg)

    [h, w] = size(valid);

    if isfield(cfg, 'use_crop_mask') && cfg.use_crop_mask
        rowSearch = max(1, cfg.crop_y1) : min(h, cfg.crop_y2);
        colSearch = max(1, cfg.crop_x1) : min(w, cfg.crop_x2);
    else
        rowSearch = 1:h;
        colSearch = 1:w;
    end

    rowCounts = sum(valid(rowSearch, colSearch), 2);

    minFrac = cfg.min_boundary_valid_fraction;
    minCols = max(10, round(minFrac * numel(colSearch)));

    goodLocalRows = find(rowCounts >= minCols);

    if isempty(goodLocalRows)

        warning(['Could not find enough valid rows inside configured crop. ', ...
                 'Falling back to any valid row in the full image.']);

        rowCountsAll = sum(valid, 2);
        goodRows = find(rowCountsAll > 0);

    else

        goodRows = rowSearch(goodLocalRows);

    end

    if isempty(goodRows)
        error('No valid rows found for Beer-Lambert propagation.');
    end

    topRow = min(goodRows);
    bottomRow = max(goodRows);

    colCounts = sum(valid(topRow:bottomRow, :), 1);
    goodCols = find(colCounts > 0);

    if isempty(goodCols)
        goodCols = colSearch;
    end

    propInfo = struct();

    propInfo.topRow = topRow;
    propInfo.bottomRow = bottomRow;
    propInfo.goodCols = goodCols;
    propInfo.nGoodCols = numel(goodCols);

    propInfo.rowSearchFirst = rowSearch(1);
    propInfo.rowSearchLast  = rowSearch(end);
    propInfo.colSearchFirst = colSearch(1);
    propInfo.colSearchLast  = colSearch(end);
    propInfo.minColsForValidRow = minCols;
end

function beta = computeBeerLambertBeta(Cs_row, cfg)

    Cs_row = double(Cs_row);

    switch lower(cfg.propagation_scheme)

        case 'explicit'

            beta = 1 - cfg.alpha_mean .* Cs_row;

        case 'cn'

            beta = (1 - 0.5 .* cfg.alpha_mean .* Cs_row) ./ ...
                   (1 + 0.5 .* cfg.alpha_mean .* Cs_row);

        otherwise

            error('Unknown propagation scheme: %s', cfg.propagation_scheme);
    end

    beta(~isfinite(beta)) = NaN;

    if isfield(cfg, 'beta_min')
        beta(beta < cfg.beta_min) = cfg.beta_min;
    end

    if isfield(cfg, 'beta_max')
        beta(beta > cfg.beta_max) = cfg.beta_max;
    end
end

function I_e_cam = readOriginalIeFromDfm_open(fidRaw, frameIndex, cfg, pRaw)

    exp = df_dfm_read(fidRaw, frameIndex, pRaw);

    I_e_cam = double(exp(:,:,1,1));

    if isfield(cfg, 'raw_dfm_divide_by_255') && cfg.raw_dfm_divide_by_255
        I_e_cam = I_e_cam ./ 255;
    end

    I_e_cam(~isfinite(I_e_cam)) = NaN;
end

function C1_cam = readC1FromTif(frameIndex, cfg)

    fname = getC1TifFilename(frameIndex, cfg);

    if ~isfile(fname)
        error('C1 tif file not found for frame %d:\n%s', frameIndex, fname);
    end

    A = imread(fname);

    if ndims(A) == 3
        A = A(:,:,1);
    end

    C1_cam = double(A);

    if isfield(cfg, 'C1_normalise_to_0_1') && cfg.C1_normalise_to_0_1

        vals = C1_cam(isfinite(C1_cam));

        if ~isempty(vals)

            p99 = prctile(vals, 99);

            if p99 > 1000
                C1_cam = C1_cam ./ 65535;
            elseif p99 > 2
                C1_cam = C1_cam ./ 255;
            end
        end
    end

    C1_cam(~isfinite(C1_cam)) = NaN;
end

function fname = getC1TifFilename(frameIndex, cfg)

    if isfield(cfg, 'C1_uses_frame_index_as_file_number') && cfg.C1_uses_frame_index_as_file_number

        fileNumber = frameIndex;

    else

        error('Only direct frame-index C1 filenames are configured in this script.');

    end

    fname = fullfile(cfg.C1_tif_dir, sprintf(char(cfg.C1_tif_name_fmt), fileNumber));
end

function Ck_cam = interpolateCkFromCfit(frameIndex, cfg, C_fit)

    if ndims(C_fit) == 2
        Ck_cam = C_fit;
        return;
    end

    [h, w, nt] = size(C_fit);

    if nt ~= numel(cfg.fit_frame_centers)
        error('C_fit third dimension does not match cfg.fit_frame_centers.');
    end

    Ck_cam = NaN(h, w);

    nPix = h * w;
    tFit = double(cfg.fit_frame_centers(:));

    C_flat = reshape(C_fit, nPix, nt);

    chunk = cfg.pixel_chunk;

    for p1 = 1:chunk:nPix

        p2 = min(p1 + chunk - 1, nPix);

        F = double(C_flat(p1:p2, :));

        Ctmp = interp1( ...
            tFit, ...
            F.', ...
            double(frameIndex), ...
            'linear', ...
            'extrap');

        Ck_cam(p1:p2) = Ctmp(:);
    end

    Ck_cam = reshape(Ck_cam, h, w);

    Ck_cam(~isfinite(Ck_cam)) = NaN;
end

function [Corr_mean, Corr_std] = computeMeanStdFromSums(Corr_sum, Corr_sumsq, Corr_count)

    Corr_mean = NaN(size(Corr_sum));
    Corr_std  = NaN(size(Corr_sum));

    valid = Corr_count > 0;

    Corr_mean(valid) = Corr_sum(valid) ./ Corr_count(valid);

    variance_tmp = Corr_sumsq(valid) ./ Corr_count(valid) - Corr_mean(valid).^2;

    variance_tmp(variance_tmp < 0) = 0;

    Corr_std(valid) = sqrt(variance_tmp);
end

function clim = robustClim(A)

    A = double(A);
    vals = A(isfinite(A));

    if isempty(vals)
        clim = [];
        return;
    end

    clim = prctile(vals, [1 99]);

    if ~all(isfinite(clim)) || clim(2) <= clim(1)
        clim = [min(vals), max(vals)];
    end

    if ~all(isfinite(clim)) || clim(2) <= clim(1)
        clim = [];
    end
end

function printImageStats(name, A)

    A = double(A);
    vals = A(isfinite(A));

    if isempty(vals)
        fprintf('\n%s: no finite values.\n', name);
        return;
    end

    fprintf('\n%s\n', name);
    fprintf('  size      = %d x %d\n', size(A,1), size(A,2));
    fprintf('  finite %%  = %.2f %%\n', 100 * numel(vals) / numel(A));
    fprintf('  min       = %.6g\n', min(vals));
    fprintf('  p01       = %.6g\n', prctile(vals, 1));
    fprintf('  p50       = %.6g\n', prctile(vals, 50));
    fprintf('  p99       = %.6g\n', prctile(vals, 99));
    fprintf('  max       = %.6g\n', max(vals));
end

function saveDebugImage(A, outFile, figTitle, cfg, clim_use)

    A = double(A);

    fig = figure('Visible', 'off');

    if size(A,1) == cfg.h_raw && size(A,2) == cfg.w_raw

        imagesc(cfg.x_raw_mm, cfg.z_row_from_bottom_mm, A);
        xlabel('x (mm)');
        ylabel('z from bottom (mm)');

    else

        imagesc(A);
        xlabel('column');
        ylabel('row');

    end

    axis image;
    set(gca, 'YDir', 'normal');

    colorbar;
    title(figTitle, 'Interpreter', 'none');

    if nargin >= 5 && ~isempty(clim_use)
        if all(isfinite(clim_use)) && clim_use(2) > clim_use(1)
            caxis(clim_use);
        end
    end

    outFile = char(outFile);

    drawnow;
    exportgraphics(fig, outFile, 'Resolution', 200);
    close(fig);

    if isfile(outFile)
        fprintf('Saved debug image: %s\n', outFile);
    else
        warning('Debug image was NOT created: %s', outFile);
    end
end