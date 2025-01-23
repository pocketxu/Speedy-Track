%% Group molecules from .csv file into trajectories

%--- select frames to analyze ---
startframe=1;
endframe=0; %use endframe=0 to default to final frame

%--- other parameters ---
SearchRadius=5; %distance in pixels to search for a molecule. must be less than verticalshift/2.
VShift=15; %distance shifted between exposures (baseline number)
maxskipcount=6; %maximum number of skips in a row in a given trajectory. must be greater than the largest shifting multiple. ~5-7 recommended. 
MinValid=5; %minimum number of valid molecules in a trajectory 
%-------------------------

mfolder = fileparts(which(mfilename)); 
addpath(genpath(mfolder));

MinStreakLength=MinValid;
XTol=SearchRadius;
YTol=SearchRadius;
DistanceTolSquared=SearchRadius*SearchRadius;
maxskipcount=maxskipcount-1;
ReadCatUnder=2;

XTol=SearchRadius;
YTol=SearchRadius;
DistanceTolSquared=SearchRadius*SearchRadius;
maxskipcount=maxskipcount-1;
ReadCatUnder=2;

%Load file
close all
if exist('LastFolder','var')
    GetFileName=sprintf('%s/*.csv',LastFolder);
else
    GetFileName='*.csv';
end
[FileName,PathName] = uigetfile(GetFileName,'Select the csv file with localizations');
LastFolder=PathName;

MolFile =sprintf('%s%s',PathName,FileName);
fprintf(1,'\nLoading molecule list\n');
Mol=loadGDSCcsv(MolFile);
numMol=Mol.N;

FullFileName=sprintf('%s%s',PathName,FileName);
filehead = FullFileName(1:end-4); %File name without ".csv"
outfilemat = sprintf('%s_StreaksTol%g.mat',filehead,SearchRadius);
if endframe==0
    endframe=Mol.TotalFrames;
end

%---- Go through each frame and find trajectories -----
currentn=1;
fprintf(1,'Finding trajectories, frame.................\n')

