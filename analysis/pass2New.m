clear; clc; close all;
fclose('all');

%% =========================================================
% PASS 2:
% Build frame-by-frame I_e' from saved Corr_mean
%
% Input:
%   Corr_mean from PASS 1:
%       Corr = I_f / I_e
%
% Then for each raw frame:
%   I_e_ray       = mapTo(I_e_cam)
%   I_e'_ray      = Corr_mean .* I_e_ray
%   I_e'_cam      = inverse map I_e'_ray back to camera space
%
% Important:
%   - I_e is original raw camera image from CamC_dimmer.dfm.
%   - Keep full image size: 1024 x 3320.
%   - Use crop/mask from PASS 1:
%       x columns = 30:3300
%       y rows    = 20:1015
%   - Outside valid region is saved as NaN.
%   - Do NOT flip data. Only flip for physical plotting.
%% =========================================================

%% =========================================================
% BASIC CONFIG
%% =========================================================
cfg = struct();

cfg.corr_file = "V:\202311\w318\LIF-Processing\outputs\Corr_model\Corr_model_w318.mat";

% Save only a few frames first so you can inspect the result.
cfg.frame_list = [15000 15020 15040];

% Later, you can change to:
% cfg.frame_list = 15000:20:18420;

cfg.output_dir = "V:\202311\w318\LIF-Processing\outputs\IePrime_frames_cropMasked_test";

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

cfg.manifest_file = fullfile(cfg.output_dir, "IePrime_manifest.mat");

%% ---------------- debug settings ----------------
cfg.save_debug_png = true;
cfg.debug_frames = cfg.frame_list;

cfg.debug_dir = fullfile(cfg.output_dir, "debug_pass2_IePrime");

if cfg.save_debug_png && ~exist(cfg.debug_dir, 'dir')
    mkdir(cfg.debug_dir);
end

%% ---------------- inverse mapping settings ----------------
% When inverse-mapping a valid mask, interpolation gives values between 0 and 1.
% 0.5 is permissive; 0.99 is stricter.
cfg.inverse_valid_threshold = 0.5;

% If true, save an extra version where invalid regions are filled by original I_e.
% This is useful for visual checking and later Stefan input experiments.
cfg.save_filled_preview = true;

%% =========================================================
% LOAD CORR MODEL FROM PASS 1
%% =========================================================
fprintf('\nLoading Corr model from:\n%s\n', cfg.corr_file);

S = load(cfg.corr_file);

if ~isfield(S, 'Corr_mean')
    error('Corr_mean not found in corr_file.');
end

Corr_mean = double(S.Corr_mean);

if isfield(S, 'Corr_std')
    Corr_std = double(S.Corr_std);
else
    Corr_std = NaN(size(Corr_mean));
    warning('Corr_std not found. Using NaN array.');
end

if isfield(S, 'cfg')
    cfg_pass1 = S.cfg;
else
    error('PASS 1 cfg not found in corr_file.');
end

if isfield(S, 'rayMask')
    rayMask = S.rayMask;
else
    warning('rayMask not found. Using finite(Corr_mean) as rayMask.valid.');
    rayMask = struct();
    rayMask.valid = isfinite(Corr_mean);
end

if ~isfield(rayMask, 'valid')
    rayMask.valid = isfinite(Corr_mean);
end

rayMask.valid = logical(rayMask.valid) & isfinite(Corr_mean);

fprintf('\nCorr_mean loaded.\n');
printImageStats('Corr_mean', Corr_mean);
fprintf('rayMask.valid fraction = %.4f\n', nnz(rayMask.valid) / numel(rayMask.valid));

%% =========================================================
% INHERIT GEOMETRY AND PATHS FROM PASS 1
%% =========================================================
cfg.px_per_mm = cfg_pass1.px_per_mm;

cfg.h_raw = size(Corr_mean, 1);
cfg.w_raw = size(Corr_mean, 2);

cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;

% For physical display only:
% z=0 is physical bottom.
cfg.z_plot_mm = (0:cfg.h_raw-1) / cfg.px_per_mm;

% Original raw camera movie
cfg.fRaw = cfg_pass1.fRaw;
cfg.fRaw_char = char(cfg.fRaw);

if isfield(cfg_pass1, 'raw_dfm_divide_by_255')
    cfg.raw_dfm_divide_by_255 = cfg_pass1.raw_dfm_divide_by_255;
else
    cfg.raw_dfm_divide_by_255 = true;
end

