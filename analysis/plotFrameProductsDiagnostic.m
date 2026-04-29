function plotFrameProductsDiagnostic(diag, Corr_mean, Corr_std, cfg)

frame = diag.frame;

Ie_ray_plot      = flipud(diag.I_e_ray);
Cs_plot          = flipud(diag.C_s);
If_plot          = flipud(diag.I_f);
Corr_single_plot = flipud(diag.Corr);
Corr_mean_plot   = flipud(Corr_mean);
Corr_std_plot    = flipud(Corr_std);
Ie_prime_plot    = flipud(diag.Ie_prime_ray);

%% =========================================================
% Figure 1: Main fields
%% =========================================================
figure('Color','w','Position',[80 80 1700 850]);

subplot(2,3,1);
h1 = imagesc(cfg.x_raw_mm, cfg.z_plot_mm, Ie_ray_plot);
set(h1, 'AlphaData', ~isnan(Ie_ray_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('I_e in ray space, frame %d', frame));

subplot(2,3,2);
h2 = imagesc(cfg.x_raw_mm, cfg.z_plot_mm, Cs_plot);
set(h2, 'AlphaData', ~isnan(Cs_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('C_s = I_e / C_k in ray space');
setRobustCaxis(Cs_plot);

subplot(2,3,3);
h3 = imagesc(cfg.x_raw_mm, cfg.z_plot_mm, If_plot);
set(h3, 'AlphaData', ~isnan(If_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('I_f from %s propagation', cfg.propagation_scheme));

valid_I = isfinite(Ie_ray_plot) & isfinite(If_plot);
if any(valid_I(:))
    clim_I = prctile([Ie_ray_plot(valid_I); If_plot(valid_I)], [1 99]);
    caxis(clim_I);
end

subplot(2,3,4);
h4 = imagesc(cfg.x_raw_mm, cfg.z_plot_mm, Corr_single_plot);
set(h4, 'AlphaData', ~isnan(Corr_single_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('Corr = I_f / I_e for this frame');
setRobustCaxis(Corr_single_plot);

subplot(2,3,5);
h5 = imagesc(cfg.x_raw_mm, cfg.z_plot_mm, Corr_mean_plot);
set(h5, 'AlphaData', ~isnan(Corr_mean_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title('<Corr> averaged over selected frames');
setRobustCaxis(Corr_mean_plot);

subplot(2,3,6);
h6 = imagesc(cfg.x_raw_mm, cfg.z_plot_mm, Ie_prime_plot);
set(h6, 'AlphaData', ~isnan(Ie_prime_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('x (mm)');
ylabel('z from bottom (mm)');
title(sprintf('I_e'' = <Corr> I_e, frame %d', frame));
setRobustCaxis(Ie_prime_plot);

%% =========================================================
% Figure 2: Vertical mean profiles
%% =========================================================
Ie_mean_z       = mean(Ie_ray_plot, 2, 'omitnan');
If_mean_z       = mean(If_plot, 2, 'omitnan');
Ie_prime_mean_z = mean(Ie_prime_plot, 2, 'omitnan');

figure('Color','w','Position',[200 200 650 500]);
plot(Ie_mean_z, cfg.z_plot_mm, 'LineWidth', 1.8); hold on;
plot(If_mean_z, cfg.z_plot_mm, 'LineWidth', 1.8);
plot(Ie_prime_mean_z, cfg.z_plot_mm, 'LineWidth', 1.8);
grid on;

xlabel('horizontal mean intensity');
ylabel('z from bottom (mm)');
title(sprintf('Vertical mean comparison, frame %d', frame));
legend('I_e ray', 'I_f CN prediction', 'I_e'' corrected', 'Location', 'best');

end

function setRobustCaxis(A)
vals = A(isfinite(A));
if ~isempty(vals)
    caxis(prctile(vals, [1 99]));
end
end