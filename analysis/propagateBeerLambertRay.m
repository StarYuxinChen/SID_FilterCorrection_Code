function I_f = propagateBeerLambertRay(C_s, I_e_ray, cfg, rayMask)

h = cfg.h_raw;
w = cfg.w_raw;

I_f = nan(h, w);

if cfg.propagate_from_bottom

    % Physical bottom = last row in the unflipped ray-space array
    I0_row = h;
    I0 = I_e_ray(I0_row, :);
    I0(~isfinite(I0)) = NaN;

    I_f(I0_row, :) = I0;

    for iz = I0_row-1:-1:1

        beta = nan(1, w);
        valid_beta = isfinite(C_s(iz,:));

        switch lower(cfg.propagation_scheme)

            case 'explicit'
                beta(valid_beta) = 1 - cfg.alpha_mean * C_s(iz,valid_beta);

            case 'cn'
                beta(valid_beta) = ...
                    (1 - 0.5 * cfg.alpha_mean * C_s(iz,valid_beta)) ./ ...
                    (1 + 0.5 * cfg.alpha_mean * C_s(iz,valid_beta));

            otherwise
                error('Unknown propagation_scheme. Use ''explicit'' or ''CN''.');
        end

        beta(beta < cfg.beta_min) = cfg.beta_min;
        beta(beta > cfg.beta_max) = cfg.beta_max;

        valid_prop = isfinite(I_f(iz+1,:)) & isfinite(beta);
        I_f(iz, valid_prop) = I_f(iz+1, valid_prop) .* beta(valid_prop);
    end

else

    % Kept for completeness only
    I0_row = 1;
    I0 = I_e_ray(I0_row, :);
    I0(~isfinite(I0)) = NaN;

    I_f(I0_row, :) = I0;

    for iz = I0_row+1:h

        beta = nan(1, w);
        valid_beta = isfinite(C_s(iz,:));

        switch lower(cfg.propagation_scheme)

            case 'explicit'
                beta(valid_beta) = 1 - cfg.alpha_mean * C_s(iz,valid_beta);

            case 'cn'
                beta(valid_beta) = ...
                    (1 - 0.5 * cfg.alpha_mean * C_s(iz,valid_beta)) ./ ...
                    (1 + 0.5 * cfg.alpha_mean * C_s(iz,valid_beta));

            otherwise
                error('Unknown propagation_scheme. Use ''explicit'' or ''CN''.');
        end

        beta(beta < cfg.beta_min) = cfg.beta_min;
        beta(beta > cfg.beta_max) = cfg.beta_max;

        valid_prop = isfinite(I_f(iz-1,:)) & isfinite(beta);
        I_f(iz, valid_prop) = I_f(iz-1, valid_prop) .* beta(valid_prop);
    end
end

I_f(rayMask.invalid) = NaN;

end