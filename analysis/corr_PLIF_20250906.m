function [corr, mapped, streakRM, illFix, laser, laserRhoI] = correct_Plif_MI_20250906(rhoI, back, x_map_file, y_map_file, w, h, C0, streaks, synthetic_laser, Level, Sigma, LS, LE, resize, fftPad)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Inputs:
% 'rhoI': LIF image for correction
% 'x_map_file, y_map_file': result of coord_system_create_mapping_array [:,:,0] & [:,:,1]
% 'h,w': height and width of matrices stored in x_map_file, y_map_file, and rhoI
% 'C0': concentration of dye in background image C0 \in (0,1)
% 'streaks': boolean for removal of streaks in rhoI
% 'synthetic_laser': boolean to use generated laser sheet to correct image (false uses back)
% 'Level': number of levels used in wavelet decomposition for streak filter
% 'Sigma': standard deviation of filter applied to fft coeffs of wavelet transform
% 'LS': first level of wavelet transform you wish to filter
% 'LE': last level of wavelet transform you wish to filter
% 'resize': factor to increase image size, helps separate features on wavelet levels
% 'fftPad': factor to determine size of padding for wavelets before fft is applied
%
% Output:
% 'corr': corrected image
% 'laser': laser sheet used to correct image
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 1. Default Arguments
if nargin < 8;  streaks = false; end
if nargin < 9;  synthetic_laser = false; end
if nargin < 14; resize = 1; end
if nargin < 15; fftPad = false; end

%% 2. Initialization & Mapping
% Keep as false; option only exists for proof of concept tests
Conic = false;
% Conic = true;

if (Conic)
    map = @mapToC;
else
    map = @mapTo;
end

j0 = 20;
j1 = 0;
backIC = back(end-j0:end-j1, :);

backfilt = localmean(back, 25);
[back, ind] = map(back, x_map_file, y_map_file, h, w);

rhoIfilt = localmean(rhoI, 25);
rRho = fillEdges(flipud(rhoI));
rBack = fillEdges(flipud(back));

rhoI = double(map(rhoI, x_map_file, y_map_file, h, w));
mapped = flipud(rhoI);
mapped(ind) = 0;

rhoIfilt = double(map(rhoIfilt, x_map_file, y_map_file, h, w));
backfilt = double(map(backfilt, x_map_file, y_map_file, h, w));

% Orient images correctly
rhoI = flipud(rhoI);
back = flipud(back);
rhoIfilt = flipud(rhoIfilt);
backfilt = flipud(backfilt);

%% 3. Laser Sheet Reconstruction
if (synthetic_laser == true)
    bottom = mean(backIC, 1);
    w = size(back, 2); % assuming width is # of columns
    
    x = double(1:w);
    y = double(bottom);
    
    pfit = fit(x.', y.', 'gauss4');
    
    % % Plot original and fitted curve
    % figure;
    % plot(x, y, 'b-', 'LineWidth', 1.5); hold on;
    % plot(x, pfit(x), 'r--', 'LineWidth', 2);
    % title('IC with Gaussian Fit');
    % legend('Original Data', 'Gaussian Best Fit');
    
    bottom = pfit(x);
    % Ensure bottom is a row vector to match laser dimensions
    if iscolumn(bottom)
        bottom = bottom.';
    end
    
    % Initialize array for synthetic sheet
    laser = zeros(size(rhoI));
    laser(1, :) = bottom / C0;
    
    % Initialize array for coefficients (Beer-Lambert Gradient)
    % \alpha = - 1/(C0*p) (dp/ds)
    alpha = zeros(size(rhoI));
    
    % Row 1
    alpha(1, :) = -1.0 * (backfilt(2, :) - backfilt(1, :)) ./ (C0 * backfilt(1, :) + 1e-5);
    
    % Middle Rows
    for j = 2:h-1
        alpha(j, :) = -1.0 * (backfilt(j+1, :) - backfilt(j-1, :)) ./ (2.0 * C0 * backfilt(j, :) + 1e-5);
    end
    
    % Last Row
    alpha(h, :) = -1.0 * (backfilt(h, :) - backfilt(h-1, :)) ./ (C0 * backfilt(h, :) + 1e-5);
    
    % Alpha for Rho
    alphaRho = zeros(size(rhoI));
    alphaRho(1, :) = -1.0 * (backfilt(2, :) - backfilt(1, :)) ./ (C0 * rhoIfilt(1, :) + 1e-5);
    
    for j = 2:h-1
        alphaRho(j, :) = -1.0 * (backfilt(j+1, :) - backfilt(j-1, :)) ./ (C0 * 2.0 * rhoIfilt(j, :) + 1e-5);
    end
    
    alphaRho(h, :) = -1.0 * (backfilt(h, :) - backfilt(h-1, :)) ./ (C0 * rhoIfilt(h, :) + 1e-5);
    
    % Reconstruct laser using information from current frame
    laserRhoI = laser;
    laserRhoI(1, :) = bottom / C0;
    
    % Filter Alphas
    alpha = medfilt2(alpha, [11 11]);
    alphaRho = medfilt2(alphaRho, [11 11]);
    
    disp(mean(alpha(:)));
    
    % % Integrate Sheet Downwards
    % for j = 2:h
    %     laserRhoI(j, :) = laserRhoI(j-1, :) - alphaRho(j, :) .* rhoIfilt(j, :);
    %     laser(j, :) = laser(j-1, :) - alpha(j, :) .* backfilt(j, :);
    % end

    % Integrate Sheet Downwards
    for j = 2:h
        alphaRhoConstant = 1e-4;
        laserRhoI(j, :) = laserRhoI(j-1, :) - alphaRhoConstant .* rhoIfilt(j, :);
        laser(j, :) = laser(j-1, :) - alphaRhoConstant .* backfilt(j, :);
    end
    
    % Apply streak filter to the laser sheet to remove any defects
    laserRhoIfill = fillEdges(flipud(map(flipud(laserRhoI), x_map_file, y_map_file, h, w, true)));
    laserfill = fillEdges(flipud(map(flipud(laser), x_map_file, y_map_file, h, w, true)));
    
    laserRhoI(ind) = laserRhoIfill(ind);
    laser(ind) = laserfill(ind);
    
    laser(laser < 1e-5) = 1e-5;
    laserRhoI(laserRhoI < 1e-5) = 1e-5;
    
