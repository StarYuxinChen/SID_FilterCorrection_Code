function C_k = interpolateCfitAtFrame(C_fit, fit_frame_centers, frame, min_positive_value)

t = fit_frame_centers(:);
Nt = numel(t);

if Nt < 2
    error('Need at least two fitted frame centers for interpolation/extrapolation.');
end

if frame <= t(1)
    i1 = 1;
    i2 = 2;
elseif frame >= t(end)
    i1 = Nt - 1;
    i2 = Nt;
else
    i2 = find(t >= frame, 1, 'first');
    i1 = i2 - 1;
end

a = (frame - t(i1)) / (t(i2) - t(i1));

C_k = (1 - a) * C_fit(:,:,i1) + a * C_fit(:,:,i2);
C_k(C_k <= min_positive_value) = min_positive_value;

end