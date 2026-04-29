function diag = computeFrameProducts_IeRaw_C1Model(frameIndex, cfg, pRaw, C_fit, rayMask)

    %% =========================================================
    % 1. Read original raw camera image I_e
    %% =========================================================
    I_e_cam = readOriginalIeFromDfm(frameIndex, cfg, pRaw);

    %% =========================================================
    % 2. Read C1 image
    % C1 is the image after one inverse Beer-Lambert correction.
    % It is NOT the raw image.
    %% =========================================================
    C1_cam = readC1FromTif(frameIndex, cfg);

    %% =========================================================
    % 3. Get Star correction field C_k on camera grid
    %% =========================================================
    Ck_cam = interpolateCkFromCfit(frameIndex, cfg, C_fit);

    Ck_cam(Ck_cam < cfg.min_positive_value) = cfg.min_positive_value;

    %% =========================================================
    % 4. Map I_e, C1, and C_k to ray space
    %% =========================================================
    I_e_ray = cfg.mapfun( ...
        I_e_cam, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    C1_ray = cfg.mapfun( ...
        C1_cam, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    Ck_ray = cfg.mapfun( ...
        Ck_cam, ...
        cfg.x_map_file, ...
        cfg.y_map_file, ...
        cfg.h_raw, ...
        cfg.w_raw, ...
        false);

    I_e_ray(~rayMask.valid) = NaN;
    C1_ray(~rayMask.valid)  = NaN;
    Ck_ray(~rayMask.valid)  = NaN;

    %% =========================================================
    % 5. Build concentration proxy C_s
    %
    % Your definition:
    %     C_s = C_1 / C_k
    %% =========================================================
    Cs_ray = C1_ray ./ max(Ck_ray, cfg.min_positive_value);
    Cs_ray(~rayMask.valid) = NaN;

    %% =========================================================
    % 6. Forward Beer-Lambert propagation to get sheet intensity I_s
    %% =========================================================
    Is_ray = forwardBeerLambertSheetIntensity(Cs_ray, I_e_ray, cfg, rayMask);

    %% =========================================================
    % 7. Forward-predicted image:
    %
    %     I_f = I_s * C_s
    %% =========================================================
    If_ray = Is_ray .* Cs_ray;

    %% =========================================================
    % 8. Correction factor:
    %
    %     Corr = I_f / I_e
    %% =========================================================
    Corr = If_ray ./ max(I_e_ray, cfg.min_positive_value);

    Corr(~rayMask.valid) = NaN;
    Corr(~isfinite(Corr)) = NaN;

    %% =========================================================
    % 9. Diagnostics
    %% =========================================================
    diag = struct();

    diag.frameIndex = frameIndex;

    diag.I_e_cam = I_e_cam;
    diag.C1_cam  = C1_cam;
    diag.Ck_cam  = Ck_cam;

    diag.I_e_ray = I_e_ray;
    diag.C1_ray  = C1_ray;
    diag.Ck_ray  = Ck_ray;

    diag.Cs_ray = Cs_ray;
    diag.Is_ray = Is_ray;
    diag.If_ray = If_ray;
    diag.Corr   = Corr;
end