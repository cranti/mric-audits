%PROCESSAUDITQUERY - This function processes csv files output by queries to
%the MRIC database within a specified date range. 
%
% INPUTS:
%       startdate (string) - Beginning of the date range for the query.
%       enddate (string) - End of the date range for the query.
%       runPython (1 or 0) - If true, query the database by calling the 
%               Python data query script. 
%
% OUTPUTS:
%       sessionFields - Column names for the session table query
%       sessionData - Processed output from the session table query
%       runFields - Column names for the run table query
%       runData - Processed output from the run table query
%       AllProtocols - All of the unique protocols from the session table
%               query (column vector)
%       sProtLogic - Logical matrix: one column per protocol (matching
%               AllProtocols), one row per session (matching sessionData).
%       rProtLogic - Logical matrix: one column per protocol (matching
%               AllProtocols), one row per session (matching runData).
%
% If runPython is true, the Python data query script will be run: 
%   > Calls python script dataquery.py (from /Users/ETLcommon/Software/),
%     which queries the database for all sessions in a specified date range.
%     The MATLAB command line will display the prompts from the Python script,
%     asking the user for a username and password to the database.
% Otherwise, this script just looks for the directory where outputs are
% saved. If the directory cannot be found, runPython is set to 1, and the
% query is run.
%
% This script reads in the csv files output by the python script, & parses
% data into a cell. Data is stored as a number if possible, and a string
% otherwise. Each row can have multiple protocols, which are output in a
% distinct way by the database/dataquery.py - this script takes
% advantage of those patterns, and stores the protocols as a cell with
% multiple entries (if applicable).
%
% Outputs from this script can be used to create graphs (see auditGraphs.m)
%
% Script prints progress updates to command window.
%
% NOTES:
%   > Currently using dataquery.py (V4)
%   > dataquery.py must be stored in /Users/ETLcommon/Software/, and it
%   must output files into a directory in /Users/etl/Desktop/DataQueries
%   > It's important that the protocol column of the query csv is named
%   "Protocol" (if it exists)
%   > Session and Rollup queries must both have age columns that start with
%   "Age" (case insensitive), as well as a date column
%   > Currently playing nice with empty entries (as far as I can tell)
%

% Written by Carolyn Ranti
% 3.17.14
% Updated 4.28.14 - switching to dataquery_v4
% Updated 5.21.14 - switching to dataquery_v5


function [sessionFields,sessionData,runFields,runData,AllProtocols,sProtLogic,rProtLogic]=processAuditQuery(startdate,enddate,runPython)

disp('----------------------------------------------------------------------------------------------------------')
disp('                                        Running processAuditQuery.m                                       ')


origDir = pwd;
scriptDir = '/Volumes/ETLcommon/Software/';
queryDir = ['/Users/etl/Desktop/DataQueries/',startdate,'_',enddate];

sessionFilename = ['session_',startdate,'_',enddate,'.csv'];
runFilename = ['run_',startdate,'_',enddate,'.csv'];

%% Run data query - call python script

if ~runPython && ~exist(queryDir,'dir')
    disp(' ')
    disp('Cannot find query folder - running query for specified dates.');
    runPython=1;
end

disp(' ')
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
if (runPython)
    disp('%%%%%%%%----------- Querying the database -------------%%%%%%%%');
    cd(scriptDir)
    
    system(['python dataquery.py ',startdate,' ',enddate]); %MATLAB command line will prompt user to enter database username and password
     
end


%% Read in session file

disp('%%%%%%%%-------- Reading in session query file --------%%%%%%%%');

cd(queryDir)
sessionFID = fopen(sessionFilename);

% Get column headers
line = fgetl(sessionFID);
sessionFields = strsplit(line,','); %preserves whitespace

%line by line
C={}; %where data will be stored
line = fgetl(sessionFID);
rowIndex=1; %use to index into the proper row of the data cell

while ischar(line)
   
    tempData = strsplit(line,',','CollapseDelimiters',false); %split out columns using commas - do not collapse delimiters
    %disp(tempData)
    for colIndex=1:length(tempData)
        
        tempData{colIndex}=sscanf(tempData{colIndex},'%s'); %squeeze out white space 
        
        %Keep the protocols as a cell, convert all other data types to num
        %if possible
        
        if strcmpi(sessionFields{colIndex},'Protocol')
            C{rowIndex,colIndex}=strsplit(tempData{colIndex}(2:end-1),{'###'}); %split out protocols using delimiter inserted by dataquery.py (v4)
        else
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
    end
    rowIndex=rowIndex+1;
    line = fgetl(sessionFID);
