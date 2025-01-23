%%--- parameters to adjust ---
Vshift=15;

endnum=0; %last trajectory to analyze. 0 defaults to analyzing all trajectories

Ymin=1;  %can use to clean up image somewhat if the boundaries of the image are known
Ymax=512;  

hamthresh=0.3;  % portion of the observed molecule pattern that can be wrong compared to sequence. Recommended ~0.3. 
%------------------------------

loadnewseq=1; %if you already have an expected sequence loaded you would like to use, select 0
flipseq=0; %usually 0, but may need to change to 1 depending on whether time direction is up or down in image
totalmols=0;
clearvars matchstreaks 
mfolder = fileparts(which(mfilename)); 
addpath(genpath(mfolder));

% -- load the sequence in .xls format used to set shifting pattern in acquisition
if loadnewseq
    clearvars shiftlistforward
end
if exist('shiftlistforward')==0 || exist('expectedseq')==0
    [seqFile,seqPath] = uigetfile('.xlsx','Load sequence file');
    shiftlistforward = xlsread(sprintf('%s%s',seqPath,seqFile),'Sheet1');
    numshifts=sum(shiftlistforward);
    expectedseq=[];
    for i=1:length(shiftlistforward)
        expectedseq=[expectedseq, 1];
        expectedseq=[expectedseq, zeros(1,shiftlistforward(i)-1)];
    end
    clearvars raw;
    shiftlistforward=num2str(shiftlistforward);
    if flipseq
        expectedseq=flip(expectedseq);
    end
end

offset=-1*(length(expectedseq)+1)*Vshift; 

% -- load trajectories from previous step

if exist('LastFolder','var')
    GetFileName=sprintf('%s/*Streaks*.mat',LastFolder);
else
    GetFileName='*Streaks*.mat';
end
[streakFile,streakPath] = uigetfile(GetFileName,'Load streak file');
load(sprintf('%s%s',streakPath,streakFile))

if endnum==0
    endnum= numel(Lstreaks);
end


%-- find best match between obs data and seq by calculating sliding hamming distance
currentn=1;
fprintf(1,'\nMatching trajectories.................\n')
matchstreaks(endnum).ham=[];
for s=1:endnum
    if mod(s, 10)==0
        fprintf('\b\b\b\b\b\b\b\b\b\b\b\b\b%6d/%6d', s,endnum)
    end
    
    obseq=transpose(Lstreaks(s).valid);
    obY=transpose(Lstreaks(s).Yc);
    %     inY=find(obY<620);
    %     obseq=obseq(inY);
    
    obslength=length(obseq);
    ham=double.empty(length(expectedseq)-obslength, 0);
    
    %--calculate hamming distance for each potential match position
    for i=1:length(expectedseq)-obslength
        ham(i)=pdist([expectedseq(i:i+obslength-1);obseq], 'hamming');
    end
    %--find best and second best position
    [minham, matchpos]= min(ham);
    ham(matchpos)=NaN;
    [ham2, match2]=min(ham);
    ham(matchpos)=minham;
    
    
    
    
    if length(find(ham==minham))==1 %only one match with the best hamming distance
        matchstreaks(currentn).ham=minham;
        matchstreaks(currentn).frame=Lstreaks(s).frame;
        
        ham12diff(s)=ham2-minham;
        ham1s(s)=minham;
        ham2s(s)=ham2;
        
        
        %-- calculate correct Y positions based on match position
        if matchpos>0
            for i=1:obslength
                if expectedseq(i+matchpos-1)==1
                    if Lstreaks(s).valid(i)==0;
                        matchstreaks(currentn).valid(i)=1;
                        matchstreaks(currentn).Yc(i)=NaN;
                        matchstreaks(currentn).Xc(i)=NaN;
                        matchstreaks(currentn).i(i)=0;
                    else
                        matchstreaks(currentn).valid(i)=1;
                        matchstreaks(currentn).Yc(i)=Lstreaks(s).Yc(i)+(i+matchpos-2)*Vshift+offset;
                        matchstreaks(currentn).Xc(i)=Lstreaks(s).Xc(i);
                        matchstreaks(currentn).i(i)=Lstreaks(s).i(i);
                        totalmols=totalmols+1;
                    end
                    matchstreaks(currentn).Y(i)=Lstreaks(s).Yc(i);
                    matchstreaks(currentn).time(i)=sum(expectedseq(1:i+matchpos-1));
                end
            end
        end
        
        %if calculated y positions are outside expected image range, use
        %the second best match 
        if (matchstreaks(currentn).Yc(1))>Ymax || (matchstreaks(currentn).Yc(1))<Ymin
            minham=ham2;
            matchpos=match2;
            
            if length(find(ham==minham))==1 
                matchstreaks(currentn).Yc=[];
                matchstreaks(currentn).Xc=[];
                matchstreaks(currentn).Y=[];
                matchstreaks(currentn).valid=[];
                matchstreaks(currentn).time=[];
                searchfor2nd(s)=1;
                for i=1:obslength
                    if expectedseq(i+matchpos-1)==1
                        if Lstreaks(s).valid(i)==0;
                            matchstreaks(currentn).valid(i)=1;
                            matchstreaks(currentn).Yc(i)=NaN;
                            matchstreaks(currentn).Xc(i)=NaN;
                            matchstreaks(currentn).i(i)=0;
                        else
                            matchstreaks(currentn).valid(i)=1;
                            matchstreaks(currentn).Yc(i)=Lstreaks(s).Yc(i)+(i+matchpos-2)*Vshift+offset;
                            matchstreaks(currentn).Xc(i)=Lstreaks(s).Xc(i);
                            matchstreaks(currentn).i(i)=Lstreaks(s).i(i);
                        end
                        matchstreaks(currentn).Y(i)=Lstreaks(s).Yc(i);
                        matchstreaks(currentn).time(i)=sum(expectedseq(1:i+matchpos-1));
                    end
                end
            end
        end
    end
    
    
    matchstreaks(currentn).ham=minham;
    matchstreaks(currentn).frame=Lstreaks(s).frame;

    %-- calculate correct Y positions based on match position (accounting for negative values)  
    if matchpos<1
        for i=1:obslength+matchpos
            if expectedseq(i)==1
                if Lstreaks(s).valid(i-matchpos)==0;
                    matchstreaks(currentn).valid(i)=0;
                    matchstreaks(currentn).Yc(i)=NaN;
                else
                    matchstreaks(currentn).valid(i)=1;
                    matchstreaks(currentn).Yc(i)=Lstreaks(s).Yc(i-matchpos)+(i+matchpos-2)*Vshift+offset;
                end
                matchstreaks(currentn).Xc(i)=Lstreaks(s).Xc(i);
                matchstreaks(currentn).Y(i)=Lstreaks(s).Yc(i);
                matchstreaks(currentn).i(i)=Lstreaks(s).i(i);
                matchstreaks(currentn).time(i)=sum(expectedseq(1:i+matchpos-1));
            end
        end
    end
    currentn=currentn+1;
