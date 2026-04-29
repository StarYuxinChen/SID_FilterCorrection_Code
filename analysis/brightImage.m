clear; clc; close all;

%% =========================================================
% Build a raw-like corrected bright image for Stefan
% IMPORTANT:
% fIn4 must be raw-like because Stefan will subtract black internally.
%% =========================================================

fBlack = "V:\202311\w318\LIF-Processing\inputs\CamC_black.dfi";
fBrightRaw = "V:\202311\w318\LIF-Processing\inputs\CamC_bright.dfi";

fCorr = "V:\202311\w318\LIF-Processing\outputs\Corr_model_w318.mat";

fOut = "V:\202311\w318\LIF-Processing\inputs\CamC_bright_corrMean_rawLike_forStefan.tif";

%% crop used in your current pass1/pass2
crop_x = 30:3300;
crop_y = 20:1015;

%% ---------------- read black and raw bright ----------------
Sblack = dfi2mat(char(fBlack));
Sbright = dfi2mat(char(fBrightRaw));

blackBright = double(Sblack.image);
brightRaw   = double(Sbright.image);

[h, w] = size(brightRaw);

%% ---------------- load Corr_mean ----------------
S = load(fCorr);

if ~isfield(S, "Corr_mean")
    error("Corr_mean not found in %s", fCorr);
end

Corr_mean = double(S.Corr_mean);

if ~isequal(size(Corr_mean), size(brightRaw))
    error("Corr_mean size does not match bright image size.");
end

%% ---------------- make valid crop mask ----------------
validCrop = false(h, w);
validCrop(crop_y, crop_x) = true;

validCorr = isfinite(Corr_mean) & Corr_mean > 0;
valid = validCrop & validCorr;

%% ---------------- construct corrected signal ----------------
brightSignal = brightRaw - blackBright;

fprintf("\nBefore correction: brightSignal stats\n");
printStats(brightSignal, valid, "brightRaw - blackBright");

% Do not allow obviously nonphysical negative reference signal
% This is diagnostic first. If many pixels are negative, the source bright/black
% scaling is already wrong.
negFrac = mean(brightSignal(valid) < 0, "omitnan");
fprintf("Negative fraction inside crop before correction = %.4f\n", negFrac);

%% Apply Corr_mean only to the signal part
brightSignalCorr = brightSignal;

brightSignalCorr(valid) = Corr_mean(valid) .* brightSignal(valid);

%% Outside crop: keep the original raw bright signal.
% This avoids NaNs propagating through Stefan's unchanged code.
brightSignalCorr(~validCrop) = brightSignal(~validCrop);

% For invalid Corr inside crop, also keep original signal for now.
badInside = validCrop & ~validCorr;
brightSignalCorr(badInside) = brightSignal(badInside);

%% Optional safety floor
% Use a very small positive floor only for the signal after checking stats.
smallPositive = prctile(brightSignal(valid), 1);
smallPositive = max(smallPositive, 1e-6);

brightSignalCorr(validCrop) = max(brightSignalCorr(validCrop), smallPositive);

fprintf("\nAfter correction: brightSignalCorr stats\n");
printStats(brightSignalCorr, validCrop, "corrected bright signal");

%% Put black back to make a raw-like image for Stefan
brightForStefan = blackBright + brightSignalCorr;

fprintf("\nFinal fIn4 raw-like image stats\n");
printStats(brightForStefan, validCrop, "brightForStefan");

%% ---------------- save as 32-bit float TIFF ----------------
writeFloatTiff(fOut, single(brightForStefan));

fprintf("\nSaved raw-like corrected bright image for Stefan:\n%s\n", fOut);

%% ---------------- quick diagnostic plot ----------------
figure("Color","w");

subplot(1,3,1);
imagesc(brightRaw); axis image; colorbar;
title("raw bright");

subplot(1,3,2);
imagesc(brightSignal); axis image; colorbar;
title("bright - black");

subplot(1,3,3);
imagesc(brightSignalCorr); axis image; colorbar;
title("Corr\_mean corrected signal");

exportgraphics(gcf, replace(fOut, ".tif", "_diagnostic.png"), "Resolution", 200);


%% =========================================================
% helper functions
%% =========================================================
function printStats(A, mask, name)
    vals = A(mask);
    vals = vals(isfinite(vals));

    fprintf("\n%s\n", name);
    fprintf("  min    = %.6g\n", min(vals));
    fprintf("  p01    = %.6g\n", prctile(vals, 1));
    fprintf("  p50    = %.6g\n", prctile(vals, 50));
    fprintf("  p99    = %.6g\n", prctile(vals, 99));
    fprintf("  max    = %.6g\n", max(vals));
    fprintf("  mean   = %.6g\n", mean(vals));
    fprintf("  neg %%  = %.4f\n", 100 * mean(vals < 0));
end

function writeFloatTiff(filename, A)
    t = Tiff(char(filename), "w");

    tagstruct.ImageLength = size(A,1);
    tagstruct.ImageWidth = size(A,2);
    tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
    tagstruct.BitsPerSample = 32;
    tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
    tagstruct.SamplesPerPixel = 1;
    tagstruct.RowsPerStrip = 16;
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.Compression = Tiff.Compression.None;

    t.setTag(tagstruct);
    t.write(single(A));
    t.close();
end