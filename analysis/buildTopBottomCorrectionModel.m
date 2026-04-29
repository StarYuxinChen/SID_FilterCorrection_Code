function starModel = buildTopBottomCorrectionModel(fileList_top, fileList_bot, px_per_mm)

N = numel(fileList_top);
assert(numel(fileList_bot)==N, 'Top and bottom file counts must match.');

% ---------------------------------------------------------
% Use the same x crop as Pass 1.
% This avoids bad left/right boundary values contaminating the Star model.
% ---------------------------------------------------------
crop_x1 = 30;
crop_x2 = 3300;

x_min_mm = (crop_x1 - 1) / px_per_mm;
x_max_mm = (crop_x2 - 1) / px_per_mm;

t = (1:N)';

M_top = zeros(N,1);
x_top_all = cell(N,1);
C_top_all = cell(N,1);

for k = 1:N

    [~, x_mm, Czmean_x, ~] = dfi_zAverage_vs_x(fileList_top{k}, px_per_mm);

    x_mm = x_mm(:);
    Czmean_x = Czmean_x(:);

    keep = isfinite(x_mm) & isfinite(Czmean_x) & ...
           x_mm >= x_min_mm & x_mm <= x_max_mm;

    x_top_all{k} = x_mm(keep);
    C_top_all{k} = Czmean_x(keep);

    M_top(k) = mean(C_top_all{k}, 'omitnan');
end

M_bot = zeros(N,1);
x_bot_all = cell(N,1);
C_bot_all = cell(N,1);

for k = 1:N

    [~, x_mm, Czmean_x, ~] = dfi_zAverage_vs_x(fileList_bot{k}, px_per_mm);

    x_mm = x_mm(:);
    Czmean_x = Czmean_x(:);

    keep = isfinite(x_mm) & isfinite(Czmean_x) & ...
           x_mm >= x_min_mm & x_mm <= x_max_mm;

    x_bot_all{k} = x_mm(keep);
    C_bot_all{k} = Czmean_x(keep);

    M_bot(k) = mean(C_bot_all{k}, 'omitnan');
end

% ---------------------------------------------------------
% Check x grids
% ---------------------------------------------------------
for k = 2:N

    if length(x_top_all{k}) ~= length(x_top_all{1}) || ...
            any(abs(x_top_all{k} - x_top_all{1}) > 1e-10)
        error('Top x grids are not identical after crop.');
    end

    if length(x_bot_all{k}) ~= length(x_bot_all{1}) || ...
            any(abs(x_bot_all{k} - x_bot_all{1}) > 1e-10)
        error('Bottom x grids are not identical after crop.');
    end
end

if length(x_top_all{1}) ~= length(x_bot_all{1}) || ...
        any(abs(x_top_all{1} - x_bot_all{1}) > 1e-10)
    error('Top and bottom x grids are not identical after crop.');
end

x_common = x_top_all{1};
nx_common = numel(x_common);

% ---------------------------------------------------------
% Exponential temporal fits
% ---------------------------------------------------------
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

% ---------------------------------------------------------
% Spatial functions
% ---------------------------------------------------------
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

% ---------------------------------------------------------
% Extra diagnostics
% ---------------------------------------------------------
fprintf('\nStar model diagnostics:\n');
fprintf('  x crop used: %.3f mm to %.3f mm\n', x_min_mm, x_max_mm);
fprintf('  nx_common after crop = %d\n', nx_common);
fprintf('  M_top range = [%.6g, %.6g]\n', min(M_top), max(M_top));
fprintf('  M_bot range = [%.6g, %.6g]\n', min(M_bot), max(M_bot));
fprintf('  Top fit R^2 = %.6f\n', gof_top.rsquare);
fprintf('  Bot fit R^2 = %.6f\n', gof_bot.rsquare);
fprintf('  g_t_norm range = [%.6g, %.6g]\n', min(g_t_norm), max(g_t_norm));
fprintf('  g_b_norm range = [%.6g, %.6g]\n', min(g_b_norm), max(g_b_norm));

% ---------------------------------------------------------
% Output
% ---------------------------------------------------------
starModel = struct();

starModel.N = N;
starModel.t = t;
starModel.x_common = x_common;

starModel.crop_x1 = crop_x1;
starModel.crop_x2 = crop_x2;
starModel.x_min_mm = x_min_mm;
starModel.x_max_mm = x_max_mm;

starModel.M_top = M_top;
starModel.M_bot = M_bot;

starModel.curve_top = curve_top;
starModel.curve_bot = curve_bot;
starModel.gof_top = gof_top;
starModel.gof_bot = gof_bot;

starModel.f_t_norm = f_t_norm;
starModel.f_b_norm = f_b_norm;

starModel.g_t_corr = g_t_corr;
starModel.g_b_corr = g_b_corr;
starModel.g_t_norm = g_t_norm;
starModel.g_b_norm = g_b_norm;

starModel.I_t = I_t;
starModel.I_b = I_b;

starModel.G_top_each = G_top_each;
starModel.G_bot_each = G_bot_each;

end