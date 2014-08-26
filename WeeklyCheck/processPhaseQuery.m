%PROCESSAUDITQUERY This function processes the output of a phase query to
%	MRIC database, putting it into a cell. Saves the outputs in a mat file.
%
% INPUTS:
%       startdate (string) - Beginning of the date range for the query (YYYY-MM-DD)
%       enddate (string) - End of the date range for the query (YYYY-MM-DD)
%
% OUTPUTS:
%       phaseFields - Column names for the phase query
%       phaseData - Processed output from the session table query. Data is
%           stored as a number if possible, and a string otherwise.
%
% Basically the same as processAuditQuery.m, but it only processes the 
% phase level query. Also, this script will NOT run the query if it can't
% find the needed files - instead, it just exits the program.
%

% Written by Carolyn Ranti 4.2.14
% Updated 7.7.14 -- Protocols are no longer in a cell

function [phaseFields,phaseData]=processPhaseQuery(startdate,enddate)

disp('----------------------------------------------------------------------------------------------------------')
disp('                                        Running processPhaseQuery.m                                       ')

origDir = pwd;
queryDir = ['/Users/etl/Desktop/DataQueries/WeeklyChecks/',startdate,'_',enddate];

phaseFilename = ['phase_',startdate,'_',enddate,'.csv'];

%% If the query has not been run, exit program.

if ~exist(queryDir,'dir')
    disp(' ')
    error('Cannot find query folder - exiting.');
else
    cd(queryDir)
    if ~exist(phaseFilename)
        error('Cannot find the phase file - exiting.');
    end
end

disp(' ')
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');

%% Read in phase file
disp('%%%%%%%%-------- Reading in phase query file ---------%%%%%%%%');

cd(queryDir)
phaseFID = fopen(phaseFilename);

% Get column headers
line = fgetl(phaseFID);
phaseFields = strsplit(line,','); %preserves whitespace

%line by line
C={}; %where data will be stored
line = fgetl(phaseFID);
rowIndex=1; %use to index into the proper row of the data cell

while ischar(line)
    tempData = strsplit(line,',','CollapseDelimiters',false); %split out columns using commas - do not collapse delimiters
    
    for colIndex=1:length(tempData)
    tempData{colIndex}=sscanf(tempData{colIndex},'%s'); %squeeze out white space 
        
        %7.7.14 EDIT -- there should be only one protocol per line, so
        %removing this if statement
        %Keep the protocols as a cell, convert all other data types to num if possible
       % if strcmpi(phaseFields{colIndex},'Protocol')
       %     C{rowIndex,colIndex}=strsplit(tempData{colIndex}(2:end-1),{'###'}); %split out protocols using delimiter inserted by dataquery.py (v4)
       % else
       if ~isempty(tempData{colIndex})
           [numVersion]=str2double(tempData{colIndex}); %convert to number if possible
           if isnan(numVersion)
               C{rowIndex,colIndex}=tempData{colIndex};
           else
               C{rowIndex,colIndex}=numVersion;
           end
       else
           C{rowIndex,colIndex}=[];
       end
    end
       % end
    rowIndex=rowIndex+1;
    line = fgetl(phaseFID);
end
phaseData=C;
fclose(phaseFID);


%% Parse dates 
disp('%%%%%%%%--------------- Processing data ---------------%%%%%%%%');

dateCols = find(cellfun(@(x) ~isempty(x),strfind(phaseFields,'Date'))); %EDIT: is there an easier way to do this? there must be...
for i =1:length(dateCols)
    for ii=1:size(phaseData,1)
        if ~isempty(phaseData{ii,dateCols(i)})
            temp=strsplit(phaseData{ii,dateCols(i)},'/');
            if length(temp)==3
                mo=temp{1};
                temp{1}=temp{3};
                temp{3}=temp{2};
                temp{2}=mo;
            else
                temp=strsplit(phaseData{ii,dateCols(i)},'-'); %in the right order
            end
            temp = cellfun(@str2num,temp);
            phaseData{ii,dateCols(i)}=temp;
        end
    end
end

%% Save output, cd to original dir
disp('%%%%%%%%----------------- Saving data -----------------%%%%%%%%');
save([startdate,'_',enddate,'_phase'],'phaseFields','phaseData');

cd(origDir)
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
disp(' ');
disp('---------------------------------------------------Done---------------------------------------------------')
