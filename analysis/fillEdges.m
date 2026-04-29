function B = fillEdges(A)
    % FILLEdges replicates the first and last columns of matrix A
    % into the left and right halves of a new matrix B of the same size.
    %
    % Usage:
    %   B = fillEdges(A)
    %
    % A: Input matrix (ny x nx)
    % B: Output matrix (ny x nx)
    
    [ny, nx] = size(A);
    B = zeros(ny, nx);
    
    % Compute midpoint (integer division)
    mid = floor(nx / 2);
    
    % Fill left half with first column
    B(:, 1:mid) = repmat(mean(A(:, 1:20),2), 1, mid);
    
    % Fill right half with last column
    B(:, mid+1:end) = repmat(mean(A(:, end-20:end),2), 1, nx - mid);
end