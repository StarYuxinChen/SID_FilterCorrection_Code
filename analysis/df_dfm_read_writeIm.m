function x=df_dfm_read_writeIm(fn,loc,start,finish)
%df_dfm_read_writeIm(fn,loc,start,finish) read DigiFlow movie frames
% e.g. loc = '/home/crsid/Documents/Images_' will save images named 'Images_#####.png' in the folder '/home/crsid/Documents/';
% NB start and finish refer the image numbering in the sequence 1,2,...,n. (as per digiflow) output images are numbered in the sequence 0,1,...n-1.

%df_dfm_read_writeIm('/media/hcb39/Henry/Lab_Data/Plumes_2014/Plume_201114_T01.dfm','/media/hcb39/Henry/Lab_Data/Plumes_2014/Plume_2014_11_20_T01/Plume_2014_11_20_T01_');

if nargin<2
  error('You must at least specify a file-path for the source dfm and a name/file-path&name for the output png files');
end

Name = loc;
p = df_dfm_info(fn);
frms=1:p.nMovieFrames;

n = length(frms);
if nargin<3
  start=1;  
  finish=n;
elseif nargin<4 
  finish=n;
end

f = fopen(fn,'r');

for j=start:finish
  x = zeros(p.sz([2 1]),'uint8');
  fseek(f,p.iPtrFrame(frms(j)),'bof');
  [tx cnt]=fread(f,p.tsz,'uint8=>uint8');
  if cnt~=p.tsz
    warning(sprintf('Frame is missing data. File "%s" has been damaged',fn));
    x=[];
    return;
    j=j-1;
    break;
  else
    x(:,:)=permute(reshape(tx,p.sz([1 2 3])),[2 1 3]);
  end
  imwrite(x,strcat(Name,num2str(j-1,'%05.0f'),'.png')); 
end

if ischar(fn)
  fclose(f);
end
%x(:,:,:,j+1:end)=[];

return;