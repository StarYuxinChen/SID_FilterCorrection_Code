function pass2_buildAndSaveIePrime(cfg, pRaw, rayMask, Corr_mean)

fidRaw = fopen(cfg.fRaw_char, 'rb');
if fidRaw == -1
    error('Could not open raw movie file: %s', cfg.fRaw_char);
end

for kk = 1:cfg.N_sel

    frame = cfg.selected_frames(kk);

    fprintf('PASS 2: frame %d (%d/%d)\n', frame, kk, cfg.N_sel);

    I_e = double(df_dfm_read(fidRaw, frame, pRaw));

    I_e_ray = double(cfg.mapfun( ...
        I_e, cfg.x_map_file, cfg.y_map_file, cfg.h_raw, cfg.w_raw));

    I_e_ray(rayMask.invalid) = NaN;

    I_e_prime_ray = Corr_mean .* I_e_ray;
    I_e_prime_ray(rayMask.invalid) = NaN;

    [I_e_prime_cam, cam_valid] = inverseRayToCamera(I_e_prime_ray, cfg, rayMask);

    saveIePrimeFrame(frame, I_e_prime_ray, I_e_prime_cam, cam_valid, cfg);
end

fclose(fidRaw);

end