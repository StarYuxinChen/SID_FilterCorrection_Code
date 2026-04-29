clear; clc; close all;



%% =========================================================
% USER INPUTS
%% =========================================================
px_per_mm = 22;

fileList_top = {
    "V:\202311\w318\LIF-Processing\top_11000-17000.dfi"
    "V:\202311\w318\LIF-Processing\top_17000-23000.dfi"
    "V:\202311\w318\LIF-Processing\top_23000-29000.dfi"
    "V:\202311\w318\LIF-Processing\top_29000-35000.dfi"
    "V:\202311\w318\LIF-Processing\top_35000-41000.dfi"
    "V:\202311\w318\LIF-Processing\top_41000-47000.dfi"
    "V:\202311\w318\LIF-Processing\top_47000-53000.dfi"
    "V:\202311\w318\LIF-Processing\top_53000-59000.dfi"
};

fileList_bot = {
    "V:\202311\w318\LIF-Processing\bot_11000-17000.dfi"
    "V:\202311\w318\LIF-Processing\bot_17000-23000.dfi"
    "V:\202311\w318\LIF-Processing\bot_23000-29000.dfi"
    "V:\202311\w318\LIF-Processing\bot_29000-35000.dfi"
    "V:\202311\w318\LIF-Processing\bot_35000-41000.dfi"
    "V:\202311\w318\LIF-Processing\bot_41000-47000.dfi"
    "V:\202311\w318\LIF-Processing\bot_47000-53000.dfi"
    "V:\202311\w318\LIF-Processing\bot_53000-59000.dfi"
};

fRaw = "V:\202311\w318\LIF-Processing\inputs\CamC_dimmer.dfm";
x_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_x_map.txt";
y_map_file = "V:\202311\w318\LIF-Processing\inputs\w318_ribbon_test2_y_map.txt";

mapfun = @mapTo;   % Stefan default
% mapfun = @mapToC; % only if you know conic mapping is needed

selected_frames = [11000 14000 17000 20000 23000 26000 29000 32000 35000 38000 41000 44000 47000 50000 53000 56000];
N_sel = numel(selected_frames);

fit_frame_centers = [14000; 20000; 26000; 32000; 38000; 44000; 50000; 56000];

z_bot_mm = 4.22;
z_top_mm = 42.32;

alpha_mean = 5e-6;
min_positive_value = 1e-10;

propagation_scheme = 'CN';   % 'explicit' or 'CN'
beta_min = 0;
beta_max = 1.5;

% plotting / diagnostics
show_debug_mapping = true;
crop_to_valid_cols = false;  % set true if you want to crop out invalid left block visually

%% =========================================================
% PART 1: Build top/bottom temporal-spatial correction model
%% =========================================================
N = numel(fileList_top);
assert(numel(fileList_bot)==N, 'top and bottom file counts must match.');
t = (1:N)';

M_top = zeros(N,1);
x_top_all = cell(N,1);
C_top_all = cell(N,1);

for k = 1:N
    [~, x_mm, Czmean_x, ~] = dfi_zAverage_vs_x(fileList_top{k}, px_per_mm);
    x_top_all{k} = x_mm(:);
    C_top_all{k} = Czmean_x(:);
    M_top(k) = mean(Czmean_x, 'omitnan');
end

M_bot = zeros(N,1);
x_bot_all = cell(N,1);
C_bot_all = cell(N,1);

for k = 1:N
    [~, x_mm, Czmean_x, ~] = dfi_zAverage_vs_x(fileList_bot{k}, px_per_mm);
    x_bot_all{k} = x_mm(:);
    C_bot_all{k} = Czmean_x(:);
    M_bot(k) = mean(Czmean_x, 'omitnan');
end

for k = 2:N
    if length(x_top_all{k}) ~= length(x_top_all{1}) || any(abs(x_top_all{k} - x_top_all{1}) > 1e-10)
        error('Top x grids are not identical.');
    end
    if length(x_bot_all{k}) ~= length(x_bot_all{1}) || any(abs(x_bot_all{k} - x_bot_all{1}) > 1e-10)
        error('Bottom x grids are not identical.');
    end
