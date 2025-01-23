mfolder = fileparts(which(mfilename)); 
addpath(genpath(mfolder));

%--- parameters to adjust ---
dt=0.5; %time delay in ms

%-- select trajectories to plot
loadnew=0;
starttraj=1; 
endtraj=0; %use 0 to default to final trajectory
minpercentvalid=0.5; 
minlength=18; %only plot trajectories longer than min
selectROI=0; %only plot trajectories within a selected ROI
xrange=[185, 225]; %Define ROI in pixels        
yrange=[325, 355];
yoffset=0;

%-- select plotting styles
plotmode= 'image'; %possible modes are 'tiled' or 'image'
trajcolor='Dest'; %possible modes are 'Dest', and 'none'
onlyconnected=0; %if 1, will stop plotting that trajectory when meeting a "skip"

Drange=[0 20];  %Range for coloring with meanD, in um2/s
pixelsize=0.16; % in microns
hnum=5; %number of trajectories displayed horizontally in tiled mode
highdis=6; %maximum expected displacement in pixels, used for setting the space between trajectories for tiled mode

%-------------------------

close all

if selectROI==0
    xrange=[-inf, inf];
    yrange=[-inf, inf];
end

%load statement
if loadnew
    clearvars Lstreaks
end
if ~exist('Lstreaks','var')
    if exist('LastFolder','var')
        GetFileName=sprintf('%s/*.mat',LastFolder);
    else
        GetFileName='*.mat';
    end
    [FileName,PathName] = uigetfile(GetFileName,'Select the mat file with streaks');
    LastFolder=PathName;
    sFile =sprintf('%s%s',PathName,FileName);
    load(sFile);
end
if ~exist('Lstreaks','var') %convert matchstreaks to Lstreaks if necessary
    Lstreaks=ConvertVarToBasic(matchstreaks);
    save(sFile, 'matchstreaks', 'Lstreaks');
end

if endtraj==0
    endtraj=numel(Lstreaks);
end

indices=(starttraj: endtraj);
n_tracks = numel(indices);

if strcmp(plotmode, 'tiled');
    for i=1:n_tracks
        tileoffset{i}=[mod(i,hnum), floor(i/hnum)].*(highdis*3);
    end
end

if strcmp(trajcolor, 'Dest');
    colors=jet(601);
    colorind=[Drange(1):(Drange(2)-Drange(1))/600:Drange(2)];
else
    colors = jet(n_tracks);
end

figure (3)
ha=gca();
hold(ha, 'on');
hps = NaN(n_tracks, 1);
segind=1;
numplotted=0;

plottedlist=NaN(1, n_tracks);
fprintf(1,'Working.................\n')
for i = 1 : n_tracks
    if mod(i, 10)==0
        fprintf('\b\b\b\b\b\b\b\b\b\b\b\b\b%6d/%6d', i, n_tracks)
    end
    
    trackName = sprintf('Track %d', indices(i) );
    
    x = Lstreaks(indices(i)).Xc;
    y=Lstreaks(indices(i)).Ycorrected;
    valid= Lstreaks(indices(i)).valid;
    valid(valid==-1)=0;
    
    if mean(x, 'omitnan')> xrange(2) | mean(x, 'omitnan')< xrange(1) | mean(y, 'omitnan')> yrange(2) | mean(y, 'omitnan')< yrange(1)
        continue
    end
    
    if length(x)<minlength
        continue
    end
    
    if (sum(valid)./length(valid))<minpercentvalid
        continue
    end
    
    if onlyconnected  %%find longest streak of valid=1 to plot
        valid(valid==-1)=0;
        try
            zpos = find(~[0 valid 0]);
        catch
            zpos = find(~[0; valid; 0]);
        end
        [~, grpidx] = max(diff(zpos));
        x = x(zpos(grpidx):zpos(grpidx+1)-2);
        y = y(zpos(grpidx):zpos(grpidx+1)-2);
        valid = valid(zpos(grpidx):zpos(grpidx+1)-2);
    end
    
    if length(x)>minlength
        numplotted=numplotted+1;
        plottedlist(i)= indices(i);
    else
        continue
    end
    
    if strcmp(plotmode, 'tiled')
        x=x-mean(x, 'omitnan')+tileoffset{numplotted}(1);
        y=y-mean(y, 'omitnan')+tileoffset{numplotted}(2);
    end
    
    seglist=[];

    %determine line color
    if strcmp(trajcolor, 'Dest')
        yum=y.*pixelsize;
        xum=x.*pixelsize;
        dts=dt/1000;
        
        dis1=sqrt((xum(1:end-1)-xum(2:end)).^2+(yum(1:end-1)-yum(2:end)).^2);
        dis2=sqrt((xum(1:end-2)-xum(3:end)).^2+(yum(1:end-2)-yum(3:end)).^2);
        mdis1=mean(dis1.^2, 'omitnan');
        mdis2=mean(dis2.^2, 'omitnan');
        
        D=(mdis2-mdis1)./4./dts;
        [ d, ix ] = min(abs(colorind-(D)));
    else
        ix= i;
    end
    
    hps(segind) =  plot(ha, x, y,  ...
        'LineStyle', '-',...
        'Color', colors(ix,:), ...
        'DisplayName', trackName, ...
        'LineWidth', 0.5);
    
    
    seglist=[seglist, segind];
    segind=segind+2;
end
handleskey{i}=seglist;

pbaspect([1 1 1]);
daspect([1 1 1])
set(gca,'YDir','reverse')
