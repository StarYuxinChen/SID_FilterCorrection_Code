function saveDebugImage(A, outFile, figTitle)

    A = double(A);

    fig = figure('Visible', 'off');
    imagesc(A);
    axis image;
    axis ij;
    colorbar;
    title(figTitle, 'Interpreter', 'none');

    vals = A(isfinite(A));
    if ~isempty(vals)
        lo = prctile(vals(:), 1);
        hi = prctile(vals(:), 99);

        if isfinite(lo) && isfinite(hi) && hi > lo
            caxis([lo hi]);
        end
    end

    exportgraphics(fig, outFile, 'Resolution', 200);
    close(fig);
end