function mol=loadGDSCcsv(filename)
%% Import data from .csv file
% assumes all .csv files have single molecule localization data in a 4 column format: 
% Column 1: Time (frames); Column 2: X position (pixels); Column 3: Y position (pixels); Column 4: Intensity; 

%% Initialize variables.
delimiter = ',';
startRow = 2;

%% Format string for each line of text:
formatSpec = '%f%f%f%f%[^\n\r]';

%% Open the text file.
fileID = fopen(filename,'r');

%% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

%% Close the text file.
fclose(fileID);

%% Allocate imported array to structure
frame = dataArray{:, 1};
x = dataArray{:, 2};
y = dataArray{:, 3};
I = dataArray{:, 4};

N=length(x);
mol.x = x;
mol.y = y;
mol.I = I;
mol.frame = frame;

mol.N=N;
mol.TotalFrames=max(mol.frame);

%% Clear temporary variables
clearvars filename delimiter startRow formatSpec fileID dataArray ans;