end

clearvars Lstreaks

%%
ListOfOutputFrames=zeros(totalmols+5,1);
ListOfOutputQual=zeros(totalmols+5,1);
currentp=1;

hamind=find([matchstreaks.ham]<hamthresh);
ListOfOutputXc=horzcat(matchstreaks(hamind).Xc);
ListOfOutputYc=horzcat(matchstreaks(hamind).Yc);
ListOfOutputValid=horzcat(matchstreaks(hamind).valid);
ListOfOutputI=horzcat(matchstreaks(hamind).i);
ListOfOutputTime=horzcat(matchstreaks(hamind).time);

for i=1:numel(matchstreaks)
    if matchstreaks(i).ham>hamthresh
        continue
    end
    ListOfOutputFrames(currentp:currentp+length(matchstreaks(i).valid)-1)=double(matchstreaks(i).frame)*(ones(1, length(matchstreaks(i).valid)));
    ListOfOutputQual(currentp:currentp+length(matchstreaks(i).valid)-1)=(1-matchstreaks(i).ham)*length(find([matchstreaks(i).valid]==1)).*(ones(1, length(matchstreaks(i).valid)));
    currentp=currentp+length(matchstreaks(i).valid);
end

Lstreaks = ConvertVarToBasic(matchstreaks);

validind1=find(ListOfOutputValid==1);
validind2=find(~isnan(ListOfOutputXc));
validind3=find(~isnan(ListOfOutputYc));
validind=intersect(validind1, validind2);
validind=intersect(validind, validind3);

clearvars AllBin
%%
AllBin.x=transpose(ListOfOutputXc(validind));
AllBin.y=transpose(ListOfOutputYc(validind));
AllBin.I=transpose(ListOfOutputI(validind));
AllBin.frame=ListOfOutputFrames(validind);

OutFileAll=[sprintf('%s%s',streakPath,streakFile(1:end-4)) '-image.csv'];
writetable(struct2table(AllBin), OutFileAll);

OutFileAll4=[sprintf('%s%s',streakPath,streakFile(1:end-4)) '-image.mat'];
save(OutFileAll4, 'Lstreaks')
