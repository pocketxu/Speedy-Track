%% calculate ensemble-averaged MSD from Lstreaks structure

% -- parameters to adjust
pixelsize=0.16; % in micrometers
nlags=30; %number of time lags to calculate
dT=0.5075; % time separation in milliseconds. Keep in mind that in most cases the time separation is equal to the exposure time + the shifting time
fitind=4; % number of time lags to use in linear fit of MSD 
%---------


mfolder = fileparts(which(mfilename)); 
addpath(genpath(mfolder));

tlags=(1:nlags).*dT;

if exist('LastFolder','var')
    if LastFolder==0
        LastFolder=[];
    end
end

if exist('LastFolder','var')
    GetFileName=sprintf('%s/*.mat',LastFolder);
else
    GetFileName='*.mat';
end
[FileName,PathName] = uigetfile(GetFileName,'Select the .mat file with the Lstreaks variable');
filehead=FileName(1:end-4);

load([PathName FileName])
LastFolder=PathName;


FileNameKeyTol = 'Tol';
FindTolPos=strfind(filehead,FileNameKeyTol);
PreviousSearchRadius = sscanf(filehead(FindTolPos(end)+length(FileNameKeyTol):end),'%f',1);
savename=[PathName filehead '-displacements.mat'];

xgrid=(0:0.01:(PreviousSearchRadius*0.16));

PreviousSearchRadiusN=PreviousSearchRadius*0.16;

lagp=ones(1,nlags);

disall=nan(nlags, numel(Lstreaks).*40);
dxall=disall;
dyall=disall;

for i=1:numel(Lstreaks)

    x=Lstreaks(i).Xc;
    y=Lstreaks(i).Ycorrected;
    x(Lstreaks(i).valid==0)=NaN;
    y(Lstreaks(i).valid==0)=NaN;
    x(Lstreaks(i).valid==-1)=NaN;
    y(Lstreaks(i).valid==-1)=NaN;

    x=x.*pixelsize;
    y=y.*pixelsize;
    
    if sum(~isnan(x))<1
        continue
    end
    for j=1:min(length(x), nlags)
        dx=(x(1:end-j)-x(1+j:end));
        dx(isnan(dx))=[];
        dy=(y(1:end-j)-y(1+j:end));
        dy(isnan(dy))=[];
        disj=sqrt((x(1:end-j)-x(1+j:end)).^2 + (y(1:end-j)-y(1+j:end)).^2);
        disj(isnan(disj))=[];
        disj(disj>j*PreviousSearchRadiusN)=NaN;

        disall(j, (lagp(j):lagp(j)+length(disj)-1))=disj;
        dxall(j, (lagp(j):lagp(j)+length(dx)-1))=dx;
        dyall(j, (lagp(j):lagp(j)+length(dy)-1))=dy;
        lagp(j)=lagp(j)+length(disj);
    end
end

disall(:,max(lagp):end)=[];
dxall(:,max(lagp):end)=[];
dyall(:,max(lagp):end)=[];

msd=mean(disall.^2, 2,'omitnan');

figure
plot(tlags, msd, 'marker', 'o', 'linestyle', 'none', 'linewidth', 2, 'color', 'k')
hold on

c = polyfit(transpose(tlags(1:fitind)),msd(1:fitind),1);

slope=c(1);
intercept=c(2);

xfit=[0:tlags(end)/50:tlags(end)];
plot(xfit, xfit.*slope+intercept, 'linestyle', '--', 'color', 'k')
xlabel('Time lag (ms)')
ylabel('MSD (um^2)')

sprintf('D = %.4g um2/s', slope/4*1000)

save savename disall dxall dyall;


