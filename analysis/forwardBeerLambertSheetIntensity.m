function Is_ray = forwardBeerLambertSheetIntensity(Cs_ray, I_e_ray, cfg, rayMask)

    Cs_ray = double(Cs_ray);
    I_e_ray = double(I_e_ray);

    [h, w] = size(Cs_ray);

    Is_ray = NaN(h, w);

    valid = rayMask.valid & isfinite(Cs_ray) & isfinite(I_e_ray);

    Cs_safe = Cs_ray;
    Cs_safe(~valid) = NaN;
    Cs_safe(Cs_safe < cfg.min_positive_value) = cfg.min_positive_value;

    %% =========================================================
    % Incident boundary
    %
    % Since I_f = I_s * C_s, and I_f should match I_e at the incident
    % boundary, a consistent boundary estimate is:
    %
    %     I_s0 = I_e_boundary / C_s_boundary
    %
    % For bottom-to-top propagation, use bottom row.
    %% =========================================================

    if cfg.propagate_from_bottom

        iz0 = h;

        boundary_valid = valid(iz0,:) & isfinite(Cs_safe(iz0,:));

        I0 = NaN(1, w);
        I0(boundary_valid) = I_e_ray(iz0,boundary_valid) ./ Cs_safe(iz0,boundary_valid);

        % Fill missing boundary values by robust median.
        medI0 = median(I0(isfinite(I0)), 'omitnan');

        if ~isfinite(medI0)
            medI0 = 1;
        end

        I0(~isfinite(I0)) = medI0;

        Is_ray(iz0,:) = I0;

        for iz = h-1:-1:1

            beta = computeBeerLambertBeta(Cs_safe(iz+1,:), cfg);

            Is_ray(iz,:) = Is_ray(iz+1,:) .* beta;

            bad = ~valid(iz,:);
            Is_ray(iz,bad) = NaN;
        end

    else

        iz0 = 1;

        boundary_valid = valid(iz0,:) & isfinite(Cs_safe(iz0,:));

        I0 = NaN(1, w);
        I0(boundary_valid) = I_e_ray(iz0,boundary_valid) ./ Cs_safe(iz0,boundary_valid);

        medI0 = median(I0(isfinite(I0)), 'omitnan');

        if ~isfinite(medI0)
            medI0 = 1;
        end

        I0(~isfinite(I0)) = medI0;

        Is_ray(iz0,:) = I0;

        for iz = 2:h

            beta = computeBeerLambertBeta(Cs_safe(iz-1,:), cfg);

            Is_ray(iz,:) = Is_ray(iz-1,:) .* beta;

            bad = ~valid(iz,:);
            Is_ray(iz,bad) = NaN;
        end
    end

    Is_ray(~rayMask.valid) = NaN;
end