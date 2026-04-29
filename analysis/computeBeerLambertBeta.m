function beta = computeBeerLambertBeta(Cs_row, cfg)

    Cs_row = double(Cs_row);

    switch lower(cfg.propagation_scheme)

        case 'explicit'
            beta = 1 - cfg.alpha_mean .* Cs_row;

        case 'cn'
            beta = (1 - 0.5 .* cfg.alpha_mean .* Cs_row) ./ ...
                   (1 + 0.5 .* cfg.alpha_mean .* Cs_row);

        otherwise
            error('Unknown propagation scheme: %s', cfg.propagation_scheme);
    end

    beta(~isfinite(beta)) = NaN;

    if isfield(cfg, 'beta_min')
        beta(beta < cfg.beta_min) = cfg.beta_min;
    end

    if isfield(cfg, 'beta_max')
        beta(beta > cfg.beta_max) = cfg.beta_max;
    end
end