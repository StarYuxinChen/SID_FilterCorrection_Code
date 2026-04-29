function I = readRawDfmFrame(frame, cfg, pRaw)
%READRAWDFMFRAME Read one frame from the original .dfm movie.
%
% The output is returned as double.

    fidRaw = fopen(cfg.fRaw_char, 'rb');

    if fidRaw == -1
        error('Could not open raw movie file: %s', cfg.fRaw_char);
    end

    cleaner = onCleanup(@() fclose(fidRaw));

    Iraw = df_dfm_read(fidRaw, frame, pRaw);

    Iraw = squeeze(Iraw);

    if ndims(Iraw) > 2
        Iraw = Iraw(:,:,1);
    end

    I = double(Iraw);
end