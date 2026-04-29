%% =========================================================
% QC CHECK FOR PASS 1 CORR MODEL
% Checks:
%   1. TIF vs DFM scale/orientation
%   2. Ray-space consistency
%   3. I_f = I_sheet .* C_s
%   4. Corr = I_f ./ I_raw_ray
%   5. Corr_mean / Corr_std statistics
%% =========================================================

%% =========================================================
% QC CHECK FOR PASS 1 CORR MODEL
%% =========================================================

clc; close all;

% Do NOT use clear here if you just ran Script 1 and want to keep variables.

fprintf('\n=====================================================\n');
fprintf('QC CHECK: PASS 1 Corr model\n');
fprintf('=====================================================\n');

%% ---------------------------------------------------------
% Option A: if variables are not in workspace, load saved Corr model
%% ---------------------------------------------------------
if ~exist('cfg', 'var') || ~exist('Corr_mean', 'var') || ~exist('rayMask', 'var')

    corrFile = "V:\202311\w318\LIF-Processing\outputs\Corr_model\Corr_model_w318.mat";

    fprintf('\nWorkspace variables not found. Loading:\n%s\n', corrFile);

    S = load(corrFile);

    cfg = S.cfg;
    Corr_mean = S.Corr_mean;
    Corr_std = S.Corr_std;
    rayMask = S.rayMask;

    if isfield(S, 'Corr_count')
        Corr_count = S.Corr_count;
    end

    if isfield(S, 'C_fit')
        C_fit = S.C_fit;
    else
        error(['C_fit is not saved in Corr_model_w318.mat. ', ...
               'Please either run QC immediately after Script 1, ', ...
               'or modify Script 1 to save C_fit.']);
    end
end

%% ---------------------------------------------------------
% Rebuild pRaw if needed
%% ---------------------------------------------------------
if ~exist('pRaw', 'var')
    fprintf('\npRaw not found. Rebuilding pRaw from cfg.fRaw_char...\n');
    pRaw = df_dfm_info(cfg.fRaw_char);
end

%% ---------------------------------------------------------
% Final required-variable check
%% ---------------------------------------------------------
requiredVars = {'cfg', 'pRaw', 'C_fit', 'rayMask', 'Corr_mean', 'Corr_std'};

for i = 1:numel(requiredVars)
    if ~exist(requiredVars{i}, 'var')
        error('Required variable "%s" not found.', requiredVars{i});
    end
end

fprintf('\nAll required variables are available.\n');
%% ---------------------------------------------------------
% 1. Basic size checks
%% ---------------------------------------------------------
fprintf('\n=====================================================\n');
fprintf('1. Size checks\n');
fprintf('=====================================================\n');

fprintf('cfg.h_raw = %d\n', cfg.h_raw);
fprintf('cfg.w_raw = %d\n', cfg.w_raw);

fprintf('size(Corr_mean) = [%d, %d]\n', size(Corr_mean,1), size(Corr_mean,2));
fprintf('size(Corr_std)  = [%d, %d]\n', size(Corr_std,1),  size(Corr_std,2));
fprintf('size(rayMask.valid) = [%d, %d]\n', size(rayMask.valid,1), size(rayMask.valid,2));

assert(isequal(size(Corr_mean), [cfg.h_raw, cfg.w_raw]), ...
    'Corr_mean size does not match cfg.h_raw/cfg.w_raw.');

assert(isequal(size(Corr_std), [cfg.h_raw, cfg.w_raw]), ...
    'Corr_std size does not match cfg.h_raw/cfg.w_raw.');

assert(isequal(size(rayMask.valid), [cfg.h_raw, cfg.w_raw]), ...
    'rayMask.valid size does not match cfg.h_raw/cfg.w_raw.');

fprintf('Size checks passed.\n');

%% ---------------------------------------------------------
% 2. Corr_mean / Corr_std summary
%% ---------------------------------------------------------
fprintf('\n=====================================================\n');
fprintf('2. Corr_mean / Corr_std statistics\n');
fprintf('=====================================================\n');

validCorr = rayMask.valid & isfinite(Corr_mean);

printStats('Corr_mean valid region', Corr_mean(validCorr));
printStats('Corr_std valid region',  Corr_std(validCorr));

fprintf('\nValid fraction in Corr_mean = %.4f\n', nnz(validCorr) / numel(validCorr));

% Check extreme values
fracExtremeLow  = nnz(validCorr & Corr_mean < 0.1) / max(nnz(validCorr), 1);
fracExtremeHigh = nnz(validCorr & Corr_mean > 10)  / max(nnz(validCorr), 1);

fprintf('Fraction Corr_mean < 0.1 = %.6f\n', fracExtremeLow);
fprintf('Fraction Corr_mean > 10  = %.6f\n', fracExtremeHigh);

%% ---------------------------------------------------------
% 3. Recompute diagnostics for selected frames
%% ---------------------------------------------------------
fprintf('\n=====================================================\n');
fprintf('3. Per-frame diagnostic checks\n');
fprintf('=====================================================\n');

testFrames = [11000, 15000, 30000, 59000];

