function corrStats = pass1_computeCorrStats(cfg, pRaw, C_fit, rayMask)

Corr_sum   = zeros(cfg.h_raw, cfg.w_raw);
Corr_sumsq = zeros(cfg.h_raw, cfg.w_raw);
Corr_count = zeros(cfg.h_raw, cfg.w_raw);

fidRaw = fopen(cfg.fRaw_char, 'rb');
if fidRaw == -1
    error('Could not open raw movie file: %s', cfg.fRaw_char);
end

for kk = 1:cfg.N_sel

    frame = cfg.selected_frames(kk);

    fprintf('PASS 1: frame %d (%d/%d)\n', frame, kk, cfg.N_sel);

    I_e = double(df_dfm_read(fidRaw, frame, pRaw));

    out = computeCorrForFrame(I_e, frame, cfg, C_fit, rayMask);

    Corr = out.Corr;
    valid = isfinite(Corr);

    Corr_sum(valid)   = Corr_sum(valid) + Corr(valid);
    Corr_sumsq(valid) = Corr_sumsq(valid) + Corr(valid).^2;
    Corr_count(valid) = Corr_count(valid) + 1;
end

fclose(fidRaw);

Corr_mean = nan(cfg.h_raw, cfg.w_raw);
Corr_std  = nan(cfg.h_raw, cfg.w_raw);

valid_mean = Corr_count > 0;
Corr_mean(valid_mean) = Corr_sum(valid_mean) ./ Corr_count(valid_mean);

valid_std = Corr_count > 1;
Corr_std(valid_std) = sqrt( ...
    (Corr_sumsq(valid_std) - Corr_sum(valid_std).^2 ./ Corr_count(valid_std)) ./ ...
    (Corr_count(valid_std) - 1));

Corr_mean(rayMask.invalid) = NaN;
Corr_std(rayMask.invalid)  = NaN;

corrStats = struct();
corrStats.Corr_mean = Corr_mean;
corrStats.Corr_std = Corr_std;
corrStats.Corr_count = Corr_count;

end