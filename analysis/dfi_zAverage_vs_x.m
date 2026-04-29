function [x_pix, x_mm, Czmean_x, meta] = dfi_zAverage_vs_x(inFile, px_per_mm, planeName)
%DFI_ZAVERAGE_VS_X  Read a DigiFlow .dfi image plane and compute z-average profile vs x.
%
% Inputs
%   inFile    : path to .dfi
%   px_per_mm : pixels per mm (e.g. 22)
%   planeName : (optional) which image plane to use, must match output.imageList entry
%               if omitted/empty, auto-picks the largest 2D plane
%
% Outputs
%   x_pix     : 1 x nx pixel index
%   x_mm      : 1 x nx physical x (mm)
%   Czmean_x  : 1 x nx z-averaged concentration/intensity
%   meta      : info about which plane was used, size, etc.

    if nargin < 2 || isempty(px_per_mm)
        error('px_per_mm is required, e.g. 22.');
    end
    if nargin < 3
        planeName = "";
    end

    % ---- 1) read dfi -> structure ----
    [out, debug] = dfi2mat(inFile); %#ok<NASGU>

    if ~isfield(out, 'imageList') || isempty(out.imageList)
        error('dfi2mat output has no imageList or it is empty.');
    end

    % ---- 2) choose image plane ----
    img = [];
    usedName = "";

    if strlength(planeName) > 0
        % user specified
        if isfield(out, planeName)
            img = out.(planeName);
            usedName = char(planeName);
        else
            error('Requested planeName "%s" not found in output fields.', planeName);
        end
    else
        % auto pick: among imageList entries, pick the largest 2D numeric array
        bestScore = -Inf;
        for k = 1:numel(out.imageList)
            nm = out.imageList{k};
            if isfield(out, nm)
                candidate = out.(nm);
                if isnumeric(candidate) && ismatrix(candidate)
                    sz = size(candidate);
                    score = prod(sz);  % prefer largest area
                    if score > bestScore
                        bestScore = score;
                        img = candidate;
                        usedName = nm;
                    end
                end
            end
        end

        if isempty(img)
            error('No usable 2D numeric image plane found in output.imageList.');
        end
    end

    % ---- 3) convert to double for safe math ----
    C = double(img);

    % ---- 4) z-average along dimension 1 ----
    % Assume C is [nz, nx] where rows correspond to z, columns to x.
    % If你的数据是反过来的（nx,nz），下面会给你一个简单判据修正（见注释）。
    [nz, nx] = size(C);

    % 简单启发：很多相机图像 nx 通常 > nz（宽 > 高）
    % 如果你发现你的 profile 很怪，或者 size(C) 显示 nz >> nx，
    % 你可以把这段打开做转置：
    % if nz > nx
    %     C = C.';  % now [nz,nx] expected
    %     [nz,nx] = size(C);
    % end

    Czmean_x = mean(C, 1, 'omitnan');  % 1×nx

    % ---- 5) x axis ----
    x_pix = 1:nx;
    mm_per_pixel = 1/px_per_mm;
    x_mm = (x_pix - 1) * mm_per_pixel;

    % ---- 6) plot ----
    % figure('Color','w'); 
    % plot(x_mm, Czmean_x, 'LineWidth', 1.8);
    % grid on; box on;
    % xlabel('x (mm)');
    % ylabel('<C>_z (z-average)');
    % title(sprintf('z-average vs x', usedName), 'Interpreter','none');

    % ---- 7) meta ----
    meta = struct();
    meta.planeUsed = usedName;
    meta.sizeC = [nz, nx];
    meta.px_per_mm = px_per_mm;
end
