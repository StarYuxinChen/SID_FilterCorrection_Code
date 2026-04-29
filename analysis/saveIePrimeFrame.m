function saveIePrimeFrame(frame, I_e_prime_ray, I_e_prime_cam, cam_valid, cfg)

frameTag = sprintf('%05d', frame);

vars = {'frame'};

if cfg.save_ray_mat
    Ie_prime_ray = single(I_e_prime_ray);
    vars{end+1} = 'Ie_prime_ray';
end

if cfg.save_cam_mat
    Ie_prime_cam = single(I_e_prime_cam);
    cam_valid = logical(cam_valid);
    vars{end+1} = 'Ie_prime_cam';
    vars{end+1} = 'cam_valid';
end

if cfg.save_ray_mat || cfg.save_cam_mat
    matFile = fullfile(cfg.output_dir, sprintf('IePrime_%s.mat', frameTag));
    save(matFile, vars{:}, '-v7.3');
end

if cfg.save_cam_tif
    tifDir = fullfile(cfg.output_dir, "tif_camera");
    if ~exist(tifDir, 'dir')
        mkdir(tifDir);
    end

    A = I_e_prime_cam;
    A(~isfinite(A)) = 0;

    A = A * cfg.tif_scale;
    A = max(0, min(65535, A));

    tifFile = fullfile(tifDir, sprintf('IePrime_cam_%s.tif', frameTag));
    imwrite(uint16(round(A)), tifFile);
end

end