for currentframe=startframe:endframe
    if mod(currentframe, 10)==0
        fprintf('\b\b\b\b\b\b\b\b\b\b\b%5d/%5d', currentframe, endframe)
        
    end
    frameindices=find(Mol.frame==currentframe);
    xinframe=Mol.x(frameindices);
    yinframe=Mol.y(frameindices);
    iinframe=Mol.I(frameindices);
   
    %sort molecules from bottom to top
    [ysorted, Isort]=sort(yinframe, 'descend');
    xsorted=xinframe(Isort);
    isorted=iinframe(Isort);
    
    yremaining=ysorted;
    xremaining=xsorted;
    iremaining=isorted;
    
    nremaining=length(ysorted);
    while nremaining>1
        currentstreakx=xremaining(1); %start a new trajectory with lowest molecule that hasnt been used yet
        currentstreaky=yremaining(1);
        usedmols=[];
        xremaining(1)=[];
        yremaining(1)=[];
        iremaining(1)=[];
        currentstreakn=1;
        currenti=iremaining(1);
        currentx=currentstreakx;
        currenty=currentstreaky;
        currentstreakdx=[];
        currentstreakdx=single(currentstreakdx);
        currentstreakdy=single(currentstreakdx);
        currentstreakxlist=single(currentstreakdx);
        currentstreakylist=single(currentstreakdx);
        currentstreakilist=single(currentstreakdx);
        currentstreakvalid=single(currentstreakdx);
        skipflag=0;
        currentstreakskipcount=0;
        while currentstreakn<500
            if skipflag==1 %no molecule was found in last search
                currentstreakvalid=[currentstreakvalid;0];
                currentstreakilist=[currentstreakilist; NaN];
            else
                currentstreakvalid=[currentstreakvalid;1]; %add the molecule from last search to the list for this trajectory
                currentstreakilist=[currentstreakilist; currenti];
            end
            currentstreakxlist=[currentstreakxlist;currentx];
            currentstreakylist=[currentstreakylist;currenty];
            skipflag=0;
            %search for molecules meeting X criteria
            IndicesMeetX=find(xremaining+XTol>currentx & xremaining-XTol<currentx);
            if isempty(IndicesMeetX)
                if currentstreakskipcount>maxskipcount
                    break %if no molecule found and max number of skips already reached, end trajectory
                else %max number of skips not yet met, add a placeholder to the list
                    currentstreakdx=[currentstreakdx; NaN];
                    currentstreakdy=[currentstreakdy; NaN];
                    currentstreakn=currentstreakn+1;
                    currenty=currenty-VShift;
                    currentstreakskipcount=currentstreakskipcount+1;
                    skipflag=1;
                end
            end
            %search for molecules meeting Y criteria within list of
            %molecules meeting X criteria
            YForMolesMeetX=yremaining(IndicesMeetX);
            IndicesMeetY=find(YForMolesMeetX-YTol+VShift<currenty & currenty<YForMolesMeetX+YTol+VShift);
            if isempty(IndicesMeetY) %deal with skipped molecules as before
                if currentstreakskipcount>maxskipcount
                    break
                else
                    currentstreakdx=[currentstreakdx; NaN];
                    currentstreakdy=[currentstreakdy;NaN];
                    currentstreakn=currentstreakn+1;
                    currenty=currenty-VShift;
                    currentstreakskipcount=currentstreakskipcount+1;
                    skipflag=1;
                end
            end
            if length(IndicesMeetY)>1 %multiple molecules within search radius
                if currentstreakskipcount>maxskipcount
                    xremaining(IndicesMeetX(IndicesMeetY))=[];
                    yremaining(IndicesMeetX(IndicesMeetY))=[];
                    break
                else
                    currentstreakdx=[currentstreakdx; NaN];
                    currentstreakdy=[currentstreakdy;NaN];
                    currentstreakn=currentstreakn+1;
                    currenty=currenty-VShift;
                    currentstreakskipcount=currentstreakskipcount+1;
                    skipflag=1;
                end
            end
            if length(IndicesMeetY)==1 %successful search, add molecule to list
                dx=currentx-xremaining(IndicesMeetX(IndicesMeetY));
                dy=currenty-yremaining(IndicesMeetX(IndicesMeetY))-VShift;
                displacementsqr=(dx*dx+dy*dy);
                
                if displacementsqr>DistanceTolSquared
                    if currentstreakskipcount>maxskipcount
                        break
                    else
                        currentstreakdx=[currentstreakdx; NaN];
                        currentstreakdy=[currentstreakdy;NaN];
                        currentstreakn=currentstreakn+1;
                        currenty=currenty-VShift;
                        currentstreakskipcount=currentstreakskipcount+1;
                        skipflag=1;
                    end
                else
                    currentstreakskipcount=0;
                end
                currentstreakdx=[currentstreakdx; currentx-xremaining(IndicesMeetX(IndicesMeetY))];
                currentstreakdy=[currentstreakdy;currenty-yremaining(IndicesMeetX(IndicesMeetY))-VShift];
                currentstreakn=currentstreakn+1;
                currentx=xremaining(IndicesMeetX(IndicesMeetY));
                currenty=yremaining(IndicesMeetX(IndicesMeetY));
                currenti=iremaining(IndicesMeetX(IndicesMeetY));
                usedmols=[usedmols IndicesMeetX(IndicesMeetY)];
            end
            
        end
        %stop adding molecules to this trajectory

        %remove invalid from end of the streak and check if the trajectory
        %meets quality requirements
        stopind=find(currentstreakvalid, 1, 'last');
        if (length(currentstreakvalid)-maxskipcount)>MinStreakLength
            if length(find(currentstreakvalid==1))>MinValid
                xremaining(usedmols)=[];
                yremaining(usedmols)=[];
                iremaining(usedmols)=[];
                
                %add data to structure of output trajectories
                Lstreaks(currentn).streaklength=stopind;
                Lstreaks(currentn).dx=currentstreakdx(1:stopind-1);
                Lstreaks(currentn).dy=currentstreakdy(1:stopind-1);
                Lstreaks(currentn).Xc=currentstreakxlist(1:stopind);
                Lstreaks(currentn).Yc=currentstreakylist(1:stopind);
                Lstreaks(currentn).Ycorrected=currentstreakylist(1:stopind)+transpose((1:stopind)).*VShift;
                Lstreaks(currentn).i=currentstreakilist(1:stopind);
                Lstreaks(currentn).frame=currentframe;
                Lstreaks(currentn).valid=currentstreakvalid(1:stopind);
                currentn=currentn+1;
            end
        end
        usedmols=[];
        nremaining=length(xremaining);
    end
    currentframe=currentframe+1;
end

%format data for writing to .csv
ListOfOutputFrames=[];
for i=1:numel(Lstreaks)
      ListOfOutputFrames=[ListOfOutputFrames;ones(length(Lstreaks(i).Xc),1)*double(Lstreaks(i).frame)];
end
ListOfOutputXc=vertcat(Lstreaks.Xc);
ListOfOutputYc=vertcat(Lstreaks.Yc);
ListOfOutputI=vertcat(Lstreaks.i);
ListOfOutputValid=vertcat(Lstreaks.valid);
Numvalid=NaN(1, numel(Lstreaks));

for i=1:numel(Lstreaks)
    Numvalid(i)=length(find(Lstreaks(i).valid==1));
end
histogram(Numvalid)
ax=gca();
ax.XLabel.String = 'Number of valid molecules in trajectory';

AllBin.x=[ListOfOutputXc(ListOfOutputValid==1)];
AllBin.y=[ListOfOutputYc(ListOfOutputValid==1)];
AllBin.I=[ListOfOutputI(ListOfOutputValid==1)];
AllBin.frame=[ListOfOutputFrames(ListOfOutputValid==1)];

OutFileAll=[MolFile(1:end-4) '-streaks.csv'];
writetable(struct2table(AllBin), OutFileAll);

save(outfilemat,  'Lstreaks')