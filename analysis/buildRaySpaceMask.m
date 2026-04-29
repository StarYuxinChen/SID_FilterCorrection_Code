function rayMask = buildRaySpaceMask(cfg)

dummy = ones(cfg.h_raw, cfg.w_raw);

[dummy_ray, ind_common_from_mapTo] = cfg.mapfun( ...
    dummy, cfg.x_map_file, cfg.y_map_file, cfg.h_raw, cfg.w_raw);

dummy_ray = double(dummy_ray);

% mapTo returns ind = flipud(world)==0.
% Flip it back so it aligns with dummy_ray / I_e_ray / C_k_ray.
ind_common_ray = flipud(logical(ind_common_from_mapTo));

% Robust invalid check:
% dummy input is all ones, so valid mapped pixels should remain close to 1.
ind_common_ray = ind_common_ray | ~isfinite(dummy_ray) | (dummy_ray < 0.5);

valid_common = ~ind_common_ray;

valid_cols = find(any(valid_common,1));
if isempty(valid_cols)
    error('No valid columns found after mapping.');
end

rayMask = struct();
rayMask.invalid = ind_common_ray;
rayMask.valid   = valid_common;
rayMask.col1    = valid_cols(1);
rayMask.col2    = valid_cols(end);
rayMask.dummy_ray = dummy_ray;

end