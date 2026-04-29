clear; clc; close all;

%% =========================================================
% SCRIPT 2:
% Build frame-by-frame I_e' from saved Corr_mean
%
% Important:
%   - Computation is done in the same raw units as PASS 1.
%   - Variables saved for PASS 3 are 0--1:
%         I_e_cam
%         I_e_ray
%         Ie_prime_ray
%         Ie_prime_cam
%   - Raw-unit variables are also saved for debugging:
%         I_e_cam_raw_units
%         I_e_ray_raw_units
%         Ie_prime_ray_raw_units
%         Ie_prime_cam_raw_units
%% =========================================================

cfg = struct();

%% ---------------- Corr model file ----------------
cfg.corr_file = "V:\202311\w318\LIF-Processing\outputs\Corr_model\Corr_model_w318.mat";

%% ---------------- frame selection ----------------
cfg.selected_frames_override = 15000:20:16000;

%% ---------------- output ----------------
cfg.output_dir = "V:\202311\w318\LIF-Processing\outputs\IePrime_frames";

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

cfg.manifest_file = fullfile(cfg.output_dir, 'IePrime_manifest.mat');

%% ---------------- debug ----------------
cfg.debug = true;
cfg.debug_frames = [15000 15020 15040];

cfg.debug_dir = fullfile(cfg.output_dir, 'debug_script2');

if ~exist(cfg.debug_dir, 'dir')
    mkdir(cfg.debug_dir);
end

%% =========================================================
% LOAD Corr model
%% =========================================================
S = load(cfg.corr_file);

if ~isfield(S, 'Corr_mean')
    error('Corr_mean not found in %s.', cfg.corr_file);
end

Corr_mean = S.Corr_mean;

if isfield(S, 'Corr_std')
    Corr_std = S.Corr_std;
else
    Corr_std = NaN(size(Corr_mean));
    warning('Corr_std not found. Using NaN array.');
end

if isfield(S, 'processed_frames')
    processed_frames = S.processed_frames;
else
    processed_frames = [];
end

if isfield(S, 'cfg')
    cfg_pass1 = S.cfg;
else
    error('cfg from PASS 1 not found in Corr model file.');
end

if isfield(S, 'rayMask') && isfield(S.rayMask, 'valid')
    rayMask = S.rayMask;
else
    warning('rayMask not found. Using finite(Corr_mean) as rayMask.valid.');
    rayMask = struct();
    rayMask.valid = isfinite(Corr_mean);
end

%% =========================================================
% COPY IMPORTANT SETTINGS FROM PASS 1
%% =========================================================

% Geometry
cfg.px_per_mm = cfg_pass1.px_per_mm;
cfg.h_raw = cfg_pass1.h_raw;
cfg.w_raw = cfg_pass1.w_raw;

cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;

% Matrix row 1 is physical top.
% Physical z = 0 is bottom.
cfg.z_row_from_bottom_mm = ((cfg.h_raw-1):-1:0) / cfg.px_per_mm;

% Mapping files
cfg.x_map_file = cfg_pass1.x_map_file;
cfg.y_map_file = cfg_pass1.y_map_file;
cfg.mapfun = cfg_pass1.mapfun;

% Raw input settings from PASS 1
if isfield(cfg_pass1, 'raw_input_type')
    cfg.raw_input_type = 'dfm';
    cfg.fRaw = cfg_pass1.fRaw;
    cfg.fRaw_char = char(cfg.fRaw);
    cfg.raw_dfm_divide_by_255 = true;
else
    cfg.raw_input_type = 'dfm';
end

if isfield(cfg_pass1, 'fRaw')
    cfg.fRaw = cfg_pass1.fRaw;
    cfg.fRaw_char = char(cfg.fRaw);
end

rawFields = { ...
    'tif_dir', ...
    'tif_name_fmt', ...
    'tif_first_file_number', ...
    'tif_first_frame_index', ...
    'read_tif_as_double', ...
    'normalise_tif'};

for ii = 1:numel(rawFields)
    f = rawFields{ii};
    if isfield(cfg_pass1, f)
        cfg.(f) = cfg_pass1.(f);
    end
end

fprintf('\nLoaded Corr model from:\n%s\n', cfg.corr_file);
fprintf('PASS 2 raw input type inherited from PASS 1: %s\n', cfg.raw_input_type);

%% =========================================================
% SELECT FRAMES
%% =========================================================
if isempty(cfg.selected_frames_override)
    if isfield(cfg_pass1, 'selected_frames')
        selected_frames = cfg_pass1.selected_frames;
    else
        error('No selected_frames found in PASS 1 cfg.');
    end
