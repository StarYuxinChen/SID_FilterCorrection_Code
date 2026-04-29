function [matrix]=fillZeros(matrix)
    [zero_row, zero_col] = find(matrix == 0);

    % Extrapolate values for zero elements using nearest four non-zero neighbors
    for i = 1:numel(zero_row)
        neighbors_values = [];
        % Check top neighbor
        if zero_row(i) > 1 && matrix(zero_row(i)-1, zero_col(i)) ~= 0
            neighbors_values = [neighbors_values, matrix(zero_row(i)-1, zero_col(i))];
        end
        % Check bottom neighbor
        if zero_row(i) < size(matrix, 1) && matrix(zero_row(i)+1, zero_col(i)) ~= 0
            neighbors_values = [neighbors_values, matrix(zero_row(i)+1, zero_col(i))];
        end
        % Check left neighbor
        if zero_col(i) > 1 && matrix(zero_row(i), zero_col(i)-1) ~= 0
            neighbors_values = [neighbors_values, matrix(zero_row(i), zero_col(i)-1)];
        end
        % Check right neighbor
        if zero_col(i) < size(matrix, 2) && matrix(zero_row(i), zero_col(i)+1) ~= 0
            neighbors_values = [neighbors_values, matrix(zero_row(i), zero_col(i)+1)];
        end

        % Assign value of the nearest four non-zero neighbors to the zero element
        if ~isempty(neighbors_values)
            matrix(zero_row(i), zero_col(i)) = mean(neighbors_values);
        end
    end
return 


