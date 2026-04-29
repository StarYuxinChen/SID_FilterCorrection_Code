function [nima]=RemoveStripesVertical(im,decNum,wname,sigma,levelStart,levelEnd,resize,fftPad)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Inputs:
% 'im': imput image to filter
% 'decNum': number of levels used in wavelet decomposition for streak filter
% 'wname': name of wavelet type to be used for decomposition
% 'sigma':  standard deviation of filter applied to fft coeffs of wavelet tranform 
% 'levelStart': first level of wavelet transform you wish to filter
% 'levelEnd': last level of wavelet transfomr you with to filter 
% 'resize': factor to increse image size by, help to seperate features onto different levels of wavelet transform
% 'fftPad': factor to determine size of padding for wavelets before fft is applied 
% for more information on wavelet filter see munch et al. 2009: 
% "Stripe and ring artifact removal with combined wavelet — Fourier filtering"
% Output: 
% 'nima': filtered image 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 7
    resize = 1;
end
if nargin < 8
    fftPad = 1;
end

%increase resolution of image artifically to allow better seperation of
%features with wavelet decomposition. 
% mag = rms(im(:));
ima = imresize(im,resize);

% wavelet decomposition
for ii=1:decNum
    [ima,Ch{ii},Cv{ii},Cd{ii}]=dwt2(ima,wname);
    [n{ii},m{ii}] = size(Cv{ii});
end

% FFT transform of horizontal frequency bands
for ii=levelStart:levelEnd
    % FFT
    pady = fftPad*n{ii};
    padx = fftPad*m{ii};
    padded = zeros(pady,padx);
    padded(1:n{ii},1:m{ii}) = Cv{ii};
    
    %uncomment and use if you want to position coeffs in centre of padded region 
    %sy = pad/2 - floor(n{ii}/2);
    %ey = pad/2 + ceil(n{ii}/2) - 1;
    %sx = pad/2 - floor(m{ii}/2);
    %ex = pad/2 + ceil(m{ii}/2) - 1;
    %padded(sy:ey,sx:ex) = Cv{ii};
    
    fCv=fftshift(fft(padded));
    [my,mx]=size(fCv);
    
    % damping of vertical stripe information
    damp=1-exp(-[-floor(my/2):-floor(my/2)+my-1].^2/(2*sigma^2));
    fCv=fCv.*repmat(damp',1,mx);
    
    % inverse FFT
    fCv = ifftshift(fCv);
    padded=ifft((fCv));
    Cv{ii} = padded(1:n{ii},1:m{ii});
    %Cv{ii} = padded(sy:ey,sx:ex);
end
% wavelet reconstruction
nima=ima;
for ii=decNum:-1:1
    nima=nima(1:size(Ch{ii},1),1:size(Ch{ii},2));
    nima=idwt2(nima,Ch{ii},Cv{ii},Cd{ii},wname);
end

nima = imresize(nima,1/resize);
% magN = rms(nima(:));
% nima = (mag/magN)*(nima);

return