end

if length(x_top_all{1}) ~= length(x_bot_all{1}) || any(abs(x_top_all{1} - x_bot_all{1}) > 1e-10)
    error('Top and bottom x grids are not identical.');
end

x_common = x_top_all{1};
nx_common = numel(x_common);

%% =========================================================
% PART 2: Nonlinear exponential fits
%% =========================================================
ft = fittype('A*exp(-t/tau)+C', ...
    'independent', 't', ...
    'coefficients', {'A','tau','C'});

y_top = M_top(:);
[curve_top, gof_top] = fit(t, y_top, ft, ...
    'StartPoint', [y_top(1)-y_top(end), N/2, y_top(end)]);

y_bot = M_bot(:);
[curve_bot, gof_bot] = fit(t, y_bot, ft, ...
    'StartPoint', [y_bot(1)-y_bot(end), N/2, y_bot(end)]);

f_t = curve_top.A * exp(-t / curve_top.tau) + curve_top.C;
f_b = curve_bot.A * exp(-t / curve_bot.tau) + curve_bot.C;

f_t_norm = f_t / f_t(1);
f_b_norm = f_b / f_b(1);

%% =========================================================
% PART 3: Build spatial functions and fitted correction field (camera space)
%% =========================================================
G_top_each = zeros(nx_common, N);
G_bot_each = zeros(nx_common, N);

for k = 1:N
    G_top_each(:,k) = C_top_all{k} / f_t_norm(k);
    G_bot_each(:,k) = C_bot_all{k} / f_b_norm(k);
end

g_t_corr = mean(G_top_each, 2, 'omitnan');
g_b_corr = mean(G_bot_each, 2, 'omitnan');

g_t_norm = g_t_corr / mean(g_t_corr, 'omitnan');
g_b_norm = g_b_corr / mean(g_b_corr, 'omitnan');

I_t = g_t_norm * f_t_norm(:)';   % nx_common x N
I_b = g_b_norm * f_b_norm(:)';   % nx_common x N

%% =========================================================
% PART 4: Raw movie geometry and file open
%% =========================================================
fRaw_char = char(fRaw);
pRaw = df_dfm_info(fRaw_char);

w_raw = 3320;
h_raw = 1024;

fidRaw = fopen(fRaw_char, 'rb');
if fidRaw == -1
    error('Could not open raw movie file: %s', fRaw_char);
end
fprintf('Opened raw movie successfully. fidRaw = %d\n', fidRaw);

x_raw_mm = (0:w_raw-1) / px_per_mm;
z_plot_mm = (0:h_raw-1) / px_per_mm;

%% =========================================================
% PART 5: Interpolate fitted correction field C_fit to raw camera grid
%% =========================================================
Nt_fit = size(I_b, 2);
if Nt_fit ~= numel(fit_frame_centers)
    error('Number of columns in I_b/I_t must match fit_frame_centers.');
end

I_b_raw = zeros(w_raw, Nt_fit);
I_t_raw = zeros(w_raw, Nt_fit);

for j = 1:Nt_fit
    I_b_raw(:,j) = interp1(x_common(:), I_b(:,j), x_raw_mm(:), 'linear', 'extrap');
    I_t_raw(:,j) = interp1(x_common(:), I_t(:,j), x_raw_mm(:), 'linear', 'extrap');
end

z_phys_row_mm = (h_raw - (1:h_raw)) / px_per_mm;  % physical z measured from bottom upward
eta_z = (z_phys_row_mm(:) - z_bot_mm) / (z_top_mm - z_bot_mm);
eta_z = max(0, min(1, eta_z));

C_fit = zeros(h_raw, w_raw, Nt_fit);
for iz = 1:h_raw
    Cz = (1 - eta_z(iz)) * I_b_raw + eta_z(iz) * I_t_raw;   % w_raw x Nt_fit
    C_fit(iz,:,:) = reshape(Cz, [1, w_raw, Nt_fit]);
