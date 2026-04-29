function p = df_dfm_info(fn)
%DF_DMF_INFO(fn) Get Information on a digiflow ".dfm" file

if ~exist(fn,'file') | exist(fn,'dir')
  error(['Could not find "' fn '"']);
end

f = fopen(fn,'r','ieee-le');

p.fileowner = char(fread(f,8,'uchar=>uchar'))';

p.version     = char(fread(f,8,'uchar=>uchar'))';
p.iPtrHistory = fread(f,1,'uint');
p.FileType    = char(fread(f,16,'uchar=>uchar'))';
p.Comments    = char(fread(f,220,'uchar=>uchar'))';

if ~strcmp(p.fileowner,'DigImage')
  disp(sprintf('Not a DigImage movie "%s"',fn));
  p=[];
  return;
end
if ~strcmp(p.FileType(1:15),['DigImage Movie' 13])
  disp(sprintf('Not a DigImage movie "%s"',fn));
  p=[];
  return;
end

% 256 bytes to here

% History Header Information

p.iPtrPrivateHeader = fread(f,1,'uint32');
p.iDummy            = fread(f,1,'uint32');
p.CreatedBy         = char(fread(f, 8,'uchar=>uchar'))';
p.Hversion          = char(fread(f, 8,'uchar=>uchar'))';
p.CreatedUser       = char(fread(f,16,'uchar=>uchar'))';
p.CreatedName       = char(fread(f,64,'uchar=>uchar'))';
p.CreatedDate       = char(fread(f, 8,'uchar=>uchar'))';
p.CreatedTime       = char(fread(f, 8,'uchar=>uchar'))';
p.ModifiedUser      = char(fread(f,16,'uchar=>uchar'))';
p.ModifiedName      = char(fread(f,64,'uchar=>uchar'))';
p.ModifiedDate      = char(fread(f, 8,'uchar=>uchar'))';
p.ModifiedTime      = char(fread(f, 8,'uchar=>uchar'))';
p.UnUsed            = char(fread(f,40,'uchar=>uchar'))';

% History Header Information

% Movie Header Information

p.iFormatType     = fread(f,1,'uint16'); % 0 raw bit image
                                         % 1 Aligned to 8 byte boundaries
p.iFrameRate      = fread(f,1,'uint16'); % Number of frames per second
p.iSampleSpacing  = fread(f,1,'uint32'); % Number of frames between images
p.iMovieDuration  = fread(f,1,'uint32'); % Number of orignial frames
p.iPtrFrameTable  = fread(f,1,'uint32'); % Points to the start of
                                         % the table containing the
                                         % frame data
p.nMovieFrames = fread(f,1,'uint32'); % Number of movie frames
p.iw0 = fread(f,1,'uint16'); % First row stored for the image
p.iw1 = fread(f,1,'uint16'); % Last  row stored for the image
p.jw0 = fread(f,1,'uint16'); % First column stored for the image
p.jw1 = fread(f,1,'uint16'); % Last  column stored for the image
p.idi = fread(f,1,'uint16'); % Step between sampled rows
p.jdj = fread(f,1,'uint16'); % Step between sampled columns
p.nSize = fread(f,1,'uint32'); % Number of image pixels =(iw1-iw0+1)*(jw1-jw0+1)
p.AspectRatio = fread(f,1,'float32'); % Aspect ratio of pixels
p.nBits = fread(f,1,'uint16'); % Number of bit planes
p.iOLUTRed   = fread(f,256,'uchar'); % Red component of OLUT
p.iOLUTGreen = fread(f,256,'uchar'); % Green component of OLUT
p.iOLUTBlue  = fread(f,256,'uchar'); % Blue component of OLUT
p.nFrameTableLength= fread(f,1,'uint32'); % Number of bytes in Frame table
p.RecordAtFieldSpacing = fread(f,1,'uint16'); % Indicates if the
                                              % recording sample
                                              % spacing is
                                              % determined bu
                                              % iSampleSpacing or
                                              % dtSampleSpacing
p.dtSampleSpacing = fread(f,1,'float32'); % Nominal Sample Spacing
p.UnUsed  = fread(f,204,'uchar');

if ftell(f)+1~=p.iPtrFrameTable
  error('Internal error. Read the wrong number of bytes');
end

% Doesn't make sense why this is -1
fseek(f,p.iPtrFrameTable-1,'bof');
y = reshape(fread(f,p.nMovieFrames*2,'int64'),2,p.nMovieFrames);
	

p.iFrameNumber = y(1,:);
p.iPtrFrame    = y(2,:);

fclose(f);


p.sz = [(p.jw1-p.jw0+1) (p.iw1-p.iw0+1) 1];
p.tsz=prod(p.sz);
p.num_frames = p.nMovieFrames;

return

% This is how to read the movies

for j=1:p.nMovieFrames
  fseek(f,p.iPtrFrame(j),'bof');
  x=reshape(fread(f,p.tsz,'uchar=>uchar'),p.sz(1:2));
  plot(x(1:2,:)')
  %imshow(x(1:200,:))
  drawnow
end




fclose(f);
