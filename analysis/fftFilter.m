function corr_filtered = fftFilter(corr,xMax,yMin)
    % Compute the 2D FFT
    spec = fft2(corr);
    
    % Get the size of the input matrix
    [Nx, Ny] = size(corr);
    
    % Create frequency domain coordinates
    kx = (-floor(Nx/2):ceil(Nx/2)-1) / Nx * 2 * pi;
    ky = (-floor(Ny/2):ceil(Ny/2)-1) / Ny * 2 * pi;
    
    % Shift the FFT for visualization and processing
    spec_shifted = fftshift(spec);
    
    yMin = yMin / Ny * 2 * pi;
    xMax = xMax / Nx * 2 * pi;

    % Define the condition for filtering
    for i = 1:Nx
        for j = 1:Ny
            if ((abs(ky(j))>yMin) && (abs(kx(i))<xMax))
            %if ((abs(ky(j))<xMax) && (abs(kx(i))>yMin))    
                spec_shifted(i,j)  = 0;
            end
        end
    end
    
    % Shift back and compute the inverse FFT
    spec_filtered = ifftshift(spec_shifted);
    image = ifft2(spec_filtered);
    
    % Extract the real part as the final output
    corr_filtered = real(image);
end