else
    % Standard background correction
    laser = back / C0;
    if (streaks == true)
        laser = RemoveStripesVertical(laser, Level, 'db42', Sigma, LS, LE, resize, fftPad);
    end
    % Initialize variable to prevent errors later if synthetic_laser is false
    laserRhoI = laser; 
end

%% 4. Streak Removal (Input Data)
if (streaks == true)
    % Step 1: compute row means before filtering
    laser = RemoveStripesPreserveProfile(laser, Level, Sigma, LS, LE, resize, fftPad, 'mult', 21);
    laserRhoI = RemoveStripesPreserveProfile(laserRhoI, Level, Sigma, LS, LE, resize, fftPad, 'mult', 21);
    
    rhoI(ind) = rRho(ind);
    rhoI = RemoveStripesPreserveProfile(rhoI, Level, Sigma, LS, LE, resize, fftPad, 'mult', 21);
    rhoI(ind) = 0;
    
    streakRM = rhoI;
    streakRM(ind) = 0;
    streakRM = flipud(streakRM);
else
    streakRM = rhoI;
end

%% 5. Final Correction Calculation
laser = flipud(laser);
laser(laser < 1e-5) = 1e-5;

rhoI = flipud(rhoI);

if (synthetic_laser == true)
    laserRhoI = flipud(laserRhoI);
    laserRhoI(laserRhoI < 1e-5) = 1e-5;
    
    back(ind) = rBack(ind);
    back = RemoveStripesVertical(back, Level, 'db42', Sigma, LS, LE, resize, fftPad);
    back = flipud(back);
    
    corr = rhoI ./ laserRhoI; % current estimate
else
    corr = rhoI ./ laser;
end

illFix = corr;

%% 6. Post-Processing & Normalization
if (Conic == true)
    corrfill = fillEdges(map(corr, x_map_file, y_map_file, h, w, true));
    corr(flipud(ind)) = corrfill(flipud(ind));
    corr = fftFilter(corr, 20, 10);
end

illFix(flipud(ind)) = 0;
corr(flipud(ind)) = 0;
corr = map(corr, x_map_file, y_map_file, h, w, true);

pLow = prctile((corr(:)), 1);   % 1st percentile
pHigh = prctile((corr(:)), 99); % 99th percentile
corr = ((corr) - pLow) / (pHigh - pLow);

corr(corr > 1) = 1;
corr(corr < 0) = 0;

end


function out = RemoveStripesPreserveProfile(img, Level, Sigma, LS, LE, resize, fftPad, ...
                                           method, winSize)
% RemoveStripesPreserveProfile
% Removes vertical stripes with profile preservation.
%
% INPUTS:
%   img     - input 2D image
%   Level   - wavelet level (for RemoveStripesVertical)
%   Sigma   - noise sigma (for RemoveStripesVertical)
%   LS, LE  - stripe region parameters (for RemoveStripesVertical)
%   resize  - resize factor (for RemoveStripesVertical)
%   fftPad  - fftPad parameter (for RemoveStripesVertical)
%   method  - 'mult' (multiplicative, preserves contrast) 
%             or 'add' (additive, preserves absolute background)
%   winSize - smoothing window size for mean profile
%
% OUTPUT:
%   out - filtered image with preserved horizontal profile

    % --- Step 1: row mean before filtering
    meanProf = mean(img, 2);

    % --- Step 2: smooth profile
    meanProf_smooth = smooth(meanProf, winSize, 'moving');

    % --- Step 3: filtering
    img_filt = RemoveStripesVertical(img, Level, 'db42', Sigma, LS, LE, resize, fftPad);

    % --- Step 4: row mean after filtering
    meanProf_after = mean(img_filt, 2);
    meanProf_after_smooth = smooth(meanProf_after, winSize, 'moving');

    % --- Step 5: correction
    switch lower(method)
        case 'mult'
            corrFactor = meanProf_smooth ./ (meanProf_after_smooth + eps);
            out = img_filt .* corrFactor;
        case 'add'
            corrOffset = meanProf_smooth - meanProf_after_smooth;
            out = img_filt + corrOffset;
        otherwise
            error('method must be ''mult'' or ''add''');
    end
end

function filt = localmean(back, ksize)
% LOCALMEAN 2D local averaging filter without edge magnitude drop
%
%   backfilt = LOCALMEAN(back, ksize) computes the local mean of the
%   2D array BACK using a square averaging window of size KSIZE x KSIZE.
%   The normalization adapts at edges so that the output does not
%   decrease in magnitude near the borders.
%
%   Example:
%       backfilt = localmean(back, 25);

    if nargin < 2
        ksize = 25; % default window size
    end

    % Make kernel
    kernel = ones(ksize, ksize);

    % Convolve input with kernel (sum of pixels)
    num = conv2(back, kernel, 'same');

    % Convolve mask of ones to count valid pixels at each location
    den = conv2(ones(size(back)), kernel, 'same');

    % Divide element-wise for normalized average
    filt = num ./ den;
end