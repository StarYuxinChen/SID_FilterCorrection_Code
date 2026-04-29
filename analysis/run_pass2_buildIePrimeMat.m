clear; clc; close all;

%% =========================================================
% SCRIPT 2:
% Build frame-by-frame I_e' from saved Corr_mean
%% =========================================================

cfg = struct();

%% ---------------- raw input ----------------
cfg.fRaw = "V:\202311\w318\LIF-Processing\inputs\CamC_dimmer.dfm";
cfg.fRaw_char = char(cfg.fRaw);

cfg.x_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_x_map.txt";
cfg.y_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_y_map.txt";
cfg.mapfun = @mapTo;

cfg.px_per_mm = 22;
cfg.w_raw = 3320;
cfg.h_raw = 1024;
cfg.x_raw_mm = (0:cfg.w_raw-1) / cfg.px_per_mm;

% Important:
% Matrix row 1 is camera/top row.
% Physical z=0 is bottom, so row 1 should have the largest z value.
cfg.z_row_from_bottom_mm = ((cfg.h_raw-1):-1:0) / cfg.px_per_mm;

%% ---------------- Corr model file ----------------
cfg.corr_file = "V:\202311\w318\LIF-Processing\outputs\Corr_model\Corr_model_w318.mat";

%% ---------------- output frame selection ----------------
% By default use the same frames as pass 1
cfg.selected_frames_override = [15000:20:16000];  
% Example if needed:
% cfg.selected_frames_override = 15000:20:20000;


%% ---------------- output ----------------
cfg.output_dir = "V:\202311\w318\LIF-Processing\outputs\IePrime_frames";
if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

cfg.manifest_file = fullfile(cfg.output_dir, 'IePrime_manifest.mat');


%% =========================================================
% LOAD Corr model
%% =========================================================
S = load(cfg.corr_file, 'Corr_mean', 'Corr_std', 'processed_frames', 'cfg', 'rayMask');
Corr_mean = S.Corr_mean;
rayMask   = S.rayMask;

cfg_pass1 = S.cfg;

if isempty(cfg.selected_frames_override)
    selected_frames = cfg_pass1.selected_frames;
else
    selected_frames = cfg.selected_frames_override;
end

N_sel = numel(selected_frames);

fprintf('\nLoaded Corr model from:\n%s\n', cfg.corr_file);
fprintf('Number of output frames = %d\n', N_sel);
%% ---------------- debug setting ----------------
cfg.debug_frames = selected_frames(1);   
% 或者你想指定多帧：
% cfg.debug_frames = [15000 15020 15040];

cfg.debug_dir = fullfile(cfg.output_dir, 'debug_script2');

if ~isfolder(cfg.debug_dir)
    mkdir(cfg.debug_dir);
end

fprintf('\nDebug images will be saved to:\n%s\n', cfg.debug_dir);
fprintf('Debug frames are:\n');
disp(cfg.debug_frames);

%% =========================================================
% RAW MOVIE INFO
%% =========================================================
pRaw = df_dfm_info(cfg.fRaw_char);

%% =========================================================
% LOOP OVER FRAMES
%% =========================================================
saved_files = strings(N_sel,1);

