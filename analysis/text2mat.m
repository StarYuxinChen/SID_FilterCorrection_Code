function matrix = text2mat(file_location, no_columns, no_rows)
%Function to generate coordinate mapping matrix from .txt file.
%Inputs:
%   'file_location'
%   'no_colums' : number of columns in input file 
%   'no_rows' : number of rows in input file
%
%Outputs
%   'mat'   : matrix corresponding to the columns and rows of .txt file

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Open file
file_ID = fopen(file_location,'r');
formatSpec = ['%f'];

scanned_txt = fscanf(file_ID,formatSpec);

%Initialise output matrix
% if mapping_type == 2
%     no_columns = 4;
%     no_rows = 9;
% 
% elseif mapping_type == 3
%     no_columns = 4;
%     no_rows = 13;
% else 
%     
% end

matrix = zeros(no_columns,no_rows);

%Fill output matrix
for i = 1: no_columns*no_rows
    matrix(i) = scanned_txt(i);
end

%Transpose so it is equivalent to .txt file
matrix = transpose(matrix);
%end