end
C_fit(C_fit <= min_positive_value) = min_positive_value;

%% =========================================================
% PART 6: Build a robust common ray-space valid mask
%% =========================================================
dummy = ones(h_raw, w_raw);

[dummy_ray, ind_common_from_mapTo] = mapfun(dummy, x_map_file, y_map_file, h_raw, w_raw);
dummy_ray = double(dummy_ray);

% IMPORTANT:
% mapTo returns ind = flipud(world)==0.
% But dummy_ray itself is NOT flipped.
% Therefore we flip ind back so it aligns with dummy_ray / I_e_ray / C_k_ray.
ind_common_ray = flipud(logical(ind_common_from_mapTo));

% Extra robust check:
% because dummy input is all ones, valid mapped pixels should stay close to 1.
ind_common_ray = ind_common_ray | ~isfinite(dummy_ray) | (dummy_ray < 0.5);

valid_common = ~ind_common_ray;

valid_cols = find(any(valid_common,1));
if isempty(valid_cols)
    error('No valid columns found after mapping.');
end
col1 = valid_cols(1);
col2 = valid_cols(end);

fprintf('dummy_ray min = %.4g, max = %.4g, mean = %.4g\n', ...
    min(dummy_ray(:),[],'omitnan'), ...
    max(dummy_ray(:),[],'omitnan'), ...
    mean(dummy_ray(:),'omitnan'));

%% =========================================================
% PART 7: First-frame mapping diagnostic
%% =========================================================
I_test = double(df_dfm_read(fidRaw, selected_frames(1), pRaw));

[I_test_ray, ind_test_from_mapTo] = mapfun(I_test, x_map_file, y_map_file, h_raw, w_raw);
I_test_ray = double(I_test_ray);

% mapTo returns ind = flipud(world)==0.
% Flip it back so it aligns with I_test_ray.
ind_test_ray = flipud(logical(ind_test_from_mapTo));

invalid_test_ray = ind_common_ray | ind_test_ray | ~isfinite(I_test_ray);

I_test_ray_plot = I_test_ray;
I_test_ray_plot(invalid_test_ray) = NaN;

if show_debug_mapping
    figure('Color','w','Position',[100 100 1300 420]);

    subplot(1,3,1);
    imagesc(flipud(I_test)); 
    axis image; colorbar;
    title('Camera-space raw');
    xlabel('x pixel'); ylabel('z pixel');

    subplot(1,3,2);
    hIm = imagesc(I_test_ray_plot); 
    set(hIm, 'AlphaData', ~isnan(I_test_ray_plot));
    set(gca, 'Color', [0.85 0.85 0.85]);
    axis image; colorbar;
    title('Mapped ray/world image');
    xlabel('x pixel'); ylabel('z pixel');

    subplot(1,3,3);
    imagesc(invalid_test_ray); 
    axis image; colorbar;
    title('Robust invalid mask aligned with I\_test\_ray');
    xlabel('x pixel'); ylabel('z pixel');
end

%% =========================================================
% PART 8: Fix propagation direction in ray space
%% =========================================================
% For experiment w318, the laser enters from the physical bottom.
% In the unflipped ray-space array, physical bottom corresponds to row h_raw.
propagate_from_bottom = true;
fprintf('Using ray-space propagation: bottom -> top, fixed by experiment geometry.\n');


%% =========================================================
% PART 9: From C_s(ray) to Corr(ray) for each frame
%% =========================================================
Corr_all   = nan(h_raw, w_raw, N_sel);
Ie_ray_all = cell(N_sel,1);
Cs_all     = cell(N_sel,1);
If_all     = cell(N_sel,1);

