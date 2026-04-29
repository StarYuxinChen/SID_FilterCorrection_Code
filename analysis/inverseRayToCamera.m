function [camImage, camValid] = inverseRayToCamera(rayImage, cfg, rayMask)

validRay = isfinite(rayImage) & ~rayMask.invalid;

% mapTo inverse does not behave well with NaNs.
% So fill invalid ray-space pixels with 0 before inverse mapping.
rayForMap = rayImage;
rayForMap(~validRay) = 0;

camImage = double(cfg.mapfun( ...
    rayForMap, cfg.x_map_file, cfg.y_map_file, cfg.h_raw, cfg.w_raw, true));

% Inverse-map the valid mask as well.
validForMap = double(validRay);

camValidFloat = double(cfg.mapfun( ...
    validForMap, cfg.x_map_file, cfg.y_map_file, cfg.h_raw, cfg.w_raw, true));

camValid = camValidFloat > 0.5;

camImage(~camValid) = NaN;

end