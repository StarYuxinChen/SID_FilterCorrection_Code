function fname = getRawTifFilename(frameIndex, cfg)
%GETRAWTIFFFILENAME Build filename for one tif frame.

    fileNumber = cfg.tif_first_file_number + ...
        (frameIndex - cfg.tif_first_frame_index);

    fname = fullfile(cfg.tif_dir, sprintf(cfg.tif_name_fmt, fileNumber));
end