% Mapping files
cfg.x_map_file = cfg_pass1.x_map_file;
cfg.y_map_file = cfg_pass1.y_map_file;
cfg.mapfun = @mapTo;

%% =========================================================
% INHERIT / REBUILD CROP MASK
%% =========================================================
if isfield(cfg_pass1, 'crop_x1')
    cfg.crop_x1 = cfg_pass1.crop_x1;
    cfg.crop_x2 = cfg_pass1.crop_x2;
    cfg.crop_y1 = cfg_pass1.crop_y1;
    cfg.crop_y2 = cfg_pass1.crop_y2;
else
    cfg.crop_x1 = 30;
    cfg.crop_x2 = 3300;
    cfg.crop_y1 = 20;
    cfg.crop_y2 = 1015;
end

cfg.cropMask_cam = false(cfg.h_raw, cfg.w_raw);
cfg.cropMask_cam(cfg.crop_y1:cfg.crop_y2, cfg.crop_x1:cfg.crop_x2) = true;

fprintf('\nCamera crop region inherited/rebuilt:\n');
fprintf('  x columns = %d:%d\n', cfg.crop_x1, cfg.crop_x2);
fprintf('  y rows    = %d:%d\n', cfg.crop_y1, cfg.crop_y2);
fprintf('Camera crop valid fraction = %.4f\n', nnz(cfg.cropMask_cam) / numel(cfg.cropMask_cam));

%% =========================================================
% RAW MOVIE INFO
%% =========================================================
fprintf('\nReading raw DFM movie info from:\n%s\n', cfg.fRaw);

pRaw = df_dfm_info(cfg.fRaw_char);

fidRaw = fopen(cfg.fRaw_char, 'r');

if fidRaw < 0
    error('Could not open raw movie file: %s', cfg.fRaw_char);
end

cleanupRaw = onCleanup(@() fclose(fidRaw));

%% =========================================================
% QUICK CHECK FIRST FRAME
%% =========================================================
I_test = readOriginalIeFromDfm_open(fidRaw, cfg.frame_list(1), cfg, pRaw);

if ~isequal(size(I_test), [cfg.h_raw, cfg.w_raw])
    error('Raw frame size mismatch. Expected %d x %d, got %d x %d.', ...
        cfg.h_raw, cfg.w_raw, size(I_test,1), size(I_test,2));
end

fprintf('\nFirst raw frame check:\n');
printImageStats('I_e_test', I_test);

%% =========================================================
% SAVE GLOBAL MASK DEBUG
%% =========================================================
if cfg.save_debug_png
    saveDebugImagePhysical(double(cfg.cropMask_cam), ...
        fullfile(cfg.debug_dir, "00_cropMask_camera.png"), ...
        "00 camera crop mask, x=columns, y=rows", ...
        cfg, [0 1]);

    saveDebugImagePhysical(double(rayMask.valid), ...
        fullfile(cfg.debug_dir, "00_rayMask_valid.png"), ...
        "00 final ray-space valid mask from PASS 1", ...
        cfg, [0 1]);

    saveDebugImagePhysical(Corr_mean, ...
        fullfile(cfg.debug_dir, "00_Corr_mean.png"), ...
        "00 Corr mean from PASS 1", ...
        cfg, robustClim(Corr_mean));

    saveDebugImagePhysical(Corr_std, ...
        fullfile(cfg.debug_dir, "00_Corr_std.png"), ...
        "00 Corr std from PASS 1", ...
        cfg, robustClim(Corr_std));
end

%% =========================================================
% LOOP OVER FRAMES
%% =========================================================
nFrames = numel(cfg.frame_list);
saved_files = strings(nFrames, 1);

fprintf('\nStarting PASS 2 for %d frames...\n', nFrames);

