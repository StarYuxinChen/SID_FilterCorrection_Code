%% MATLAB Script: Convert DigiFlow TIFF Range to Struct (Pixel Space & 100fps)
clear; clc; close all;

%% 1. Configuration
% -------------------------------------------------------------------------
inputDir   = 'V:\202311\w318\LIF-Processing\outputs';
outputDir  = 'V:\202311\w318\LIF-Processing\outputs';

filePrefix = 'w318_test5_';

% 帧范围（inclusive)
startFrame = 10000;
endFrame   = 20000;

fps = 100;
dt_original = 1 / fps;

stride = 2;

% 文件名中的帧号位数：
frameDigits = 5;

% 输出文件名
outputFilename = sprintf('w318_%d_%d.mat', startFrame, endFrame);

% 统一的文件名格式（自动补零）
frameFmt = sprintf('%%s%%0%dd.tif', frameDigits);  % -> '%s%05d.tif'

fprintf('Configuration:\n');
fprintf('  - Frame range: %d to %d (inclusive)\n', startFrame, endFrame);
fprintf('  - FPS: %d (dt_original = %.4fs)\n', fps, dt_original);
fprintf('  - Coordinate System: Pixel Space\n');
fprintf('  - Stride: %d (Skipping %d frames between samples)\n', stride, stride-1);
fprintf('  - Frame filename format: %s\n', frameFmt);
fprintf('  - Output: %s\n', outputFilename);

%% 2. Build Frame List
% -------------------------------------------------------------------------
frameNumsAll = startFrame:endFrame;
frameNums = frameNumsAll(1:stride:end);
numFiles = numel(frameNums);

fprintf('---------------------------------------------------\n');
fprintf('Frames to process after stride=%d: %d\n', stride, numFiles);
fprintf('First/Last processed frame: %d / %d\n', frameNums(1), frameNums(end));
fprintf('---------------------------------------------------\n');

%% 3. Read First Frame Info
% -------------------------------------------------------------------------
firstPath = fullfile(inputDir, sprintf(frameFmt, filePrefix, frameNums(1)));

if ~exist(firstPath, 'file')
    error('First file not found: %s\n(Check frameDigits=%d or naming pattern.)', firstPath, frameDigits);
end

info = imfinfo(firstPath);
rows = info.Height;
cols = info.Width;
bitDepth = info.BitDepth;

fprintf('Image Info: %d x %d pixels, %d-bit depth\n', rows, cols, bitDepth);

if bitDepth == 8
    maxVal = 255;
elseif bitDepth == 16
    maxVal = 65535;
else
    maxVal = 2^bitDepth - 1;
end
fprintf('Normalization Max Value: %d\n', maxVal);

bytesPerPixel = 4; % single
estGB = (rows * cols * numFiles * bytesPerPixel) / (1024^3);
fprintf('Estimated RAM usage (density only): %.2f GB\n', estGB);

try
    DataStruct.density = zeros(rows, cols, numFiles, 'single');
catch
    error('Out of Memory! Try increasing stride (e.g., stride=%d or more).', stride+1);
end

%% 4. Processing Loop
% -------------------------------------------------------------------------
hWait = waitbar(0, 'Reading and converting images...');
fprintf('Starting conversion...\n');

missingCount = 0;

for k = 1:numFiles
    frameID = frameNums(k);
    fullPath = fullfile(inputDir, sprintf(frameFmt, filePrefix, frameID));

    if ~exist(fullPath, 'file')
        warning('Missing file: %s (skipping)', fullPath);
        missingCount = missingCount + 1;
        continue;
    end

    img = imread(fullPath);

    if ndims(img) == 3 && size(img,3) == 3
        img = rgb2gray(img);
    end

    DataStruct.density(:,:,k) = single(img) / maxVal;

    if mod(k, 100) == 0 || k == numFiles
        waitbar(k / numFiles, hWait, sprintf('Processed: %d / %d', k, numFiles));
    end
end

close(hWait);

if missingCount > 0
    fprintf('WARNING: Missing files encountered: %d\n', missingCount);
end

fprintf('All requested frames processed (with stride).\n');

%% 5. Finalizing Struct
% -------------------------------------------------------------------------
fprintf('Building final struct...\n');

DataStruct.x = 1:cols;
DataStruct.y = 1:rows;

DataStruct.t = (frameNums - frameNums(1)) * dt_original;

DataStruct.frameNums   = frameNums;
DataStruct.startFrame  = startFrame;
DataStruct.endFrame    = endFrame;
DataStruct.stride      = stride;
DataStruct.fps         = fps;
DataStruct.dt_original = dt_original;
DataStruct.filePrefix  = filePrefix;
DataStruct.frameDigits = frameDigits;   % 记录补零位数，方便未来复现

%% 6. Save
% -------------------------------------------------------------------------
savePath = fullfile(outputDir, outputFilename);
fprintf('Saving to .mat file (v7.3): %s\n', savePath);

save(savePath, 'DataStruct', '-v7.3');

fprintf('---------------------------------------------------\n');
fprintf('DONE! File saved:\n  %s\n', savePath);
fprintf('---------------------------------------------------\n');