end
sessionData=C;
fclose(sessionFID);


%% Read in run file
disp('%%%%%%%%---------- Reading in run query file ----------%%%%%%%%');

cd(queryDir)
runFID = fopen(runFilename);

% Get column headers
line = fgetl(runFID);
runFields = strsplit(line,','); %preserves whitespace

%line by line
C={}; %where data will be stored
line = fgetl(runFID);
rowIndex=1; %use to index into the proper row of the data cell

while ischar(line)
   
    tempData = strsplit(line,',','CollapseDelimiters',false); %split out columns using commas - do not collapse delimiters
    
    for colIndex=1:length(tempData)
        
        tempData{colIndex}=sscanf(tempData{colIndex},'%s'); %squeeze out white space 
        
        %Keep the protocols as a cell, convert all other data types to num if possible
        if strcmpi(runFields{colIndex},'Protocol')
            C{rowIndex,colIndex}=strsplit(tempData{colIndex}(2:end-1),{'###'}); %split out protocols using delimiter inserted by dataquery.py (v4)
        else
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
    end
    rowIndex=rowIndex+1;
    line = fgetl(runFID);
end
runData=C;
fclose(runFID);


%% Parse dates
disp('%%%%%%%%--------------- Processing data ---------------%%%%%%%%');

% Works for excel and database format (M(M)/D(D)/YY or YYYY-MM-DD)
% Puts date in array as numbers: [Y,M,D]
sDateCol = find(strcmpi('Date',sessionFields));
for ii=1:size(sessionData,1)
    temp=strsplit(sessionData{ii,sDateCol},'/');
    if length(temp)==3
        mo=temp{1};
        temp{1}=temp{3}; %year
        temp{3}=temp{2};
        temp{2}=mo;
    else
        temp=strsplit(sessionData{ii,sDateCol},'-'); %in the right order
    end
    temp = cellfun(@str2num,temp);
    sessionData{ii,sDateCol}=temp;
end

rDateCol = find(strcmpi('Date',runFields));
for ii=1:size(runData,1)
    temp=strsplit(runData{ii,rDateCol},'/');
    if length(temp)==3
        mo=temp{1};
        temp{1}=temp{3};
        temp{3}=temp{2};
        temp{2}=mo;
    else
        temp=strsplit(runData{ii,rDateCol},'-'); %in the right order
    end
    temp = cellfun(@str2num,temp);
    runData{ii,rDateCol}=temp;
end

%% Bin ages 
% Add binned ages column

%Session query
sAgeCol = strncmpi('Age',sessionFields,3);

