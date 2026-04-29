function x=df_dfm_read(fn,frms,p)
%DF_DFM_READ(fn,frms) Read DigiFlow movie frames

if nargin<2
  frms=[];
end
if nargin<3
  p=[];
end

if isempty(p);
  p = df_dfm_info(fn);
end

if isempty(frms)
  frms=1:p.nMovieFrames;
end

n = length(frms);

x = repmat(uint8(0),[p.sz([2 1 3]) n]);

if ischar(fn)
  f = fopen(fn,'r');
else
  f=fn;
end

for j=1:n
  fseek(f,p.iPtrFrame(frms(j)),'bof');
  [tx cnt]=fread(f,p.tsz,'uint8=>uint8');
  if cnt~=p.tsz
    warning(sprintf('Frame is missing data. File "%s" has been damaged',fn));
    x=[];
    return;
    j=j-1;
    break;
  else
    x(:,:,j)=permute(reshape(tx,p.sz([1 2 3])),[2 1 3]);
  end
end
if ischar(fn)
  fclose(f);
end

%x(:,:,:,j+1:end)=[];

return;



[tx cnt]=fread(f,p.tsz,'uint8=>uint8');
x(:,:)=permute(reshape(tx,p.sz([1 2 3])),[2 1 3]);
load_image(x);

f = fopen(fn,'r');
fseek(f,p.iPtrFrame(158),'bof');
[tx cnt]=fread(f,p.tsz,'uint8=>uint8');
x=permute(reshape(tx,p.sz([1 2 3])),[2 1 3]);
load_image(x);


f = fopen(fn,'r');
fseek(f,p.iPtrFrame(159),'bof');
[tx cnt]=fread(f,p.tsz,'uint8=>uint8');
x=permute(reshape(tx,p.sz([1 2 3])),[2 1 3]);
load_image(x);

