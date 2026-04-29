clear; clc; close all;

%% =========================================================
% SCRIPT 1:
% Build <Corr> and std(Corr) for w318
%% =========================================================

cfg = struct();

%% ---------------- basic config ----------------
cfg.px_per_mm = 22;

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

%% ---------------- original raw camera image I_e ----------------
cfg.raw_input_type = 'dfm';

cfg.fRaw = "V:\202311\w318\LIF-Processing\inputs\CamC_dimmer.dfm";
cfg.fRaw_char = char(cfg.fRaw);

% Keep I_e in 0--1 scale because Stefan/pass3 also uses 0--1.
cfg.raw_dfm_divide_by_255 = true;

%% ---------------- C1 input: inverse Beer-Lambert output ----------------
% This is NOT raw I_e.
% This is C_1, produced by previous inverse Beer-Lambert processing.
cfg.C1_input_type = 'tif_sequence';

cfg.C1_tif_dir = "V:\202311\w318\LIF-Processing\outputs";
cfg.C1_tif_name_fmt = "w318_test5_%05d.tif";

% frameIndex = 11000 -> w318_test5_11000.tif
cfg.C1_tif_first_file_number = 1;
cfg.C1_tif_first_frame_index = 1;

% Keep C1 in 0--1 scale to be consistent unless you deliberately tuned alpha for 0--255.
cfg.C1_read_as_double = true;
cfg.C1_normalise_to_0_1 = true;

cfg.x_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_x_map.txt";
cfg.y_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_y_map.txt";
cfg.mapfun = @mapTo;

cfg.fit_frame_centers = [14000; 20000; 26000; 32000; 38000; 44000; 50000; 56000];

cfg.z_bot_mm = 4.22;
cfg.z_top_mm = 42.32;

cfg.alpha_mean = 5e-6;
cfg.min_positive_value = 1e-10;
cfg.propagation_scheme = 'CN';
cfg.beta_min = 0;
cfg.beta_max = 1.5;
cfg.propagate_from_bottom = true;

cfg.w_raw = 3320;
cfg.h_raw = 1024;
cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;
cfg.z_plot_mm = (0:cfg.h_raw-1) / cfg.px_per_mm;

%% ---------------- selected frames for Corr ----------------
cfg.selected_frames = 11000:500:59000;
cfg.N_sel = numel(cfg.selected_frames);

%% ---------------- check selected tif files ----------------
fprintf('\nChecking selected C1 tif files...\n');

missingFiles = strings(0,1);

for kk = 1:numel(cfg.selected_frames)
    frameIndex = cfg.selected_frames(kk);
    fname = getC1TifFilename(frameIndex, cfg);

    if ~isfile(fname)
        missingFiles(end+1,1) = fname;
    end
end

if ~isempty(missingFiles)
    fprintf('Missing C1 tif files:\n');
    disp(missingFiles);
    error('Some selected C1 tif files are missing. Please check filename numbering.');
else
    fprintf('All selected C1 tif files exist. Total = %d\n', numel(cfg.selected_frames));
end

if ~isempty(missingFiles)
    fprintf('Missing tif files:\n');
    disp(missingFiles);
    error('Some selected tif files are missing. Please check filename numbering.');
else
    fprintf('All selected tif files exist. Total = %d\n', numel(cfg.selected_frames));
end

%% ---------------- output ----------------
cfg.output_dir = "V:\202311\w318\LIF-Processing\outputs\Corr_model";
if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

cfg.checkpoint_every = 5;   % every N frames save checkpoint
cfg.checkpoint_file = fullfile(cfg.output_dir, "Corr_checkpoint.mat");
cfg.final_corr_file = fullfile(cfg.output_dir, "Corr_model_w318.mat");



%% =========================================================
% RAW MOVIE INFO
%% =========================================================
pRaw = df_dfm_info(cfg.fRaw_char);

fprintf('\nRaw movie configured as h = %d, w = %d\n', cfg.h_raw, cfg.w_raw);
fprintf('Number of selected frames = %d\n', cfg.N_sel);


%% =========================================================
% RAW DFM MOVIE INFO
%% =========================================================
pRaw = df_dfm_info(cfg.fRaw_char);

I_e_test = readOriginalIeFromDfm(cfg.selected_frames(1), cfg, pRaw);
[cfg.h_raw, cfg.w_raw] = size(I_e_test);

cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;
cfg.z_plot_mm = (0:cfg.h_raw-1) / cfg.px_per_mm;

fprintf('\nOriginal raw I_e configured as h = %d, w = %d\n', cfg.h_raw, cfg.w_raw);
fprintf('First selected raw frame read successfully: %d\n', cfg.selected_frames(1));
fprintf('I_e image class after reading = %s\n', class(I_e_test));
fprintf('I_e min/max = %.6f / %.6f\n', min(I_e_test(:)), max(I_e_test(:)));

C1_test = readC1FromTif(cfg.selected_frames(1), cfg);

fprintf('\nC1 image read successfully: %d\n', cfg.selected_frames(1));
fprintf('C1 image class after reading = %s\n', class(C1_test));
fprintf('C1 min/max = %.6f / %.6f\n', min(C1_test(:)), max(C1_test(:)));

if ~isequal(size(I_e_test), size(C1_test))
    error('I_e and C1 size mismatch. I_e is %d x %d, C1 is %d x %d.', ...
        size(I_e_test,1), size(I_e_test,2), size(C1_test,1), size(C1_test,2));
end
%% =========================================================
% STEP 1: Build Star model
%% =========================================================
fprintf('\nSTEP 1: Building top/bottom temporal-spatial correction model...\n');