sTempRound=cellfun(@round,sessionData(:,sAgeCol),'UniformOutput',false);
sTempRound(cellfun(@isempty,sTempRound))={-1}; %convert empty cells to -1 (flag for ages that aren't in database)
sTempRound=cell2mat(sTempRound);

sTempRound(sTempRound==7) = 6;
sTempRound(sTempRound==8) = 9;
sTempRound(sTempRound==10) = 9;
sTempRound(sTempRound==11) = 12;
sTempRound(sTempRound==13) = 12;
sTempRound(sTempRound==14) = 15;
sTempRound(sTempRound==16) = 15;
sTempRound(sTempRound==17) = 18;
sTempRound(sTempRound==19) = 18;
sTempRound(sTempRound==20) = 18;
sTempRound(sTempRound>20&sTempRound<=29) = 24;
sTempRound(sTempRound>29&sTempRound<=42) = 36;

%SCHOOL AGE ROUNDING:
sTempRound(sTempRound>=54&sTempRound<72) = 60; 
sTempRound(sTempRound>=72&sTempRound<84) = 72;
sTempRound(sTempRound>=84&sTempRound<96) = 84;
sTempRound(sTempRound>=96&sTempRound<108) = 96;
sTempRound(sTempRound>=108&sTempRound<120) = 108;
sTempRound(sTempRound>=120&sTempRound<132) = 120;
sTempRound(sTempRound>=132&sTempRound<144) = 132;
sTempRound(sTempRound>=144&sTempRound<156) = 144;
sTempRound(sTempRound>=156&sTempRound<168) = 156;
sTempRound(sTempRound>=168&sTempRound<180) = 168;
sTempRound(sTempRound>=180&sTempRound<192) = 180;
sTempRound(sTempRound>=192&sTempRound<204) = 192;
sTempRound(sTempRound>=204&sTempRound<216) = 204;
sTempRound(sTempRound>=216&sTempRound<228) = 216;

sessionData(:,size(sessionData,2)+1)=num2cell(sTempRound);
sessionFields{1,size(sessionData,2)}='Binned Age';

%Repeat for run query
rAgeCol = strncmpi('Age',runFields,3);

rTempRound=cellfun(@round,runData(:,rAgeCol),'UniformOutput',false);
rTempRound(cellfun(@isempty,rTempRound))={-1}; %convert empty cells to -1 (flag for ages that aren't in database)
rTempRound=cell2mat(rTempRound);

rTempRound(rTempRound==7) = 6;
rTempRound(rTempRound==8) = 9;
rTempRound(rTempRound==10) = 9;
rTempRound(rTempRound==11) = 12;
rTempRound(rTempRound==13) = 12;
rTempRound(rTempRound==14) = 15;
rTempRound(rTempRound==16) = 15;
rTempRound(rTempRound==17) = 18;
rTempRound(rTempRound==19) = 18;
rTempRound(rTempRound==20) = 18;
rTempRound(rTempRound>20&rTempRound<=29) = 24;
rTempRound(rTempRound>29&rTempRound<=42) = 36;

%SCHOOL AGE ROUNDING:
rTempRound(rTempRound>=54&rTempRound<72) = 60; 
rTempRound(rTempRound>=72&rTempRound<84) = 72;
rTempRound(rTempRound>=84&rTempRound<96) = 84;
rTempRound(rTempRound>=96&rTempRound<108) = 96;
rTempRound(rTempRound>=108&rTempRound<120) = 108;
rTempRound(rTempRound>=120&rTempRound<132) = 120;
rTempRound(rTempRound>=132&rTempRound<144) = 132;
rTempRound(rTempRound>=144&rTempRound<156) = 144;
rTempRound(rTempRound>=156&rTempRound<168) = 156;
rTempRound(rTempRound>=168&rTempRound<180) = 168;
rTempRound(rTempRound>=180&rTempRound<192) = 180;
rTempRound(rTempRound>=192&rTempRound<204) = 192;
rTempRound(rTempRound>=204&rTempRound<216) = 204;
rTempRound(rTempRound>=216&rTempRound<228) = 216;

runData(:,size(runData,2)+1)=num2cell(rTempRound);
runFields{1,size(runData,2)}='Binned Age';


%% Deal with protocols

%Find unique protocols (using session is fine, bc all participants will be in there)
sProtCol=strcmpi('Protocol',sessionFields);
AllProtocols={};
for ii=1:size(sessionData,1)
    for i2=1:size(sessionData{ii,sProtCol},2)
        if ~isempty(sessionData{ii,sProtCol}{i2})
        	AllProtocols={AllProtocols{:},sessionData{ii,sProtCol}{i2}};
        end
    end
end    

AllProtocols=unique(AllProtocols);

%make logical array for session and run: [# sessions]x[# unique protocols]
sProtLogic=false(size(sessionData,1),length(AllProtocols));

for ii=1:size(sessionData,1)
    for i2=1:size(sessionData{ii,sProtCol},2)
        if ~isempty(sessionData{ii,sProtCol}{i2})
            sProtLogic(ii,strcmp(sessionData{ii,sProtCol}{i2},AllProtocols))=1;
        end
    end
end

%Repeat for run query:
rProtCol=strcmpi('Protocol',runFields);
rProtLogic=false(size(runData,1),length(AllProtocols));

for ii=1:size(runData,1)
    for i2=1:size(runData{ii,rProtCol},2)
        if ~isempty(runData{ii,rProtCol}{i2})
            rProtLogic(ii,strcmp(runData{ii,rProtCol}{i2},AllProtocols))=1;
        end
    end
end


%% Save output, cd to original dir
disp('%%%%%%%%----------------- Saving data -----------------%%%%%%%%');
save([startdate,'_',enddate],'sessionFields','sessionData','runFields','runData','AllProtocols','sProtLogic','rProtLogic');

cd(origDir)
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
disp(' ');
disp('---------------------------------------------------Done---------------------------------------------------')