for kk = 1:N_sel
    k = selected_frames(kk);
    fprintf('Processing frame %d (%d/%d), fidRaw = %d\n', k, kk, N_sel, fidRaw);

    % ------------------------------------------------------
    % read raw experimental image in camera space
    % ------------------------------------------------------
    I_e = double(df_dfm_read(fidRaw, k, pRaw));

    if size(I_e,1) ~= h_raw || size(I_e,2) ~= w_raw
        error('Frame size mismatch at frame %d.', k);
    end

    % ------------------------------------------------------
    % interpolate camera-space correction field C_k at this frame
    % ------------------------------------------------------
    C_k = zeros(h_raw, w_raw);

    for iz = 1:h_raw
        for ix = 1:w_raw
            C_k(iz,ix) = interp1( ...
                fit_frame_centers, ...
                squeeze(C_fit(iz,ix,:)), ...
                k, 'linear', 'extrap');
        end
    end

    C_k(C_k <= min_positive_value) = min_positive_value;

    % ------------------------------------------------------
    % map camera-space fields to ray/world space
    % ------------------------------------------------------
    I_e_ray = double(mapfun(I_e, x_map_file, y_map_file, h_raw, w_raw));
    C_k_ray = double(mapfun(C_k, x_map_file, y_map_file, h_raw, w_raw));

    % keep invalid mapped region as NaN
    I_e_ray(ind_common_ray) = NaN;
    C_k_ray(ind_common_ray) = NaN;

    % ------------------------------------------------------
    % define C_s in ray space
    % ------------------------------------------------------
    C_s = I_e_ray ./ C_k_ray;
    C_s(~isfinite(C_s)) = NaN;
    C_s(C_s < 0) = NaN;

    % ------------------------------------------------------
    % Beer-Lambert / CN propagation in ray space
    % C_s --> I_f
    % ------------------------------------------------------
    I_f = nan(h_raw, w_raw);

    if propagate_from_bottom
        % Physical bottom = last row in the unflipped ray-space array
        I0_row = h_raw;
        I0 = I_e_ray(I0_row, :);
        I0(~isfinite(I0)) = NaN;
        I_f(I0_row, :) = I0;

        for iz = I0_row-1:-1:1
            beta = nan(1, w_raw);

            valid_beta = isfinite(C_s(iz,:));

            switch lower(propagation_scheme)
                case 'explicit'
                    beta(valid_beta) = 1 - alpha_mean * C_s(iz,valid_beta);

                case 'cn'
                    beta(valid_beta) = ...
                        (1 - 0.5 * alpha_mean * C_s(iz,valid_beta)) ./ ...
                        (1 + 0.5 * alpha_mean * C_s(iz,valid_beta));

                otherwise
                    error('Unknown propagation_scheme. Use ''explicit'' or ''CN''.');
            end

            beta(beta < beta_min) = beta_min;
            beta(beta > beta_max) = beta_max;

            valid_prop = isfinite(I_f(iz+1,:)) & isfinite(beta);
            I_f(iz, valid_prop) = I_f(iz+1, valid_prop) .* beta(valid_prop);
        end

    else
        % This branch is kept for completeness, but w318 should use bottom -> top
        I0_row = 1;
        I0 = I_e_ray(I0_row, :);
        I0(~isfinite(I0)) = NaN;
        I_f(I0_row, :) = I0;

        for iz = I0_row+1:h_raw
            beta = nan(1, w_raw);

            valid_beta = isfinite(C_s(iz,:));

            switch lower(propagation_scheme)
                case 'explicit'
                    beta(valid_beta) = 1 - alpha_mean * C_s(iz,valid_beta);

                case 'cn'
                    beta(valid_beta) = ...
                        (1 - 0.5 * alpha_mean * C_s(iz,valid_beta)) ./ ...
                        (1 + 0.5 * alpha_mean * C_s(iz,valid_beta));

                otherwise
                    error('Unknown propagation_scheme. Use ''explicit'' or ''CN''.');
            end

            beta(beta < beta_min) = beta_min;
            beta(beta > beta_max) = beta_max;

            valid_prop = isfinite(I_f(iz-1,:)) & isfinite(beta);
            I_f(iz, valid_prop) = I_f(iz-1, valid_prop) .* beta(valid_prop);
        end
    end

    % ensure invalid region stays invalid
    I_f(ind_common_ray) = NaN;

    % ------------------------------------------------------
    % Corr = I_f / I_e_ray
    % ------------------------------------------------------
    Corr = nan(h_raw, w_raw);

    valid = isfinite(I_e_ray) & isfinite(I_f) & abs(I_e_ray) > min_positive_value;
    Corr(valid) = I_f(valid) ./ I_e_ray(valid);

    Corr(ind_common_ray) = NaN;

    % ------------------------------------------------------
    % store ray-space fields
    % ------------------------------------------------------
    Corr_all(:,:,kk) = Corr;
    Ie_ray_all{kk} = I_e_ray;
    Cs_all{kk} = C_s;
    If_all{kk} = I_f;
