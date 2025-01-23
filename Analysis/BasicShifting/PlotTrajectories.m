%function PlotTrajectories(Lstreaks)
mfolder = fileparts(which(mfilename)); 
addpath(genpath(mfolder));
close all

%--- parameters to adjust ---

%-- select trajectories to plot
loadnew=0;
starttraj=1; 
endtraj=100; %use 0 to default to final trajectory
minpercentvalid=0.5; 
minlength=5; %only plot trajectories longer than min
selectROI=0; %only plot trajectories within a selected ROI
xrange=[185, 225]; %Define ROI in pixels        
yrange=[325, 355];
yoffset=0;

%-- select plotting styles
plotmode= 'tiled'; %possible modes are 'tiled' or 'image'
trajcolor='none'; %possible modes are 'displacement', 'logdisp', 'time', and 'none'
plotstyle='lineonly'; %possible modes are 'linedot' and 'lineonly'
plotinvalid=0; %if 1, a dashed line will connect points that have skips between them.
onlyconnected=1; %if 1, will stop plotting that trajectory when meeting a "skip" 

%-- other misc settings
highdis=6;  %maximum expected displacement in pixels, used for setting coloring and setting the space between trajectories for tiled mode
timelength=19; %if using 'time' for coloring, set to the approximate maximum length of your trajectories
hnum=5; %number of trajectories displayed horizontally in tiled mode

%-------------------------



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
    endtraj=numel(Lstreaks)
end

indices=(starttraj: endtraj);
n_tracks = numel(indices);

if strcmp(plotmode, 'tiled');
    for i=1:n_tracks
    tileoffset{i}=[mod(i,hnum), floor(i/hnum)].*(highdis*3);
    end
end

if strcmp(trajcolor, 'displacement'); 
    colors=jet(601);
    colorind=[0:(highdis)/600:(highdis)];
elseif strcmp(trajcolor, 'logdisp'); 
    colors=jet(601);
    colorind=[0:log10(highdis)/600:log10(highdis)];
elseif strcmp(trajcolor, 'time'); 
    colors=jet(601);
    colorind=[0:timelength/600:timelength];
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
    for j=1:length(x)-1
        dis=sqrt((x(j)-x(j+1)).^2+(y(j)-y(j+1)).^2);
        %determine line color
        if strcmp(trajcolor, 'displacement')
            [ d, ix ] = min(abs(colorind-dis));
        elseif strcmp(trajcolor, 'logdisp')
            [ d, ix ] = min(abs(colorind-log10(dis)));
        elseif strcmp(trajcolor, 'time')
            [ d, ix ] = min(abs(colorind-j));
        else
            ix= i;
        end
 
        if valid(j)==0 || valid(j+1)==0 %either point is invalid
            if plotinvalid
                hps(segind) =  plot(ha, x(j:j+1), y(j:j+1),...
                    'LineStyle', '--',...
                    'Color', colors(ix,:), ...
                    'DisplayName', trackName );
            else 
%                 hps(segind) =  plot(ha, x(j:j+1), y(j:j+1),...
%                     'LineStyle', 'none',...
%                     'Color', colors(ix,:), ...
%                     'DisplayName', trackName );
            end
            
        else %both points are valid
            
            if strcmp(plotstyle, 'linedot')
                str = '#9c9c9c';
                colorgrey = sscanf(str(2:end),'%2x%2x%2x',[1 3])/255;
                
                hps(segind) =  plot(ha, x(j:j+1), y(j:j+1),  ...
                'LineStyle', '-',...
                'Color', colorgrey, ... 
                'marker', 'none',...
                'markersize', 18,...
                'DisplayName', trackName, ...
                'LineWidth', 2);

                 hps(segind+1) =  plot(ha, x(j:j+1), y(j:j+1),  ...
                'LineStyle', 'none',...
                'Color', colors(ix,:), ...
                'marker', '.',...
                'markersize', 25,...
                'DisplayName', trackName, ...
                'LineWidth', 2);

                
            else

            hps(segind) =  plot(ha, x(j:j+1), y(j:j+1),  ...
                'LineStyle', '-',...
                'Color', colors(ix,:), ...
                'DisplayName', trackName, ...
                'LineWidth', 0.5);
%             hps(segind) =  plot(ha, x(j:j+1), y(j:j+1),  ...
%                 'LineStyle', 'none',...
%                 'marker', '.', ...
%                 'markersize', 2,...
%                 'Color', colors(ix,:), ...
%                 'DisplayName', trackName);%'marker', '.', 'markersize', '2',...
            end
        end
        seglist=[seglist, segind];
        segind=segind+2;
    end
    handleskey{i}=seglist;
end
pbaspect([1 1 1]);
daspect([1 1 1])
set(gca,'YDir','reverse')