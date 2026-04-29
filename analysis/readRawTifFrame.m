function I = readRawTifFrame(frameIndex, cfg)
%READRAWTIFFRAME Read one raw frame from the saved tif sequence.
%
% frameIndex = physical/original frame index, e.g. 11000.
% The corresponding file is:
%   w318_test5_11000.tif
%
% The image is returned as double, but the original 0--255 scale is kept.

    fname = getRawTifFilename(frameIndex, cfg);

    if ~isfile(fname)
        error('TIFF file not found for frameIndex %d:\n%s', frameIndex, fname);
    end

    Iraw = imread(fname);

    % Handle unexpected RGB tif safely
    if ndims(Iraw) == 3
        if size(Iraw,3) == 3
            R = Iraw(:,:,1);
            G = Iraw(:,:,2);
            B = Iraw(:,:,3);

            if isequal(R, G) && isequal(R, B)
                Iraw = R;
            else
                warning(['TIFF frame %d is RGB and channels are not identical. ', ...
                         'Using rgb2gray, but this may not preserve raw LIF intensity.'], ...
                         frameIndex);
                Iraw = rgb2gray(Iraw);
            end
        else
            error('Unexpected TIFF channel number for frameIndex %d.', frameIndex);
        end
    end

    if isfield(cfg, 'normalise_tif') && cfg.normalise_tif
        % Usually NOT recommended here, because it changes the alpha scale.
        switch class(Iraw)
            case 'uint8'
                I = double(Iraw) / 255;
            case 'uint16'
                I = double(Iraw) / 65535;
            otherwise
                I = double(Iraw);
        end
    else
        % Recommended for your current pipeline:
        % keep the original 0--255 intensity scale.
        I = double(Iraw);
    end
end