end

fclose(fidRaw);

%% =========================================================
% PART 10: Average Corr over frames in ray space
%% =========================================================
Corr_mean = mean(Corr_all, 3, 'omitnan');
Corr_std  = std(Corr_all, 0, 3, 'omitnan');

Corr_mean(ind_common_ray) = NaN;
Corr_std(ind_common_ray)  = NaN;

%% =========================================================
% PART 11: Build I_e' in ray space
%% =========================================================
Ie_prime_ray_all = cell(N_sel,1);

for kk = 1:N_sel
    I_e_ray = Ie_ray_all{kk};

    % I_e' = <Corr> * I_e_ray
    I_e_prime_ray = Corr_mean .* I_e_ray;
    I_e_prime_ray(ind_common_ray) = NaN;

    Ie_prime_ray_all{kk} = I_e_prime_ray;
end

%% =========================================================
% EXTRA PLOT 1: Show CN reconstruction for one selected frame
%% =========================================================
plot_idx = 1;  % choose which selected frame to inspect
frame_to_plot = selected_frames(plot_idx);

% All fields below are displayed in physical orientation:
% physical bottom at z = 0 mm, physical top at larger z.
Ie_ray_plot      = flipud(Ie_ray_all{plot_idx});
Cs_plot          = flipud(Cs_all{plot_idx});
If_plot          = flipud(If_all{plot_idx});          % CN output
Corr_single_plot = flipud(Corr_all(:,:,plot_idx));
Corr_mean_plot2  = flipud(Corr_mean);
Ie_prime_plot2   = flipud(Ie_prime_ray_all{plot_idx});

figure('Color','w','Position',[80 80 1700 850]);

