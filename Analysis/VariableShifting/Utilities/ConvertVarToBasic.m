function Lstreaks = ConvertVarToBasic(matchstreaks)
nstreaks=numel(matchstreaks);
Lstreaks(nstreaks).Xc=NaN;
Lstreaks(nstreaks).Yc=NaN;
Lstreaks(nstreaks).valid=NaN;
[Lstreaks.frame]=deal(matchstreaks(:).frame);

for i=1:nstreaks
    Lstreaks(i).Xc=matchstreaks(i).Xc(matchstreaks(i).valid==1);
    Lstreaks(i).Ycorrected=matchstreaks(i).Yc(matchstreaks(i).valid==1);
    Lstreaks(i).Yc=matchstreaks(i).Y(matchstreaks(i).valid==1);
    Lstreaks(i).valid=(isfinite(Lstreaks(i).Yc).*isfinite(Lstreaks(i).Xc));
    
    invalid=find(Lstreaks(i).valid==0);
    Lstreaks(i).Xc(invalid)=NaN;
    Lstreaks(i).Yc(invalid)=NaN;
    Lstreaks(i).Ycorrected(invalid)=NaN;
    
    Lstreaks(i).streaklength=length(Lstreaks(i).valid);
    Lstreaks(i).ham=matchstreaks(i).ham;
end


badind1=find([Lstreaks.streaklength]<1);
Lstreaks(badind1)=[];