starModel = buildTopBottomCorrectionModel( ...
    cfg.fileList_top, ...
    cfg.fileList_bot, ...
    cfg.px_per_mm);

%% =========================================================
% STEP 2: Build C_fit on raw camera grid
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

%% =========================================================
% STEP 3: Build robust ray-space valid mask
%% =========================================================
fprintf('\nSTEP 3: Building robust ray-space valid mask...\n');

rayMask = buildRaySpaceMask(cfg);

fprintf('Ray-space valid fraction = %.4f\n', nnz(rayMask.valid) / numel(rayMask.valid));
fprintf('Valid x columns = [%d, %d]\n', rayMask.col1, rayMask.col2);

%% =========================================================
% STEP 4: Accumulate Corr statistics
%% =========================================================
fprintf('\nSTEP 4: Computing Corr_mean and Corr_std...\n');

Corr_sum   = zeros(cfg.h_raw, cfg.w_raw, 'double');
Corr_sumsq = zeros(cfg.h_raw, cfg.w_raw, 'double');
Corr_count = zeros(cfg.h_raw, cfg.w_raw, 'double');

processed_frames = [];

for k = 1:cfg.N_sel
    frameIndex = cfg.selected_frames(k);

    fprintf('Processing frame %d (%d / %d)\n', frameIndex, k, cfg.N_sel);

     diag = computeFrameProducts_IeRaw_C1Model(frameIndex, cfg, pRaw, C_fit, rayMask);
    
    % Expecting diag.Corr exists
    Corr = diag.Corr;

    % mask invalid region
    Corr(~rayMask.valid) = NaN;

    validMask = isfinite(Corr);

    Corr_sum(validMask)   = Corr_sum(validMask)   + Corr(validMask);
    Corr_sumsq(validMask) = Corr_sumsq(validMask) + Corr(validMask).^2;
    Corr_count(validMask) = Corr_count(validMask) + 1;

    processed_frames(end+1,1) = frameIndex; %#ok<SAGROW>

    % checkpoint
    if mod(k, cfg.checkpoint_every) == 0 || k == cfg.N_sel
        [Corr_mean_tmp, Corr_std_tmp] = computeMeanStdFromSums(Corr_sum, Corr_sumsq, Corr_count);

        save(cfg.checkpoint_file, ...
            'Corr_sum', 'Corr_sumsq', 'Corr_count', ...
            'processed_frames', ...
            'Corr_mean_tmp', 'Corr_std_tmp', ...
            'cfg', 'rayMask', ...
            '-v7.3');

        fprintf('Checkpoint saved: %s\n', cfg.checkpoint_file);
    end
end

%% =========================================================
% STEP 5: Final Corr statistics
%% =========================================================
[Corr_mean, Corr_std] = computeMeanStdFromSums(Corr_sum, Corr_sumsq, Corr_count);

starModelSummary = struct();
starModelSummary.gof_top = starModel.gof_top;
starModelSummary.gof_bot = starModel.gof_bot;
starModelSummary.fit_frame_centers = cfg.fit_frame_centers;
starModelSummary.z_bot_mm = cfg.z_bot_mm;
starModelSummary.z_top_mm = cfg.z_top_mm;

save(cfg.final_corr_file, ...
    'Corr_mean', 'Corr_std', ...
    'Corr_count', ...
    'processed_frames', ...
    'cfg', ...
    'rayMask', ...
    'starModelSummary', ...
    'C_fit', ...
    '-v7.3');

fprintf('\nSaved final Corr model:\n%s\n', cfg.final_corr_file);
fprintf('Top fit R^2    = %.6f\n', starModel.gof_top.rsquare);
fprintf('Bottom fit R^2 = %.6f\n', starModel.gof_bot.rsquare);

%% =========================================================
% local function
%% =========================================================
function [Corr_mean, Corr_std] = computeMeanStdFromSums(Corr_sum, Corr_sumsq, Corr_count)
    Corr_mean = NaN(size(Corr_sum));
    Corr_std  = NaN(size(Corr_sum));

    valid = Corr_count > 0;

    Corr_mean(valid) = Corr_sum(valid) ./ Corr_count(valid);

    variance_tmp = Corr_sumsq(valid) ./ Corr_count(valid) - Corr_mean(valid).^2;
    variance_tmp(variance_tmp < 0) = 0;

    Corr_std(valid) = sqrt(variance_tmp);
end

function I_e_cam = readOriginalIeFromDfm(frameIndex, cfg, pRaw)

    f1 = fopen(cfg.fRaw_char, 'r');

    if f1 < 0
        error('Could not open raw movie file: %s', cfg.fRaw_char);
    end

    exp = df_dfm_read(f1, frameIndex, pRaw);
    fclose(f1);

    I_e_cam = double(exp(:,:,1,1));

    if isfield(cfg, 'raw_dfm_divide_by_255') && cfg.raw_dfm_divide_by_255
        I_e_cam = I_e_cam ./ 255;
    end
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
        if max(C1_cam(:), [], 'omitnan') > 2
            C1_cam = C1_cam ./ 255;
        end
    end
end

function fname = getC1TifFilename(frameIndex, cfg)

    fileNumber = cfg.C1_tif_first_file_number + ...
        (frameIndex - cfg.C1_tif_first_frame_index);

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

    C_flat = reshape(C_fit, h*w, nt);

    Ck_flat = interp1( ...
        double(cfg.fit_frame_centers(:)), ...
        C_flat.', ...
        double(frameIndex), ...
        'linear', ...
        'extrap');

    Ck_cam = reshape(Ck_flat.', h, w);
end