for ii = 1:numel(testFrames)

    frame = testFrames(ii);

    fprintf('\n-----------------------------------------------------\n');
    fprintf('Checking frame %d\n', frame);
    fprintf('-----------------------------------------------------\n');

    diag = computeFrameProductsFromFile(frame, cfg, pRaw, C_fit, rayMask);

    %% ---------------- camera-space input checks ----------------
    fprintf('\nCamera-space input statistics:\n');

    printStats('I_model_cam from tif', diag.I_model_cam(:));
    printStats('I_raw_cam from dfm',   diag.I_raw_cam(:));

    camValid = isfinite(diag.I_model_cam) & isfinite(diag.I_raw_cam);

    r_cam = localCorr(diag.I_model_cam(camValid), diag.I_raw_cam(camValid));
    fprintf('Correlation I_model_cam vs I_raw_cam = %.6f\n', r_cam);

    med_model = median(diag.I_model_cam(camValid), 'omitnan');
    med_raw   = median(diag.I_raw_cam(camValid), 'omitnan');

    fprintf('Median(I_model_cam) / Median(I_raw_cam) = %.6g\n', ...
        med_model / max(med_raw, eps));

    fprintf('\nInterpretation:\n');
    fprintf('  If this ratio is close to 1, tif and dfm are on similar intensity scale.\n');
    fprintf('  If this ratio is close to 255, dfm may be scaled to 0--1 while tif is 0--255.\n');

    %% ---------------- ray-space size checks ----------------
    fprintf('\nRay-space size checks:\n');

    assert(isequal(size(diag.I_model_ray), size(diag.I_raw_ray)), ...
        'I_model_ray and I_raw_ray sizes differ.');

    assert(isequal(size(diag.I_model_ray), size(diag.C_k_ray)), ...
        'I_model_ray and C_k_ray sizes differ.');

    assert(isequal(size(diag.I_model_ray), size(diag.C_s)), ...
        'I_model_ray and C_s sizes differ.');

    assert(isequal(size(diag.I_model_ray), size(diag.I_sheet)), ...
        'I_model_ray and I_sheet sizes differ.');

    assert(isequal(size(diag.I_model_ray), size(diag.I_f)), ...
        'I_model_ray and I_f sizes differ.');

    assert(isequal(size(diag.I_model_ray), size(diag.Corr)), ...
        'I_model_ray and Corr sizes differ.');

    fprintf('All ray-space arrays have matching size.\n');

    %% ---------------- ray-space statistics ----------------
    fprintf('\nRay-space statistics:\n');

    rayValid = rayMask.valid;

    printStats('I_model_ray', diag.I_model_ray(rayValid & isfinite(diag.I_model_ray)));
    printStats('I_raw_ray',   diag.I_raw_ray(rayValid & isfinite(diag.I_raw_ray)));
    printStats('C_k_ray',     diag.C_k_ray(rayValid & isfinite(diag.C_k_ray)));
    printStats('C_s',         diag.C_s(rayValid & isfinite(diag.C_s)));
    printStats('I_sheet',     diag.I_sheet(rayValid & isfinite(diag.I_sheet)));
    printStats('I_f',         diag.I_f(rayValid & isfinite(diag.I_f)));
    printStats('Corr',        diag.Corr(rayValid & isfinite(diag.Corr)));

    %% ---------------- formula check 1: I_f = I_sheet .* C_s ----------------
    fprintf('\nFormula check 1: I_f = I_sheet .* C_s\n');

    I_f_expected = diag.I_sheet .* diag.C_s;

    validIf = rayMask.valid & ...
              isfinite(diag.I_f) & ...
              isfinite(I_f_expected);

    absErrIf = abs(diag.I_f(validIf) - I_f_expected(validIf));
    relErrIf = absErrIf ./ max(abs(I_f_expected(validIf)), cfg.min_positive_value);

    fprintf('max abs error = %.6g\n', max(absErrIf));
    fprintf('p99 rel error = %.6g\n', prctile(relErrIf, 99));
    fprintf('max rel error = %.6g\n', max(relErrIf));

    %% ---------------- formula check 2: Corr = I_f ./ I_raw_ray ----------------
    fprintf('\nFormula check 2: Corr = I_f ./ I_raw_ray\n');

    Corr_expected = nan(size(diag.Corr));

    validDenom = rayMask.valid & ...
                 isfinite(diag.I_f) & ...
                 isfinite(diag.I_raw_ray) & ...
                 abs(diag.I_raw_ray) > cfg.min_positive_value;

    Corr_expected(validDenom) = diag.I_f(validDenom) ./ diag.I_raw_ray(validDenom);

    validCorrFrame = rayMask.valid & ...
                     isfinite(diag.Corr) & ...
                     isfinite(Corr_expected);

    absErrCorr = abs(diag.Corr(validCorrFrame) - Corr_expected(validCorrFrame));
    relErrCorr = absErrCorr ./ max(abs(Corr_expected(validCorrFrame)), cfg.min_positive_value);

    fprintf('max abs error = %.6g\n', max(absErrCorr));
    fprintf('p99 rel error = %.6g\n', prctile(relErrCorr, 99));
    fprintf('max rel error = %.6g\n', max(relErrCorr));

    %% ---------------- orientation check ----------------
    fprintf('\nOrientation / brightness check in ray space:\n');

    topRows = 1:50;
    botRows = cfg.h_raw-49:cfg.h_raw;

    top_model = mean(diag.I_model_ray(topRows,:), 'all', 'omitnan');
    bot_model = mean(diag.I_model_ray(botRows,:), 'all', 'omitnan');

    top_raw = mean(diag.I_raw_ray(topRows,:), 'all', 'omitnan');
    bot_raw = mean(diag.I_raw_ray(botRows,:), 'all', 'omitnan');

    fprintf('I_model_ray top 50 mean    = %.6g\n', top_model);
    fprintf('I_model_ray bottom 50 mean = %.6g\n', bot_model);
    fprintf('I_raw_ray top 50 mean      = %.6g\n', top_raw);
    fprintf('I_raw_ray bottom 50 mean   = %.6g\n', bot_raw);

    fprintf('Bottom/top ratio, model ray = %.6g\n', bot_model / max(top_model, eps));
    fprintf('Bottom/top ratio, raw ray   = %.6g\n', bot_raw   / max(top_raw, eps));

    %% ---------------- quick figures ----------------
    makeDiagnosticFigure(diag, Corr_mean, Corr_std, rayMask, frame, cfg);