% ---------------------------------------------------------
% 1. I_e_ray
% ---------------------------------------------------------
subplot(2,3,1);
h1 = imagesc(x_raw_mm, z_plot_mm, Ie_ray_plot);
set(h1, 'AlphaData', ~isnan(Ie_ray_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('I_e in ray space, frame %d', frame_to_plot));

% ---------------------------------------------------------
% 2. C_s
% ---------------------------------------------------------
subplot(2,3,2);
h2 = imagesc(x_raw_mm, z_plot_mm, Cs_plot);
set(h2, 'AlphaData', ~isnan(Cs_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('C_s = I_e / C_k in ray space');

vals = Cs_plot(isfinite(Cs_plot));
if ~isempty(vals)
    caxis(prctile(vals, [1 99]));
end

% ---------------------------------------------------------
% 3. I_f = CN forward prediction
% ---------------------------------------------------------
subplot(2,3,3);
h3 = imagesc(x_raw_mm, z_plot_mm, If_plot);
set(h3, 'AlphaData', ~isnan(If_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('I_f from %s propagation', propagation_scheme));

% Match colour scale with I_e_ray for visual comparison
valid_I = isfinite(Ie_ray_plot) & isfinite(If_plot);
if any(valid_I(:))
    clim_I = prctile([Ie_ray_plot(valid_I); If_plot(valid_I)], [1 99]);
    caxis(clim_I);
end

% ---------------------------------------------------------
% 4. Corr = I_f / I_e_ray
% ---------------------------------------------------------
subplot(2,3,4);
h4 = imagesc(x_raw_mm, z_plot_mm, Corr_single_plot);
set(h4, 'AlphaData', ~isnan(Corr_single_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('Corr = I_f / I_e for this frame');

vals = Corr_single_plot(isfinite(Corr_single_plot));
if ~isempty(vals)
    caxis(prctile(vals, [1 99]));
end

% ---------------------------------------------------------
% 5. <Corr>
% ---------------------------------------------------------
subplot(2,3,5);
h5 = imagesc(x_raw_mm, z_plot_mm, Corr_mean_plot2);
set(h5, 'AlphaData', ~isnan(Corr_mean_plot2));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('<Corr> averaged over selected frames');

vals = Corr_mean_plot2(isfinite(Corr_mean_plot2));
if ~isempty(vals)
    caxis(prctile(vals, [1 99]));
end

% ---------------------------------------------------------
% 6. I_e'
% ---------------------------------------------------------
subplot(2,3,6);
h6 = imagesc(x_raw_mm, z_plot_mm, Ie_prime_plot2);
set(h6, 'AlphaData', ~isnan(Ie_prime_plot2));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('I_e'' = <Corr> I_e, frame %d', frame_to_plot));

vals = Ie_prime_plot2(isfinite(Ie_prime_plot2));
if ~isempty(vals)
    caxis(prctile(vals, [1 99]));
end

%% =========================================================
% EXTRA PLOT 2: Vertical mean profiles
%% =========================================================
plot_idx = 1;
frame_to_plot = selected_frames(plot_idx);

Ie_ray_phys    = flipud(Ie_ray_all{plot_idx});
If_phys        = flipud(If_all{plot_idx});
Ie_prime_phys  = flipud(Ie_prime_ray_all{plot_idx});

Ie_mean_z       = mean(Ie_ray_phys, 2, 'omitnan');
If_mean_z       = mean(If_phys, 2, 'omitnan');
Ie_prime_mean_z = mean(Ie_prime_phys, 2, 'omitnan');

figure('Color','w','Position',[200 200 650 500]);
plot(Ie_mean_z, z_plot_mm, 'LineWidth', 1.8); hold on;
plot(If_mean_z, z_plot_mm, 'LineWidth', 1.8);
plot(Ie_prime_mean_z, z_plot_mm, 'LineWidth', 1.8);
grid on;

xlabel('horizontal mean intensity');
ylabel('z from bottom (mm)');
title(sprintf('Vertical mean comparison, frame %d', frame_to_plot));
legend('I_e ray', 'I_f CN prediction', 'I_e'' corrected', 'Location', 'best');

%% =========================================================
% PART 12: Plot essentials
%% =========================================================
Corr_mean_plot = flipud(Corr_mean);
Corr_std_plot  = flipud(Corr_std);

example_idx = 1;
Ie_prime_plot = flipud(Ie_prime_ray_all{example_idx});

if crop_to_valid_cols
    x_plot = x_raw_mm(col1:col2);
    Corr_mean_plot_show = Corr_mean_plot(:, col1:col2);
    Corr_std_plot_show  = Corr_std_plot(:, col1:col2);
    Ie_prime_plot_show  = Ie_prime_plot(:, col1:col2);
else
    x_plot = x_raw_mm;
    Corr_mean_plot_show = Corr_mean_plot;
    Corr_std_plot_show  = Corr_std_plot;
    Ie_prime_plot_show  = Ie_prime_plot;
end

figure('Color','w','Position',[100 100 1500 450]);

subplot(1,3,1);
h1 = imagesc(x_plot, z_plot_mm, Corr_mean_plot_show);
set(h1, 'AlphaData', ~isnan(Corr_mean_plot_show));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('<Corr> in ray space, scheme = %s', propagation_scheme));

subplot(1,3,2);
h2 = imagesc(x_plot, z_plot_mm, Corr_std_plot_show);
set(h2, 'AlphaData', ~isnan(Corr_std_plot_show));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('std(Corr) in ray space');

subplot(1,3,3);
h3 = imagesc(x_plot, z_plot_mm, Ie_prime_plot_show);
set(h3, 'AlphaData', ~isnan(Ie_prime_plot_show));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('Example I_e'' in ray space, frame %d', selected_frames(example_idx)));

%% =========================================================
% PART 13: Print diagnostics
%% =========================================================
fprintf('\nTop fit R^2    = %.6f\n', gof_top.rsquare);
fprintf('Bottom fit R^2 = %.6f\n', gof_bot.rsquare);
fprintf('Propagation scheme = %s\n', propagation_scheme);

valid_fraction = nnz(valid_common) / numel(valid_common);
fprintf('Ray-space valid fraction = %.4f\n', valid_fraction);
fprintf('Valid x columns = [%d, %d]\n', col1, col2);

%% =========================================================
% EXTRA DIAGNOSTIC: Does I_f really use C_s?
%% =========================================================
plot_idx = 1;
frame_to_plot = selected_frames(plot_idx);

Cs_check = Cs_all{plot_idx};
If_check = If_all{plot_idx};

% For bottom-to-top propagation:
% I_f(iz,:) = I_f(iz+1,:) * beta(iz,:)
beta_from_If = nan(h_raw, w_raw);
Cs_implied   = nan(h_raw, w_raw);

for iz = h_raw-1:-1:1
    valid_pair = isfinite(If_check(iz,:)) & isfinite(If_check(iz+1,:)) & ...
                 abs(If_check(iz+1,:)) > min_positive_value;

    beta_from_If(iz, valid_pair) = If_check(iz, valid_pair) ./ If_check(iz+1, valid_pair);

    switch lower(propagation_scheme)
        case 'cn'
            beta_tmp = beta_from_If(iz, valid_pair);
            Cs_implied(iz, valid_pair) = 2 * (1 - beta_tmp) ./ ...
                                         (alpha_mean * (1 + beta_tmp));

        case 'explicit'
            beta_tmp = beta_from_If(iz, valid_pair);
            Cs_implied(iz, valid_pair) = (1 - beta_tmp) ./ alpha_mean;

        otherwise
            error('Unknown propagation_scheme.');
    end
end

Cs_check(ind_common_ray)   = NaN;
Cs_implied(ind_common_ray) = NaN;

% Physical orientation for plotting
Cs_check_plot   = flipud(Cs_check);
Cs_implied_plot = flipud(Cs_implied);

Cs_mean_z        = mean(Cs_check_plot, 2, 'omitnan');
Cs_implied_mean_z = mean(Cs_implied_plot, 2, 'omitnan');

figure('Color','w','Position',[200 200 700 520]);
plot(Cs_mean_z, z_plot_mm, 'LineWidth', 1.8); hold on;
plot(Cs_implied_mean_z, z_plot_mm, '--', 'LineWidth', 1.8);
grid on;

xlabel('horizontal mean concentration proxy');
ylabel('z from bottom (mm)');
title(sprintf('Check whether I_f used C_s, frame %d', frame_to_plot));
legend('input C_s', 'C_s implied from I_f', 'Location', 'best');

%% =========================================================
% EXTRA DIAGNOSTIC: 2D error between input C_s and implied C_s
%% =========================================================
Cs_error = Cs_implied - Cs_check;
Cs_error(ind_common_ray) = NaN;

Cs_error_plot = flipud(Cs_error);

figure('Color','w','Position',[200 200 900 360]);
h = imagesc(x_raw_mm, z_plot_mm, Cs_error_plot);
set(h, 'AlphaData', ~isnan(Cs_error_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('C_s implied from I_f minus input C_s, frame %d', frame_to_plot));

vals = Cs_error_plot(isfinite(Cs_error_plot));
if ~isempty(vals)
    caxis(prctile(vals, [1 99]));
end

