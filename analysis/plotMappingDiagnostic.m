function plotMappingDiagnostic(cfg, pRaw, rayMask)

fidRaw = fopen(cfg.fRaw_char, 'rb');
if fidRaw == -1
    error('Could not open raw movie file: %s', cfg.fRaw_char);
end

frame = cfg.plot_diagnostic_frame;
I_test = double(df_dfm_read(fidRaw, frame, pRaw));
fclose(fidRaw);

[I_test_ray, ind_test_from_mapTo] = cfg.mapfun( ...
    I_test, cfg.x_map_file, cfg.y_map_file, cfg.h_raw, cfg.w_raw);

I_test_ray = double(I_test_ray);

ind_test_ray = flipud(logical(ind_test_from_mapTo));
invalid_test_ray = rayMask.invalid | ind_test_ray | ~isfinite(I_test_ray);

I_test_ray_plot = I_test_ray;
I_test_ray_plot(invalid_test_ray) = NaN;

figure('Color','w','Position',[100 100 1300 420]);

subplot(1,3,1);
imagesc(flipud(I_test));
axis image; colorbar;
title(sprintf('Camera-space raw, frame %d', frame));
xlabel('x pixel');
ylabel('z pixel');

subplot(1,3,2);
hIm = imagesc(I_test_ray_plot);
set(hIm, 'AlphaData', ~isnan(I_test_ray_plot));
set(gca, 'Color', [0.85 0.85 0.85]);
axis image; colorbar;
title('Mapped ray/world image');
xlabel('x pixel');
ylabel('z pixel');

subplot(1,3,3);
imagesc(invalid_test_ray);
axis image; colorbar;
title('Robust invalid mask aligned with I\_test\_ray');
xlabel('x pixel');
ylabel('z pixel');

end