for k = 1:N_sel
    frameIndex = selected_frames(k);

    fprintf('Building I_e'' for frame %d (%d / %d)\n', frameIndex, k, N_sel);

    % ---- read raw camera-space frame ----
    I_e_cam = readRawFrameCamera(frameIndex, cfg, pRaw);

    % ---- map to ray space ----
    I_e_ray = cfg.mapfun(I_e_cam, cfg.x_map_file, cfg.y_map_file, cfg.h_raw, cfg.w_raw, false);
    I_e_ray(~rayMask.valid) = NaN;

    % ---- apply Corr_mean ----
    Ie_prime_ray = Corr_mean .* I_e_ray;
    Ie_prime_ray(~rayMask.valid) = NaN;

    % ---- inverse map back to camera space ----
    [Ie_prime_cam, Ie_prime_cam_valid] = inverseRayToCamera(Ie_prime_ray, cfg, rayMask);
    
    % optional clean-up
    Ie_prime_cam(~Ie_prime_cam_valid) = NaN;
    
    % ---- check whether inverse-mapped Ie_prime_cam is vertically flipped ----
    [needFlip, r_same, r_flip] = detectVerticalFlipByMeanProfile(I_e_cam, Ie_prime_cam);
    
    fprintf('Orientation check for frame %d: r_same = %.4f, r_flip = %.4f\n', ...
        frameIndex, r_same, r_flip);
    
    if needFlip
        warning('Ie_prime_cam appears vertically flipped relative to I_e_cam. Applying flipud to Ie_prime_cam and mask.');
        Ie_prime_cam = flipud(Ie_prime_cam);
        Ie_prime_cam_valid = flipud(Ie_prime_cam_valid);
    end

    
    debug_this_frame = (frameIndex == selected_frames(1));
    fprintf('[DEBUG CHECK] frameIndex = %d, selected_frames(1) = %d, debug_this_frame = %d\n', ...
        frameIndex, selected_frames(1), debug_this_frame);
    %% ---------------- DEBUG SCRIPT 2 ----------------
    printImageStats('I_e_cam', I_e_cam);
    printImageStats('I_e_ray', I_e_ray);
    printImageStats('Corr_mean', Corr_mean);
    printImageStats('Ie_prime_ray', Ie_prime_ray);
    printImageStats('Ie_prime_cam', Ie_prime_cam);

    debug_this_frame = ismember(frameIndex, cfg.debug_frames);

    fprintf('[DEBUG CHECK] frame %d: debug_this_frame = %d\n', ...
        frameIndex, debug_this_frame);
    % 或者指定某一帧：
    % debug_this_frame = (frameIndex == 15000);
    
    if debug_this_frame
        debug_dir = cfg.debug_dir;
    
        % Use same colour scale for raw camera and inverse-mapped Ie'
        camVals = [I_e_cam(:); Ie_prime_cam(:)];
        camVals = camVals(isfinite(camVals));
    
        if ~isempty(camVals)
            clim_cam = prctile(camVals, [1 99]);
        else
            clim_cam = [];
        end
    
        % Use same colour scale for ray-space raw and ray-space Ie'
        rayVals = [I_e_ray(:); Ie_prime_ray(:)];
        rayVals = rayVals(isfinite(rayVals));
    
        if ~isempty(rayVals)
            clim_ray = prctile(rayVals, [1 99]);
        else
            clim_ray = [];
        end
    
        saveDebugImage(I_e_cam, ...
            fullfile(debug_dir, sprintf('01_I_e_cam_raw_%05d.png', frameIndex)), ...
            sprintf('01 raw camera I_e, frame %d', frameIndex), ...
            cfg, clim_cam);
    
        saveDebugImage(I_e_ray, ...
            fullfile(debug_dir, sprintf('02_I_e_ray_%05d.png', frameIndex)), ...
            sprintf('02 mapped ray I_e, frame %d', frameIndex), ...
            cfg, clim_ray);
    
        saveDebugImage(Corr_mean, ...
            fullfile(debug_dir, sprintf('03_Corr_mean_%05d.png', frameIndex)), ...
            sprintf('03 Corr mean used, frame %d', frameIndex), ...
            cfg, []);
    
        saveDebugImage(Ie_prime_ray, ...
            fullfile(debug_dir, sprintf('04_Ie_prime_ray_%05d.png', frameIndex)), ...
            sprintf('04 Ie prime ray, frame %d', frameIndex), ...
            cfg, clim_ray);
    
        saveDebugImage(Ie_prime_cam, ...
            fullfile(debug_dir, sprintf('05_Ie_prime_cam_inverse_mapped_%05d.png', frameIndex)), ...
            sprintf('05 Ie prime camera inverse mapped, frame %d', frameIndex), ...
            cfg, clim_cam);
    
        saveDebugImage(double(Ie_prime_cam_valid), ...
            fullfile(debug_dir, sprintf('06_Ie_prime_cam_valid_%05d.png', frameIndex)), ...
            sprintf('06 Ie prime camera valid mask, frame %d', frameIndex), ...
            cfg, [0 1]);
    end
    % ---- save one frame per MAT ----
    outFile = fullfile(cfg.output_dir, sprintf('Ie_prime_cam_frame_%05d.mat', frameIndex));

    save(outFile, ...
        'frameIndex', ...
        'I_e_cam', ...
        'I_e_ray', ...
        'Ie_prime_ray', ...
        'Ie_prime_cam', ...
        'Ie_prime_cam_valid', ...
        '-v7.3');

    saved_files(k) = string(outFile);
    % outFile = char(outFile);
    % 
    % drawnow;
    % exportgraphics(fig, outFile, 'Resolution', 200);
    % close(fig);
    % 
    % if isfile(outFile)
    %     fprintf('Saved debug image: %s\n', outFile);
    % else
    %     warning('Debug image was NOT created: %s', outFile);
    % end
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
    '-v7.3');

fprintf('\nSaved IePrime manifest:\n%s\n', cfg.manifest_file);

%% =========================================================
% local function
%% =========================================================
function I_e_cam = readRawFrameCamera(frameIndex, cfg, pRaw)
    f1 = fopen(cfg.fRaw_char, 'r');
    if f1 < 0
        error('Could not open raw movie file: %s', cfg.fRaw_char);
    end

    exp = df_dfm_read(f1, frameIndex, pRaw);
    fclose(f1);

    % assume grayscale movie scaled by /255
    I_e_cam = double(exp(:,:,1,1)) / 255;
end

function saveDebugImage(A, outFile, figTitle, cfg, clim_use)

    A = double(A);

    fig = figure('Visible', 'off');

    % Display in physical orientation:
    % row 1 = physical top;
    % bottom row = physical bottom;
    % z = 0 at physical bottom.
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

    exportgraphics(fig, outFile, 'Resolution', 200);
    close(fig);
end

function [needFlip, r_same, r_flip] = detectVerticalFlipByMeanProfile(I_ref, I_test)

    I_ref  = double(I_ref);
    I_test = double(I_test);

    % Use vertical mean profiles.
    % This is robust because raw and Ie_prime should still have similar
    % large-scale vertical structure, even if the intensity is corrected.
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

    % Only flip if the flipped profile is clearly better.
    % The margin avoids accidental flipping due to noise or weak contrast.
    needFlip = isfinite(r_same) && isfinite(r_flip) && (r_flip > r_same + 0.15);
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