function C_fit = buildCameraCorrectionField(starModel, x_raw_mm, h_raw, w_raw, ...
                                            z_bot_mm, z_top_mm, min_positive_value)

I_b = starModel.I_b;
I_t = starModel.I_t;
x_common = starModel.x_common;

Nt_fit = size(I_b, 2);

I_b_raw = zeros(w_raw, Nt_fit);
I_t_raw = zeros(w_raw, Nt_fit);

for j = 1:Nt_fit
    I_b_raw(:,j) = interp1(x_common(:), I_b(:,j), x_raw_mm(:), 'linear', 'extrap');
    I_t_raw(:,j) = interp1(x_common(:), I_t(:,j), x_raw_mm(:), 'linear', 'extrap');
end

% physical z measured from bottom upward,
% but array row 1 is physical top, row h_raw is physical bottom.
z_phys_row_mm = (h_raw - (1:h_raw)) / (x_raw_mm(2)-x_raw_mm(1)) / h_raw;
% Safer explicit version:
px_per_mm_local = 1 / (x_raw_mm(2)-x_raw_mm(1));
z_phys_row_mm = (h_raw - (1:h_raw)) / px_per_mm_local;

eta_z = (z_phys_row_mm(:) - z_bot_mm) / (z_top_mm - z_bot_mm);
eta_z = max(0, min(1, eta_z));

C_fit = zeros(h_raw, w_raw, Nt_fit);

for iz = 1:h_raw
    Cz = (1 - eta_z(iz)) * I_b_raw + eta_z(iz) * I_t_raw;   % w_raw x Nt_fit
    C_fit(iz,:,:) = reshape(Cz, [1, w_raw, Nt_fit]);
end

C_fit(C_fit <= min_positive_value) = min_positive_value;

end