% function result_image = filtWindow(image,window_size,filtType,sigma)
% 
% if nargin < 4
%     sigma = 0.5;
% end
% 
% if filtType == 2
%     % This type is currently using matlab default gaussian image filter but
%     % uncomment like 15 if user desires a more specialised kernel. 
% 
%     % Create the Gaussian kernel id desired
%     kernel = fspecial('gaussian', [window_size window_size], sigma);
% 
% 
%     result_image = zeros(size(image));
%     for i = 1:size(image, 1) - window_size + 1
%         for j = 1:size(image, 2) - window_size + 1
%             window = image(i:i + window_size - 1, j:j + window_size - 1);
%             %filtered_window = conv2(window, kernel, 'valid');
%             filtered_window = imgaussfilt(window);
%             result_image(i:i + window_size - 1, j:j + window_size - 1) = ...
%                 result_image(i:i + window_size - 1, j:j + window_size - 1) + filtered_window;
%         end
%     end
%     result_image = (result_image / (window_size^2));
% end 
% 
% if filtType == 1
%     result_image = zeros(size(image));
%     for i = 1:size(image, 1) - window_size + 1
%         for j = 1:size(image, 2) - window_size + 1
%             window = image(i:i + window_size - 1, j:j + window_size - 1);
%             sorted = sort(window(:));
%             meanValue = mean(sorted(1:int32((window_size^2))));
%             filtered_window = window;
%             filtered_window(window>meanValue) = meanValue;
%             result_image(i:i + window_size - 1, j:j + window_size - 1) = ...
%                 result_image(i:i + window_size - 1, j:j + window_size - 1) + filtered_window;
%         end
%     end
%     result_image = (result_image / (window_size^2));
%     magRes = mean(result_image(:));
%     magIn = mean(image(:));
%     result_image = result_image*magIn/magRes;
% end 
% 
% if filtType == 3
%     % This type is currently using matlab default gaussian image filter but
%     % uncomment like 15 if user desires a more specialised kernel. 
% 
%     % Create the Gaussian kernel id desired
%     %kernel = fspecial('gaussian', [window_size window_size], sigma);
%     kernel = ones(window_size,window_size)/(window_size^2);
% 
%     result_image = zeros(size(image));
%     for i = 1:size(image, 1) - window_size + 1
%         for j = 1:size(image, 2) - window_size + 1
%             window = image(i:i + window_size - 1, j:j + window_size - 1);
%             filtered_window = conv2(window, kernel, 'valid');
%             %filtered_window = imgaussfilt(window);
%             result_image(i:i + window_size - 1, j:j + window_size - 1) = ...
%                 result_image(i:i + window_size - 1, j:j + window_size - 1) + filtered_window;
%         end
%     end
%     result_image = (result_image / (window_size^2));
% end 
% 
% 
% if filtType == 4
%     % Idea:
%     %   1) build a "reference" image using median filter
%     %   2) find pixels that deviate too much from reference (outliers)
%     %   3) replace only those pixels with reference value
%     %
%     % sigma here is used as threshold multiplier k (typ. 4~8)
%     %   if sigma not provided (sigma==1 by default), use k=5
%     % Ensure window_size is odd for medfilt2
%     if mod(window_size, 2) == 0
%         ws = window_size + 1;
%     else
%         ws = window_size;
%     end
% 
%     % choose threshold multiplier k
%     if nargin < 4 || sigma == 1
%         k = 5;        % default
%     else
%         k = sigma;    % user-specified (e.g. 6 or 7)
%     end
% 
%     % reference (local median keeps interface sharp, removes salt-pepper)
%     Iref = medfilt2(image, [ws ws], 'symmetric');
% 
%     % residual
%     R = image - Iref;
% 
%     % robust sigma estimate via MAD
%     medR = median(R(:));
%     madR = median(abs(R(:) - medR));
%     robustSigma = 1.4826 * madR;
% 
%     % if robustSigma is ~0 (rare), just return reference
%     if robustSigma < eps
%         result_image = Iref;
%         return;
%     end
% 
%     mask = abs(R) > k * robustSigma;
% 
%     % replace only outliers
%     result_image = image;
%     result_image(mask) = Iref(mask);
% 
%     % safety: remove NaN/Inf if any
%     result_image(~isfinite(result_image)) = 0;
% end 
% 
% % Display the original and filtered images
% % figure;
% % subplot(1, 2, 1), imshow(image), title('Original Image');
% % subplot(1, 2, 2), imshow(result_image), title('Filtered Image');

function result_image = filtWindow_clean(image, window_size, filtType, sigma)
%FILTWINDOW_CLEAN Safer image filtering for PLIF scalar images.
%
% filtType:
%   1 = mild Gaussian
%   2 = median outlier replacement
%   3 = bilateral edge-preserving filter
%   4 = anisotropic diffusion
%   5 = simple box filter
%
% Important:
%   Apply this to scalar image, not RGB colormap image.

if nargin < 4 || isempty(sigma)
    sigma = 0.7;
end

I = double(image);

% keep original invalid mask
invalid = ~isfinite(I);

% temporary fill invalid pixels for filtering
I_work = I;
if any(invalid(:))
    medVal = median(I_work(isfinite(I_work)), 'omitnan');
    I_work(invalid) = medVal;
end

% ensure odd window size
if mod(window_size, 2) == 0
    window_size = window_size + 1;
end

switch filtType

    case 1
        % Mild Gaussian smoothing
        result_image = imgaussfilt(I_work, sigma, ...
            'FilterSize', window_size, ...
            'Padding', 'replicate');

    case 2
        % Median-based outlier replacement only
        k = sigma;
        if isempty(k) || k <= 0
            k = 5;
        end

        Iref = medfilt2(I_work, [window_size window_size], 'symmetric');
        R = I_work - Iref;

        medR = median(R(:), 'omitnan');
        madR = median(abs(R(:) - medR), 'omitnan');
        robustSigma = 1.4826 * madR;

        result_image = I_work;

        if robustSigma > eps
            mask = abs(R) > k * robustSigma;
            result_image(mask) = Iref(mask);
        end

    case 3
        % Bilateral filter, edge-preserving
        I_norm = mat2gray(I_work);
        degreeOfSmoothing = sigma;   % e.g. 0.002 to 0.01
        spatialSigma = max(1, window_size/2);
        result_norm = imbilatfilt(I_norm, degreeOfSmoothing, spatialSigma);

        % map back approximately to original range
        p = prctile(I_work(:), [1 99]);
        result_image = result_norm * (p(2)-p(1)) + p(1);

    case 4
        % Anisotropic diffusion
        I_norm = mat2gray(I_work);
        result_norm = imdiffusefilt(I_norm, ...
            'NumberOfIterations', max(1, round(window_size)), ...
            'GradientThreshold', sigma);

        p = prctile(I_work(:), [1 99]);
        result_image = result_norm * (p(2)-p(1)) + p(1);

    case 5
        % Simple box filter
        kernel = ones(window_size, window_size) / window_size^2;
        result_image = imfilter(I_work, kernel, 'replicate', 'same');

    otherwise
        error('Unknown filtType. Use 1, 2, 3, 4, or 5.');
end

% restore invalid pixels
result_image(invalid) = NaN;

end