else
    selected_frames = cfg.selected_frames_override;
end

selected_frames = selected_frames(:);
N_sel = numel(selected_frames);

fprintf('Number of output frames = %d\n', N_sel);

%% =========================================================
% RAW MOVIE INFO, ONLY NEEDED FOR DFM MODE
%% =========================================================
pRaw = [];

if strcmpi(cfg.raw_input_type, 'dfm')
    pRaw = df_dfm_info(cfg.fRaw_char);
end

%% =========================================================
% TEST FIRST RAW FRAME AND INFER SCALE
%% =========================================================
I_test_raw_units = readRawFrameCameraConsistent(selected_frames(1), cfg, pRaw);

if ~isequal(size(I_test_raw_units), [cfg.h_raw, cfg.w_raw])
    error('Raw image size mismatch. Expected %d x %d, got %d x %d.', ...
        cfg.h_raw, cfg.w_raw, size(I_test_raw_units,1), size(I_test_raw_units,2));
end

cfg.raw_to_pass3_scale = inferRawToPass3Scale(I_test_raw_units);

fprintf('\nRaw input stats from first selected frame:\n');
printImageStats('I_test_raw_units', I_test_raw_units);

fprintf('\nInferred raw_to_pass3_scale = %.6g\n', cfg.raw_to_pass3_scale);
fprintf('Saved Ie_prime_cam will be divided by this factor for PASS 3.\n');

%% =========================================================
% LOOP OVER FRAMES
%% =========================================================
saved_files = strings(N_sel,1);