end

fprintf('\n=====================================================\n');
fprintf('QC check completed.\n');
fprintf('=====================================================\n');

%% =========================================================
% Local helper functions
%% =========================================================

function printStats(name, x)

    x = x(:);
    x = x(isfinite(x));

    if isempty(x)
        fprintf('%s: no finite values.\n', name);
        return;
    end

    fprintf('%s:\n', name);
    fprintf('  min  = %.6g\n', min(x));
    fprintf('  p01  = %.6g\n', prctile(x, 1));
    fprintf('  p50  = %.6g\n', prctile(x, 50));
    fprintf('  p99  = %.6g\n', prctile(x, 99));
    fprintf('  max  = %.6g\n', max(x));
    fprintf('  mean = %.6g\n', mean(x, 'omitnan'));
    fprintf('  std  = %.6g\n', std(x, 0, 'omitnan'));
end

function r = localCorr(a, b)

    a = double(a(:));
    b = double(b(:));

    valid = isfinite(a) & isfinite(b);

    a = a(valid);
    b = b(valid);

    if numel(a) < 10
        r = NaN;
        return;
    end

    C = corrcoef(a, b);
    r = C(1,2);
end

function makeDiagnosticFigure(diag, Corr_mean, Corr_std, rayMask, frame, cfg)

    figure('Name', sprintf('QC frame %d', frame), 'Color', 'w');
    tiledlayout(3, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    imagesc(diag.I_model_cam);
    axis image ij;
    colorbar;
    title('I\_model\_cam, tif');

    nexttile;
    imagesc(diag.I_raw_cam);
    axis image ij;
    colorbar;
    title('I\_raw\_cam, dfm');

    nexttile;
    imagesc(diag.I_model_cam - diag.I_raw_cam);
    axis image ij;
    colorbar;
    title('I\_model\_cam - I\_raw\_cam');

    nexttile;
    validCam = isfinite(diag.I_model_cam) & isfinite(diag.I_raw_cam);
    scatter(diag.I_raw_cam(validCam), diag.I_model_cam(validCam), 2, '.');
    xlabel('I\_raw\_cam, dfm');
    ylabel('I\_model\_cam, tif');
    title('camera-space scatter');
    grid on;

    nexttile;
    imagesc(maskForPlot(diag.I_model_ray, rayMask));
    axis image ij;
    colorbar;
    title('I\_model\_ray');

    nexttile;
    imagesc(maskForPlot(diag.I_raw_ray, rayMask));
    axis image ij;
    colorbar;
    title('I\_raw\_ray');

    nexttile;
    imagesc(maskForPlot(diag.C_s, rayMask));
    axis image ij;
    colorbar;
    title('C\_s = I\_model\_ray / C\_k\_ray');

    nexttile;
    imagesc(maskForPlot(diag.I_sheet, rayMask));
    axis image ij;
    colorbar;
    title('I\_sheet');

    nexttile;
    imagesc(maskForPlot(diag.I_f, rayMask));
    axis image ij;
    colorbar;
    title('I\_f = I\_sheet * C\_s');

    nexttile;
    imagesc(maskForPlot(diag.Corr, rayMask));
    axis image ij;
    colorbar;
    title('Corr = I\_f / I\_raw\_ray');

    nexttile;
    imagesc(maskForPlot(Corr_mean, rayMask));
    axis image ij;
    colorbar;
    title('Corr\_mean');

    nexttile;
    imagesc(maskForPlot(Corr_std, rayMask));
    axis image ij;
    colorbar;
    title('Corr\_std');

    sgtitle(sprintf('QC diagnostic frame %d', frame));
end

function A = maskForPlot(A, rayMask)
    A(~rayMask.valid) = NaN;
end