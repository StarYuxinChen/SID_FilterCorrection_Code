function out = computeFrameProductsFromFile(frame, cfg, pRaw, C_fit, rayMask)
%COMPUTEFRAMEPRODUCTSFROMFILE
%
% This function reads:
%   1. processed/model input image from tif sequence
%   2. original raw image from dfm movie
%
% The tif image is used to construct C_s and propagate the intensity sheet.
% The original dfm image is used as the denominator for Corr.

    % ------------------------------------------------------
    % Image used for model / concentration proxy
    % ------------------------------------------------------
    I_model_cam = readRawTifFrame(frame, cfg);

    % ------------------------------------------------------
    % Original raw image used as Corr denominator
    % ------------------------------------------------------
    I_raw_cam = readRawDfmFrame(frame, cfg, pRaw);

    % ------------------------------------------------------
    % Compute products
    % ------------------------------------------------------
    out = computeCorrForFrame(I_model_cam, I_raw_cam, frame, cfg, C_fit, rayMask);

end