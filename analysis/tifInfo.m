clear; clc; close all;

%% =========================================================
% CHECK TIFF SEQUENCE INFORMATION
%% =========================================================

tif_dir = "V:\202311\w318\LIF-Processing\outputs";
tif_fmt = "w318_test5_%05d.tif";

% Check representative frames
check_frames = [1, 11000, 15000, 30000, 59000, 60757];

for n = 1:numel(check_frames)

    frameNo = check_frames(n);
    fname = fullfile(tif_dir, sprintf(tif_fmt, frameNo));

    fprintf('\n=========================================\n');
    fprintf('Checking frame/file number: %d\n', frameNo);
    fprintf('File: %s\n', fname);

    if ~isfile(fname)
        fprintf('FILE DOES NOT EXIST.\n');
        continue;
    end

    info = imfinfo(fname);

    fprintf('Number of pages in tif = %d\n', numel(info));
    fprintf('Width  = %d\n', info(1).Width);
    fprintf('Height = %d\n', info(1).Height);
    fprintf('BitDepth = %d\n', info(1).BitDepth);
    fprintf('ColorType = %s\n', info(1).ColorType);
    fprintf('Compression = %s\n', info(1).Compression);

    I = imread(fname);

    fprintf('MATLAB class = %s\n', class(I));
    fprintf('size(I) = ');
    disp(size(I));

    if ndims(I) == 3
        fprintf('This image has %d channels.\n', size(I,3));

        if size(I,3) == 3
            R = double(I(:,:,1));
            G = double(I(:,:,2));
            B = double(I(:,:,3));

            fprintf('max(abs(R-G)) = %.6g\n', max(abs(R(:)-G(:))));
            fprintf('max(abs(R-B)) = %.6g\n', max(abs(R(:)-B(:))));

            if max(abs(R(:)-G(:))) == 0 && max(abs(R(:)-B(:))) == 0
                fprintf('RGB channels are identical. This is effectively grayscale.\n');
                I2 = I(:,:,1);
            else
                fprintf('WARNING: RGB channels are different. This may be colour-mapped image, not raw intensity.\n');
                I2 = rgb2gray(I);
            end
        else
            error('Unexpected number of channels.');
        end
    else
        I2 = I;
    end

    Id = double(I2);

    fprintf('After grayscale conversion:\n');
    fprintf('class = %s\n', class(I2));
    fprintf('min   = %.6g\n', min(Id(:)));
    fprintf('max   = %.6g\n', max(Id(:)));
    fprintf('mean  = %.6g\n', mean(Id(:), 'omitnan'));
    fprintf('std   = %.6g\n', std(Id(:), 0, 'omitnan'));
    fprintf('p01   = %.6g\n', prctile(Id(:), 1));
    fprintf('p50   = %.6g\n', prctile(Id(:), 50));
    fprintf('p99   = %.6g\n', prctile(Id(:), 99));

    h = size(Id,1);
    topMean = mean(Id(1:50,:), 'all', 'omitnan');
    botMean = mean(Id(end-49:end,:), 'all', 'omitnan');

    fprintf('Top 50-row mean    = %.6g\n', topMean);
    fprintf('Bottom 50-row mean = %.6g\n', botMean);
    fprintf('Bottom / Top ratio = %.6g\n', botMean / max(topMean, eps));

    % Display one or two frames only
    if ismember(frameNo, [11000, 59000])
        figure;
        imagesc(Id);
        axis image;
        set(gca, 'YDir', 'normal');
        colorbar;
        colormap gray;
        title(sprintf('TIFF frame/file %05d, displayed with YDir normal', frameNo));

        figure;
        imagesc(Id);
        axis image;
        axis ij;
        colorbar;
        colormap gray;
        title(sprintf('TIFF frame/file %05d, displayed with axis ij', frameNo));
    end
end