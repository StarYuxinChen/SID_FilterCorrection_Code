function cropped = dfiRegion(input,xMin,xMax,yMin,yMax)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Inputs:
% 'input': Image for region to be extracted from 
% 'xMin, xMax, yMin, yMax': as defined in digiflow 
% Output: 
% 'cropped': Extracted region as in digiflow extract_region 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[N,M] = size(input);
cropped = input(N-(yMax-1):N-(yMin),xMin+1:xMax);    