for k = 1:nFrames

    frameIndex = cfg.frame_list(k);

    fprintf('\nBuilding I_e'' for frame %d (%d / %d)\n', ...
        frameIndex, k, nFrames);

    %% ---------------------------------------------------------
    % 1. Read original raw camera image I_e
    %% ---------------------------------------------------------
    I_e_cam_full = readOriginalIeFromDfm_open(fidRaw, frameIndex, cfg, pRaw);

    % For saved camera diagnostic, keep outside crop as NaN.
    I_e_cam = I_e_cam_full;
    I_e_cam(~cfg.cropMask_cam) = NaN;

    %% ---------------------------------------------------------
    % 2. Map I_e to ray space
    %
    % Important:
    % Map full image first, then apply rayMask.valid.
    % Do not map a NaN-cropped camera image, otherwise NaNs can smear into
    % the ray-space interior through interpolation.
    %% ---------------------------------------------------------
    I_e_ray = cfg.mapfun( ...
        I_e_cam_full, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    I_e_ray(~rayMask.valid) = NaN;
    I_e_ray(~isfinite(I_e_ray)) = NaN;

    %% ---------------------------------------------------------
    % 3. Build I_e' in ray space
    %% ---------------------------------------------------------
    Ie_prime_ray = Corr_mean .* I_e_ray;

    Ie_prime_ray(~rayMask.valid) = NaN;
    Ie_prime_ray(~isfinite(Ie_prime_ray)) = NaN;

    %% ---------------------------------------------------------
    % 4. Inverse map I_e'_ray back to camera space
    %
    % To avoid NaN interpolation artefacts:
    %   - inverse-map data with invalid pixels set to 0
    %   - inverse-map a valid mask separately
    %   - apply the inverse valid mask afterwards
    %% ---------------------------------------------------------
    [Ie_prime_cam, Ie_prime_cam_valid, inverse_valid_weight] = inverseRayToCameraStable( ...
        Ie_prime_ray, ...
        cfg, ...
        rayMask);

    % Also enforce original camera crop.
    Ie_prime_cam_valid = Ie_prime_cam_valid & cfg.cropMask_cam;

    Ie_prime_cam(~Ie_prime_cam_valid) = NaN;

    %% ---------------------------------------------------------
    % 5. Optional filled version for preview / possible Stefan tests
    %
    % This is NOT the main scientific variable.
    % It just avoids NaN boundaries when viewing or when a downstream code
    % cannot accept NaNs.
    %% ---------------------------------------------------------
    Ie_prime_cam_filled = Ie_prime_cam;

    if cfg.save_filled_preview
        fillMask = ~isfinite(Ie_prime_cam_filled);
        Ie_prime_cam_filled(fillMask) = I_e_cam_full(fillMask);
    end

    %% ---------------------------------------------------------
    % 6. Print stats
    %% ---------------------------------------------------------
    printImageStats('I_e_cam', I_e_cam);
    printImageStats('I_e_ray', I_e_ray);
    printImageStats('Ie_prime_ray', Ie_prime_ray);
    printImageStats('Ie_prime_cam', Ie_prime_cam);
    printImageStats('Ie_prime_cam_filled', Ie_prime_cam_filled);

    %% ---------------------------------------------------------
    % 7. Save MAT file
    %% ---------------------------------------------------------
    outFile = fullfile(cfg.output_dir, sprintf("Ie_prime_cam_frame_%05d.mat", frameIndex));

    save(outFile, ...
        'frameIndex', ...
        ...
        'I_e_cam_full', ...
        'I_e_cam', ...
        'I_e_ray', ...
        ...
        'Corr_mean', ...
        'Corr_std', ...
        ...
        'Ie_prime_ray', ...
        'Ie_prime_cam', ...
        'Ie_prime_cam_valid', ...
        'Ie_prime_cam_filled', ...
        'inverse_valid_weight', ...
        ...
        'rayMask', ...
        'cfg', ...
        'cfg_pass1', ...
        '-v7.3');

    saved_files(k) = string(outFile);

    fprintf('Saved MAT:\n%s\n', outFile);

    %% ---------------------------------------------------------
    % 8. Save debug figures
    %% ---------------------------------------------------------
    if cfg.save_debug_png && ismember(frameIndex, cfg.debug_frames)

        saveDebugImagePhysical(I_e_cam, ...
            fullfile(cfg.debug_dir, sprintf("01_Ie_cam_cropMasked_%05d.png", frameIndex)), ...
            sprintf("01 I_e camera crop-masked, frame %d", frameIndex), ...
            cfg, robustClim(I_e_cam));

        saveDebugImagePhysical(I_e_ray, ...
            fullfile(cfg.debug_dir, sprintf("02_Ie_ray_%05d.png", frameIndex)), ...
            sprintf("02 I_e ray, frame %d", frameIndex), ...
            cfg, robustClim(I_e_ray));

        saveDebugImagePhysical(Corr_mean, ...
            fullfile(cfg.debug_dir, sprintf("03_Corr_mean_%05d.png", frameIndex)), ...
            sprintf("03 Corr mean used, frame %d", frameIndex), ...
            cfg, robustClim(Corr_mean));

        saveDebugImagePhysical(Ie_prime_ray, ...
            fullfile(cfg.debug_dir, sprintf("04_Ie_prime_ray_%05d.png", frameIndex)), ...
            sprintf("04 I_e' ray = Corr_mean * I_e_ray, frame %d", frameIndex), ...
            cfg, robustClim(Ie_prime_ray));

        saveDebugImagePhysical(Ie_prime_cam, ...
            fullfile(cfg.debug_dir, sprintf("05_Ie_prime_cam_%05d.png", frameIndex)), ...
            sprintf("05 I_e' camera inverse-mapped, frame %d", frameIndex), ...
            cfg, robustClim(Ie_prime_cam));

        saveDebugImagePhysical(Ie_prime_cam_filled, ...
            fullfile(cfg.debug_dir, sprintf("06_Ie_prime_cam_filled_%05d.png", frameIndex)), ...
            sprintf("06 I_e' camera filled outside valid region, frame %d", frameIndex), ...
            cfg, robustClim(Ie_prime_cam_filled));

        saveDebugImagePhysical(double(Ie_prime_cam_valid), ...
            fullfile(cfg.debug_dir, sprintf("07_Ie_prime_cam_valid_%05d.png", frameIndex)), ...
            sprintf("07 I_e' camera valid mask, frame %d", frameIndex), ...
            cfg, [0 1]);

        saveDebugImagePhysical(inverse_valid_weight, ...
            fullfile(cfg.debug_dir, sprintf("08_inverse_valid_weight_%05d.png", frameIndex)), ...
            sprintf("08 inverse-mapped valid weight, frame %d", frameIndex), ...
            cfg, [0 1]);
    end

    openFids = fopen('all');
    fprintf('Currently open files = %d\n', numel(openFids));
end

%% =========================================================
% SAVE MANIFEST
%% =========================================================
save(cfg.manifest_file, ...
    'cfg', ...
    'cfg_pass1', ...
    'rayMask', ...
    'saved_files', ...
    '-v7.3');

fprintf('\nPASS 2 finished.\n');
fprintf('Saved manifest:\n%s\n', cfg.manifest_file);
fprintf('Output folder:\n%s\n', cfg.output_dir);

%% =========================================================
% LOCAL FUNCTIONS
%% =========================================================

function I_e_cam = readOriginalIeFromDfm_open(fidRaw, frameIndex, cfg, pRaw)

    exp = df_dfm_read(fidRaw, frameIndex, pRaw);

    I_e_cam = double(exp(:,:,1,1));

    if isfield(cfg, 'raw_dfm_divide_by_255') && cfg.raw_dfm_divide_by_255
        I_e_cam = I_e_cam ./ 255;
    end

    I_e_cam(~isfinite(I_e_cam)) = NaN;
end

function [Ie_prime_cam, valid_cam, valid_weight_cam] = inverseRayToCameraStable(Ie_prime_ray, cfg, rayMask)

    valid_ray = rayMask.valid & isfinite(Ie_prime_ray);

    %% ---------------------------------------------------------
    % Inverse map data
    %% ---------------------------------------------------------
    A = Ie_prime_ray;
    A(~valid_ray) = 0;

    Ie_prime_cam = cfg.mapfun( ...
        A, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        true);

    %% ---------------------------------------------------------
    % Inverse map valid mask
    %% ---------------------------------------------------------
    valid_weight_cam = cfg.mapfun( ...
        double(valid_ray), ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        true);

    valid_weight_cam(~isfinite(valid_weight_cam)) = 0;

    valid_cam = valid_weight_cam >= cfg.inverse_valid_threshold;

    Ie_prime_cam(~valid_cam) = NaN;
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

function saveDebugImagePhysical(A, outFile, figTitle, cfg, clim_use)

    A = double(A);

    fig = figure('Visible', 'off');

    %% ---------------------------------------------------------
    % IMPORTANT:
    % Data are stored in matrix orientation:
    %   row 1 = camera/top row
    %   row h = physical bottom row
    %
    % For physical display only:
    %   flipud(A), then z_plot_mm = 0 at physical bottom.
    %
    % This flip is ONLY for plotting.
    % The saved MAT data are NOT flipped.
    %% ---------------------------------------------------------
    if size(A,1) == cfg.h_raw && size(A,2) == cfg.w_raw

        imagesc(cfg.x_raw_mm, cfg.z_plot_mm, flipud(A));
        xlabel('x (mm)');
        ylabel('z from bottom (mm)');
        set(gca, 'YDir', 'normal');

    else

        imagesc(A);
        xlabel('column');
        ylabel('row');
        set(gca, 'YDir', 'reverse');

    end

    axis image;
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
