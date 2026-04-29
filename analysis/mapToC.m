function [world,ind] = mapToC(input, x_map_file,y_map_file,h,w,inverse)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Inputs:
% 'input': Image to be mapped to world coords
% 'x_map_file, y_map_file': result of coord_system_create_mapping_array [:,:,0] & [:,:,1] saved as seperate text files
% 'h,w': hieght and width of matricies stored in x_map_file and y_map_file
% Output: 
% 'world': image in world coords 
% 'inverse': true performs inverse map ... improvements on inverse to come
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin < 6
   inverse = false; 
   A = 1;
end


x_map = text2mat(x_map_file,h,w);
y_map = text2mat(y_map_file,h,w);

[X,Y] = meshgrid(1:w,1:h);

A = 1; 
D = zeros(h,w,2);
D(:,:,1) = 1.0*flipud(x_map.');
D(:,:,2) = 1.0*flipud(y_map.');

if (inverse == false)
    world = imwarp(input,D);
    ind = flipud(world) == 0;
%     rightMean = mean(input(:,(w-10):w),2);
%     leftMean = mean(input(:,1:11),2);
%     
%     for i = 1:w
%         for j = 1:h
%             if (world(j,i) == 0 && i < w/2)
%                 world(j,i) = leftMean(j);
%             elseif (world(j,i) == 0 && i > w/2) 
%                 world(j,i) = rightMean(j);
%             end    
%         end
%     end
            
    
end

if (inverse)
    dummy = zeros(size(input)); 
    dummy = dummy + 100;
    ind = imwarp(dummy,D) == 0;
    
    Xmapped = X;
    Xmapped(ind) = 0;
    Ymapped = Y; 
    Ymapped(ind) = 0;

    unmapX = zeros(size(X));
    unmapY = zeros(size(Y));
    for i = 1:w
        for j = 1:h
            ii = int64(i + D(j,i,1)); 
            if (ii > 0 && ii < w)
                jj = int64(j + D(j,i,2));
                if (jj > 0 && jj < h)
                    unmapX(jj,ii) = Xmapped(j,i);
                    unmapY(jj,ii) = Ymapped(j,i);    
                end
            end    
        end
    end

    unmapX = fillZeros(unmapX);
    unmapY = fillZeros(unmapY);

    world = interp2(input, unmapX, unmapY,'spline');
end 