for k = 1:N_sel

    frameIndex = selected_frames(k);

    fprintf('\nBuilding I_e'' for frame %d (%d / %d)\n', ...
        frameIndex, k, N_sel);

    %% ---- read raw camera-space frame in PASS 1 raw units ----
    I_e_cam_raw_units = readRawFrameCameraConsistent(frameIndex, cfg, pRaw);

    %% ---- map to ray space in raw units ----
    I_e_ray_raw_units = cfg.mapfun( ...
        I_e_cam_raw_units, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    I_e_ray_raw_units(~rayMask.valid) = NaN;

    %% ---- apply Corr_mean in raw units ----
    Ie_prime_ray_raw_units = Corr_mean .* I_e_ray_raw_units;
    Ie_prime_ray_raw_units(~rayMask.valid) = NaN;

    %% ---- inverse map back to camera space in raw units ----
    [Ie_prime_cam_raw_units, Ie_prime_cam_valid] = inverseRayToCamera( ...
        Ie_prime_ray_raw_units, cfg, rayMask);

    Ie_prime_cam_raw_units(~Ie_prime_cam_valid) = NaN;

    %% ---- orientation check in raw units ----
    [needFlip, r_same, r_flip] = detectVerticalFlipByMeanProfile( ...
        I_e_cam_raw_units, Ie_prime_cam_raw_units);

    fprintf('Orientation check: r_same = %.4f, r_flip = %.4f\n', ...
        r_same, r_flip);

    if needFlip
        warning('Ie_prime_cam appears vertically flipped. Applying flipud.');
        Ie_prime_cam_raw_units = flipud(Ie_prime_cam_raw_units);
        Ie_prime_cam_valid = flipud(Ie_prime_cam_valid);
    end

    %% =========================================================
    % Convert to PASS 3 scale, i.e. 0--1
    %% =========================================================
    I_e_cam      = I_e_cam_raw_units      ./ cfg.raw_to_pass3_scale;
    I_e_ray      = I_e_ray_raw_units      ./ cfg.raw_to_pass3_scale;
    Ie_prime_ray = Ie_prime_ray_raw_units ./ cfg.raw_to_pass3_scale;
    Ie_prime_cam = Ie_prime_cam_raw_units ./ cfg.raw_to_pass3_scale;

    % Keep invalid region as NaN.
    Ie_prime_cam(~Ie_prime_cam_valid) = NaN;

    %% ---- sanity check ----
    vals_pass3 = Ie_prime_cam(isfinite(Ie_prime_cam));

    if ~isempty(vals_pass3)
        p99_pass3 = prctile(vals_pass3, 99);

        fprintf('PASS 3 scale Ie_prime_cam p99 = %.6g\n', p99_pass3);

        if p99_pass3 > 2
            warning(['Ie_prime_cam p99 is > 2 after PASS 3 scaling. ', ...
                     'This is not a normal 0--1 image. ', ...
                     'Corr_mean may have been built with inconsistent scaling or alpha.']);
        end
    end

    %% ---------------- DEBUG SCRIPT 2 ----------------
    debug_this_frame = cfg.debug && ismember(frameIndex, cfg.debug_frames);

    fprintf('[DEBUG CHECK] frame %d: debug_this_frame = %d\n', ...
        frameIndex, debug_this_frame);

    if debug_this_frame

        fprintf('\nDebug stats for frame %d:\n', frameIndex);
        printImageStats('I_e_cam_raw_units', I_e_cam_raw_units);
        printImageStats('I_e_cam_PASS3_0to1', I_e_cam);
        printImageStats('I_e_ray_PASS3_0to1', I_e_ray);
        printImageStats('Corr_mean', Corr_mean);
        printImageStats('Ie_prime_ray_raw_units', Ie_prime_ray_raw_units);
        printImageStats('Ie_prime_cam_raw_units', Ie_prime_cam_raw_units);
        printImageStats('Ie_prime_cam_PASS3_0to1', Ie_prime_cam);

        % Separate colour scales.
        % Do not mix raw and Ie_prime colour scales.
        clim_Ie_cam          = robustClim(I_e_cam);
        clim_Ie_ray          = robustClim(I_e_ray);
        clim_Corr            = robustClim(Corr_mean);
        clim_Ieprime_ray     = robustClim(Ie_prime_ray);
        clim_Ieprime_cam     = robustClim(Ie_prime_cam);
        clim_Ie_cam_rawunits = robustClim(I_e_cam_raw_units);
        clim_Ieprime_raw     = robustClim(Ie_prime_cam_raw_units);

        saveDebugImage(I_e_cam, ...
            fullfile(cfg.debug_dir, sprintf('01_I_e_cam_PASS3_0to1_%05d.png', frameIndex)), ...
            sprintf('01 raw camera I_e, PASS3 0-1, frame %d', frameIndex), ...
            cfg, clim_Ie_cam);

        saveDebugImage(I_e_ray, ...
            fullfile(cfg.debug_dir, sprintf('02_I_e_ray_PASS3_0to1_%05d.png', frameIndex)), ...
            sprintf('02 mapped ray I_e, PASS3 0-1, frame %d', frameIndex), ...
            cfg, clim_Ie_ray);

        saveDebugImage(Corr_mean, ...
            fullfile(cfg.debug_dir, sprintf('03_Corr_mean_%05d.png', frameIndex)), ...
            sprintf('03 Corr mean used, frame %d', frameIndex), ...
            cfg, clim_Corr);

        saveDebugImage(Ie_prime_ray, ...
            fullfile(cfg.debug_dir, sprintf('04_Ie_prime_ray_PASS3_0to1_%05d.png', frameIndex)), ...
            sprintf('04 Ie prime ray, PASS3 0-1, frame %d', frameIndex), ...
            cfg, clim_Ieprime_ray);

        saveDebugImage(Ie_prime_cam, ...
            fullfile(cfg.debug_dir, sprintf('05_Ie_prime_cam_PASS3_0to1_%05d.png', frameIndex)), ...
            sprintf('05 Ie prime camera, PASS3 0-1, frame %d', frameIndex), ...
            cfg, clim_Ieprime_cam);

        saveDebugImage(double(Ie_prime_cam_valid), ...
            fullfile(cfg.debug_dir, sprintf('06_Ie_prime_cam_valid_%05d.png', frameIndex)), ...
            sprintf('06 Ie prime camera valid mask, frame %d', frameIndex), ...
            cfg, [0 1]);

        saveDebugImage(I_e_cam_raw_units, ...
            fullfile(cfg.debug_dir, sprintf('07_I_e_cam_raw_units_%05d.png', frameIndex)), ...
            sprintf('07 raw camera I_e, raw units, frame %d', frameIndex), ...
            cfg, clim_Ie_cam_rawunits);

        saveDebugImage(Ie_prime_cam_raw_units, ...
            fullfile(cfg.debug_dir, sprintf('08_Ie_prime_cam_raw_units_%05d.png', frameIndex)), ...
            sprintf('08 Ie prime camera, raw units, frame %d', frameIndex), ...
            cfg, clim_Ieprime_raw);
    end

    %% ---- save one frame per MAT ----
    outFile = fullfile(cfg.output_dir, sprintf('Ie_prime_cam_frame_%05d.mat', frameIndex));

    save(outFile, ...
        'frameIndex', ...
        ...
        'I_e_cam', ...
        'I_e_ray', ...
        'Ie_prime_ray', ...
        'Ie_prime_cam', ...
        'Ie_prime_cam_valid', ...
        ...
        'I_e_cam_raw_units', ...
        'I_e_ray_raw_units', ...
        'Ie_prime_ray_raw_units', ...
        'Ie_prime_cam_raw_units', ...
        ...
        'r_same', ...
        'r_flip', ...
        'needFlip', ...
        '-v7.3');

    saved_files(k) = string(outFile);

    fprintf('Saved:\n%s\n', outFile);
end

%% =========================================================
% SAVE MANIFEST
%% =========================================================
save(cfg.manifest_file, ...
    'selected_frames', ...
    'saved_files', ...
    'cfg', ...
    'cfg_pass1', ...
    'Corr_mean', ...
    'Corr_std', ...
    'processed_frames', ...
    '-v7.3');

fprintf('\nSaved IePrime manifest:\n%s\n', cfg.manifest_file);

%% =========================================================
% LOCAL FUNCTIONS
%% =========================================================

function I_e_cam = readRawFrameCameraConsistent(frameIndex, cfg, pRaw)

    if isfield(cfg, 'raw_input_type') && strcmpi(cfg.raw_input_type, 'tif_sequence')

        fname = getRawTifFilename(frameIndex, cfg);

        if ~isfile(fname)
            error('Raw tif file not found for frame %d:\n%s', frameIndex, fname);
        end

        I0 = imread(fname);

        if ndims(I0) == 3
            I0 = I0(:,:,1);
        end

        if isfield(cfg, 'read_tif_as_double') && cfg.read_tif_as_double
            I_e_cam = double(I0);
        else
            I_e_cam = double(I0);
        end

        if isfield(cfg, 'normalise_tif') && cfg.normalise_tif
            I_e_cam = I_e_cam ./ 255;
        end

    else

        if ~isfield(cfg, 'fRaw_char')
            error('DFM mode requested, but cfg.fRaw_char is missing.');
        end

        f1 = fopen(cfg.fRaw_char, 'r');

        if f1 < 0
            error('Could not open raw movie file: %s', cfg.fRaw_char);
        end

        exp = df_dfm_read(f1, frameIndex, pRaw);
        fclose(f1);

        I_e_cam = double(exp(:,:,1,1));

        % Stefan's original chain usually uses /255 for dfm input.
        % If PASS 1 used dfm and did not otherwise specify scale,
        % keep dfm as 0--1 here.
        if max(I_e_cam(:), [], 'omitnan') > 2
            I_e_cam = I_e_cam ./ 255;
        end
    end
end

function fname = getRawTifFilename(frameIndex, cfg)

    fileNumber = cfg.tif_first_file_number + ...
        (frameIndex - cfg.tif_first_frame_index);

    fname = fullfile(cfg.tif_dir, sprintf(char(cfg.tif_name_fmt), fileNumber));
end

function scale = inferRawToPass3Scale(A)

    A = double(A);
    vals = A(isfinite(A));

    if isempty(vals)
        scale = 1;
        return;
    end

    p99 = prctile(vals, 99);

    if p99 > 1000
        scale = 65535;
    elseif p99 > 2
        scale = 255;
    else
        scale = 1;
    end
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
        ylabel('row');
        xlabel('column');
    end

    axis image;
    set(gca, 'YDir', 'normal');
    colorbar;
    title(figTitle, 'Interpreter', 'none');

    if nargin >= 5 && ~isempty(clim_use)
        if all(isfinite(clim_use)) && clim_use(2) > clim_use(1)
            caxis(clim_use);
        end
    else
        vals = A(isfinite(A));
        if ~isempty(vals)
            lo = prctile(vals(:), 1);
            hi = prctile(vals(:), 99);
            if isfinite(lo) && isfinite(hi) && hi > lo
                caxis([lo hi]);
            end
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

function [needFlip, r_same, r_flip] = detectVerticalFlipByMeanProfile(I_ref, I_test)

    I_ref  = double(I_ref);
    I_test = double(I_test);

    prof_ref  = mean(I_ref,  2, 'omitnan');
    prof_test = mean(I_test, 2, 'omitnan');

    ok_same = isfinite(prof_ref) & isfinite(prof_test);

    if nnz(ok_same) < 20
        r_same = NaN;
        r_flip = NaN;
        needFlip = false;
        return;
    end

    r_same = corr(prof_ref(ok_same), prof_test(ok_same));

    prof_test_flip = flipud(prof_test);
    ok_flip = isfinite(prof_ref) & isfinite(prof_test_flip);

    if nnz(ok_flip) < 20
        r_flip = NaN;
        needFlip = false;
        return;
    end

    r_flip = corr(prof_ref(ok_flip), prof_test_flip(ok_flip));

    needFlip = isfinite(r_same) && isfinite(r_flip) && (r_flip > r_same + 0.15);
end