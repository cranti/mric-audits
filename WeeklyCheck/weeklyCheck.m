function weeklyCheck(startdate,enddate)
%WEEKLYCHECK Runs ETL weekly audits on the MRIC database for a 
% specified date range and saves a csv summary.
%
% INPUTS:
%       startdate (str) - Beginning of date range for the query (YYYY-MM-DD)
%       enddate (str) - End of date range for the query (YYYY-MM-DD)
%
% This script uses weeklyCheckQuery.py to run two queries for the date
% range specified in the inputs and produces a summary of the data, to
% facilitate the fellows' (roughly) weekly checks/data audits.
%
% Saves a csv file in a directory specified in the script. The csv contains
% the following information:
%       - Date that query was run
%       - Date range of query
%       - Summary of the sessions run in the date range & their qualities,
%       broken up by lab (age range) and binned age
%       - A list of issues found by comparing session table and requirements
%       table (SEE NOTES)
%       - A list of all sessions (date of session, matlab id/sess #, fellows)
%
% The directory is named by date range, and it contains the query results
% (as csv files, output by the Python script) and the processed results
% (saved as a mat file), as well as the summary csv.
%
% NOTES:
%   > INFO ABOUT ERROR CHECKING: False positives are possible in the error
%   checking process. The most common occurs when a two day ET session
%   has been run, and the query range only includes one of the days.
%   Because of the structure of the queries, the script will print that
%   a session hasn't been uploaded and/or it hasn't been phase edited
%   properly. To check if this is the case, you can look at the dates of
%   the session, or look in the database (in session table and phase
%   editor) to make sure that everything looks good.
%
%   > If the query has been run and/or the summary already exists, the
%   user will be asked whether they want to overwrite those files.
%
%   > The script prints where results have been saved to the command line.
%
%   > For initial set up (i.e. when running on a new computer), change the
%   variable pythonDir (dir where weeklyCheckQuery.py is saved) and
%   baseResultsDir (where a subdir will be created with all of the results)
%
%
% See also READINQUERY, ADDBINNEDAGE, PROTOCOLLOGIC

% POSSIBLE FUTURE EDITS
%   > Add phase check that will make sure dates in session match the
% phase completion date
%   > Integrity of upload audit
%   > LIVE- Print out what fellows are in charge of the NONC videos?
%
% Written by Carolyn Ranti 8.25.2014

origDir = pwd;
home
addpath('../QueryTools') %% to access all of the query processing tools

disp('----------------------------------------------------------------------------------------------------------')
disp('                                           Running weeklyCheck.m                                          ')

%% SET UP directories
pythonDir = pwd; % '/Volumes/ETLcommon/Software/';
baseResultsDir = '/Users/etl/Desktop/DataQueries/WeeklyChecks/';

%%
resultsDir = [baseResultsDir,startdate,'_',enddate,'/'];
weeklyCheckFile = [resultsDir,'Summary_',startdate,'_',enddate,'.csv'];
matFileName = [startdate,'_',enddate,'.mat'];

%% Run query & process query output, if necessary

%if the query dir can't be found, runPython should be set to 1
if ~exist(resultsDir,'dir')
    runPython=1;
    processData=1;
else
    %If the query dir already exists, do not run query again
    disp(' ')
    disp('%%%%');
    fprintf(['Looks like this query exists in the following directory:\n\t',resultsDir]);
    runPython=strcmpi('y',input('\nWould you like to run it again and overwrite any existing files? (y/n): ','s'));
    disp('%%%%');
    disp(' ');
    
    cd(resultsDir)
    if runPython || ~exist(matFileName,'file')
        processData = 1;
    else %otherwise, load in existing matfile and check for variables
        processData = 0;
        load(matFileName); %this will give fields and data
        if ~exist('fields','var') || exist('data','var')
            processData = 1;
        end
    end
end

%Run the query
if runPython
    cd(pythonDir)
    system(['python weeklyCheckQuery.py ',startdate,' ',enddate]); %MATLAB command line will prompt user to enter database username and password
end

%process query output (~runPython & processData) 
%or load already processed query output (~runPython & ~processData)
if processData || runPython
    cd(origDir)
    
    %read in session query
    sessionFilename = [resultsDir,'session_',startdate,'_',enddate,'.csv'];
    [sessionFields,sessionData] = ReadInQuery(sessionFilename);
    %do a little processing
    monthAgeCol=strncmpi('Age',sessionFields,3);
    [sessionFields,sessionData] = AddBinnedAge(sessionFields,sessionData,monthAgeCol);
    colNum=find(cellfun(@(x) ~isempty(strfind(x,'Protocol')),sessionFields));
    %protocol logic
    [AllProtocols,sProtLogic] = ProtocolLogic(sessionData,colNum);
    
    %read in phase query
    phaseFilename = [resultsDir,'phase_',startdate,'_',enddate,'.csv'];
    [phaseFields,phaseData] = ReadInQuery(phaseFilename);

    
    cd(resultsDir)
    save([startdate,'_',enddate],'sessionFields','sessionData','phaseFields','phaseData','AllProtocols','sProtLogic');
else
    cd(resultsDir)
    load([startdate,'_',enddate])
end

%date the query was run --> set as modification date for the folder
d = dir(resultsDir);
queryRunDate = d(1).date; 


%% Find column indices
sDateCol=find(strcmpi('Date',sessionFields));
sIDCol=find(strcmpi('ID',sessionFields));
sMatIDCol=find(strcmpi('MatlabID',sessionFields));
sSessionCol=find(strncmpi('Session',sessionFields,7));
sQualCol=find(strcmpi('Quality',sessionFields));
sBinAgeCol=find(strcmpi('BinnedAge',sessionFields));
sFellowsCol=find(strcmpi('Fellows',sessionFields));

pMatIDCol=find(strcmpi('MatlabID',phaseFields));
pIDCol = find(strcmpi('ID',phaseFields));
pFullDateCol=find(strcmpi('FulfillmentDate',phaseFields));
pPhaseCol=find(strcmpi('Phase',phaseFields));
pReqCol=find(strcmpi('Requirement',phaseFields));
pStatusCol=find(strcmpi('Status',phaseFields));
pProtCol=find(strcmpi('Protocol',phaseFields));


%% Summary of sessions
cd(resultsDir)
if exist(weeklyCheckFile,'file') && ~runPython
    disp(' ');
    disp('%%%%');
    fprintf(['A summary for this date range already exists in the following location:\n\t',resultsDir,weeklyCheckFile]);
    overwriteFile=strcmpi('y',input('\nDo you want to overwrite the file? (y/n): ','s'));
    disp('%%%%');
    disp(' ');
else
    overwriteFile = 1;
end

if overwriteFile

fid=fopen(weeklyCheckFile,'w+');
fprintf(fid,'Query run on:,%s\n\n',queryRunDate);
fprintf(fid,'Start date:,%s\n',startdate);
fprintf(fid,'End date:,%s\n',enddate);

%summary of sessions/quality (by age, with infant/toddler/schoolage summary)
unqAges=unique(cell2mat(sessionData(:,sBinAgeCol)));

qualitySummary=zeros(length(unqAges),6); %ages x qualities
for i=1:length(unqAges)
    BinAgeLogic=(cell2mat(sessionData(:,sBinAgeCol))==unqAges(i));
    
    tempQuals=cell2mat(sessionData(BinAgeLogic,sQualCol));
    for ii=0:5
        qualitySummary(i,ii+1)=sum(tempQuals==ii);
    end
end


fprintf(fid,'\n*******************************\n*** QUALITY SUMMARY ***\n\n');

infantQuals=sum(qualitySummary(unqAges<6&unqAges>0,:),1);
toddlerQuals=sum(qualitySummary(unqAges>=6&unqAges<54,:),1);
schoolAgeQuals=sum(qualitySummary((unqAges>=54&unqAges<=216)|(unqAges==-1),:),1); %-1 means no age in database- probably school age
%last column is row total
infantQuals=[infantQuals,sum(infantQuals)];
toddlerQuals=[toddlerQuals,sum(toddlerQuals)];
schoolAgeQuals=[schoolAgeQuals,sum(schoolAgeQuals)];
%column totals:
colTotals=sum([infantQuals;toddlerQuals;schoolAgeQuals],1);


fprintf(fid,'Age Group\\Quality, %i, %i, %i, %i, %i, %i,TOTAL\n',0:5);
fprintf(fid,'Infant (0-5mo), %i, %i, %i, %i, %i, %i, %i\n',infantQuals);
fprintf(fid,'Toddler (6-54mo), %i, %i, %i, %i, %i, %i, %i\n',toddlerQuals);
fprintf(fid,'School Age (54+mo), %i, %i, %i, %i, %i, %i, %i\n',schoolAgeQuals);
fprintf(fid,'TOTAL,%i,%i,%i, %i, %i, %i, %i\n',colTotals);

fprintf(fid,'\n\nAge (months)\\Quality, %i, %i, %i, %i, %i, %i\n',0:5);
fprintf(fid,'%i, %i, %i, %i, %i, %i, %i\n',[unqAges,qualitySummary]'); %transposed bc fprintf goes down columns


%% Phase check %% 
% Phase query returns eye tracking phase information for the people/phases
% that had a compensation completed in the last week. 
% CHECKS TO RUN
%   1) Did we phase edit every session? -- All statuses should say "done"
%   2) Did we phase edit on the correct date? -- The fulfillment date
%   should match the date of a session with the same matlab ID
%   3) Did we upload all the sessions? -- The unique matlab IDs in the
%   phase and session queries should be the same. In addition, there should
%   be the same number of repetitions of each one 


%%%%%%%%
% Change the phase query a little bit 
% 1. if the MATLAB ID is empty, copy the individual id over (as a string)
for i = 1:size(phaseData,1)
    if isempty(phaseData{i,pMatIDCol})
        phaseData{i,pMatIDCol}=num2str(phaseData{i,pIDCol});
    end
end

% 2. Take out anyone who doesn't have an eye-tracking session
ETfilter=cellfun(@(x) ~isempty(strfind(x,'Tracking')),phaseData(:,pReqCol));
eyetrackedFilter=ismember(phaseData(:,pMatIDCol),phaseData(ETfilter,pMatIDCol)); %&... %only matlab ids that were eye-tracked
    %ismember(phaseData(:,pProtCol),phaseData(ETfilter,pProtCol)); %only
    %eye-tracking protocols %EDIT pretty sure this line wasn't doing
    %anything... see if it messes up
phaseData=phaseData(eyetrackedFilter,:);
%%%%%%%%%

%output is phaseCheck - first column is IDs (MATLAB ID if it exists,
%individual otherwise). One row per ID
pUnqPeople=unique(phaseData(:,pMatIDCol));
phaseCheck(:,1) = pUnqPeople;

%Next cols:
%  2. Eye-tracking not phase edited (insert specific phase, otherwise empty)
%  3. # sessions not uploaded
%  4. All phases in phase query
%  5. Binned ages in session query
%  6. Compensation not phase edited 

% EDIT: add check to see if dates match (eye-tracking and compensation)

for i=1:length(pUnqPeople)
    person = pUnqPeople(i);
    if isnumeric(person)
        person = str2double(person);
        sPersonCol = sIDCol;
        pPersonCol = pIDCol;
    else
        sPersonCol = sMatIDCol;
        pPersonCol = pMatIDCol;
    end

    tempPhase = phaseData(strcmpi(person,phaseData(:,pPersonCol)),:);
    tempSess = sessionData(strcmpi(person,sessionData(:,sPersonCol)),:);
    
    %filter for eyetracking phases:
    tempETFilter=cellfun(@(x) ~isempty(strfind(x,'Tracking')),tempPhase(:,pReqCol));
    
    %filter for compensation phases:
    tempCompFilter=cellfun(@(x) strcmpi('Compensation',x),tempPhase(:,pReqCol));
    
    % ET phases that weren't started
    notPhaseEdited=cellfun(@(x) strcmpi('not-started',x),tempPhase(:,pStatusCol));
    phaseCheck{i,2}=strjoin(tempPhase(notPhaseEdited&tempETFilter,pPhaseCol)');
    
    %# of sessions not uploaded = (# eye-tracking requirements in phase query) - (occurences in session query)
    phaseCheck{i,3} = sum(tempETFilter)-size(tempSess,1);
    
    %list of ET phases from phase query, list of binned ages from session query 
    phaseCheck{i,4} = strjoin(tempPhase(tempETFilter,pPhaseCol)','; ');
    phaseCheck{i,5} = strjoin(cellfun(@num2str,tempSess(:,sBinAgeCol),'UniformOutput',false)','; ');
        
    % Compensation phases that weren't started
    notCompPhaseEdited=cellfun(@(x) strcmpi('not-started',x),tempPhase(:,pStatusCol));
    phaseCheck{i,6}=strjoin(tempPhase(notCompPhaseEdited&tempCompFilter,pPhaseCol)');

end

%other people to check -- in the session query, but not the phase query
sUnqPeople=unique(sessionData(:,sMatIDCol));
[~,IA]=setdiff(sUnqPeople,pUnqPeople);
otherPhasesToCheck=sUnqPeople(IA);

%% Print people whose phase info should be checked. 
    
fprintf(fid,'\n\n*******************************\n*** ERROR CHECKING ***\n');

fprintf(fid,'\nNOT UPLOADED:');
toCheck = find(cellfun(@(x) x>0,phaseCheck(:,3)));
if sum(toCheck)
    fprintf(fid,',Individual,# Sessions Missing,Partial/Complete Phases,Uploaded Sessions (age in months)\n');
    for ii=toCheck' 
        fprintf(fid,',%s,%f,%s,%s\n',phaseCheck{ii,1},phaseCheck{ii,3},phaseCheck{ii,4},phaseCheck{ii,5});
    end
else
    fprintf(fid,',All good!\n');
end


fprintf(fid,'\nEYE-TRACKING NOT PHASE EDITED:');
toCheck = find(cellfun(@(x) ~isempty(x),phaseCheck(:,2)));
if sum(toCheck) || ~isempty(otherPhasesToCheck)
    
    fprintf(fid,',Individual,Phase(s)\n');
    if sum(toCheck)
        for ii=toCheck' 
            fprintf(fid,',%s,%s\n',phaseCheck{ii,1},phaseCheck{ii,2});
        end
    end
    if ~isempty(otherPhasesToCheck)
        for ii=1:size(otherPhasesToCheck,1)
            tempBinAges=sessionData(strcmpi(otherPhasesToCheck{ii},sessionData(:,sPersonCol)),sBinAgeCol);
            tempBinAges=strjoin(cellfun(@num2str,tempBinAges,'UniformOutput',false)');
            fprintf(fid,',%s,%s,**phase = binned age from uploaded session\n',otherPhasesToCheck{ii},tempBinAges);
        end
    end
else
    fprintf(fid,',All good!\n');
end

fprintf(fid,'\nCOMPENSATION NOT PHASE EDITED:');
toCheck = find(cellfun(@(x) ~isempty(x),phaseCheck(:,6)));
if sum(toCheck) || ~isempty(otherPhasesToCheck)
    fprintf(fid,',Individual,Phase(s)\n');
    
    if sum(toCheck)
        for ii=toCheck' 
            fprintf(fid,',%s,%s\n',phaseCheck{ii,1},phaseCheck{ii,6});
        end
    end
    if ~isempty(otherPhasesToCheck)
        for ii=1:size(otherPhasesToCheck,1)
            tempBinAges=sessionData(strcmpi(otherPhasesToCheck{ii},sessionData(:,sPersonCol)),sBinAgeCol);
            tempBinAges=strjoin(cellfun(@num2str,tempBinAges,'UniformOutput',false)');
            fprintf(fid,',%s,%s,**phase = binned age from uploaded session\n',otherPhasesToCheck{ii},tempBinAges);
        end
    end
else
    fprintf(fid,',All good!\n');
end

%%
%Print all sessions that were run, split by lab
fprintf(fid,'\n\n*******************************\n*** SESSIONS ***\n');
fprintf(fid,'(Compare to paper checklists)\n');
fprintf(fid,',Month,Day,Case,Fellows\n');

fprintf(fid,'INFANT LAB');
InfantLab=find((cell2mat(sessionData(:,sBinAgeCol))<6));
for ii=1:length(InfantLab)
    
    if sessionData{InfantLab(ii),sSessionCol}<10
        fprintf(fid,',%i,%i, %s_0%i,%s\n',sessionData{InfantLab(ii),sDateCol}(2),sessionData{InfantLab(ii),sDateCol}(3),...
            sessionData{InfantLab(ii),sMatIDCol},sessionData{InfantLab(ii),sSessionCol},sessionData{InfantLab(ii),sFellowsCol});
    else
        fprintf(fid,',%i,%i, %s_%i,%s\n',sessionData{InfantLab(ii),sDateCol}(2),sessionData{InfantLab(ii),sDateCol}(3),...
            sessionData{InfantLab(ii),sMatIDCol},sessionData{InfantLab(ii),sSessionCol},sessionData{InfantLab(ii),sFellowsCol});
    end
end

fprintf(fid,'TODDLER LAB');
ToddlerLab=find((cell2mat(sessionData(:,sBinAgeCol))>=6)&(cell2mat(sessionData(:,sBinAgeCol))<54));
for ii=1:length(ToddlerLab)
    if sessionData{ToddlerLab(ii),sSessionCol}<10
        fprintf(fid,',%i,%i, %s_0%i,%s\n',sessionData{ToddlerLab(ii),sDateCol}(2),sessionData{ToddlerLab(ii),sDateCol}(3),...
            sessionData{ToddlerLab(ii),sMatIDCol},sessionData{ToddlerLab(ii),sSessionCol},sessionData{ToddlerLab(ii),sFellowsCol});
    else
        fprintf(fid,',%i,%i, %s_%i,%s\n',sessionData{ToddlerLab(ii),sDateCol}(2),sessionData{ToddlerLab(ii),sDateCol}(3),...
            sessionData{ToddlerLab(ii),sMatIDCol},sessionData{ToddlerLab(ii),sSessionCol},sessionData{ToddlerLab(ii),sFellowsCol});
    end
end

fprintf(fid,'SCHOOL AGE LAB');
SALab=find((cell2mat(sessionData(:,sBinAgeCol))>54));
for ii=1:length(SALab)
    if sessionData{SALab(ii),sSessionCol}<10
        fprintf(fid,',%i,%i, %s_0%i,%s\n',sessionData{SALab(ii),sDateCol}(2),sessionData{SALab(ii),sDateCol}(3),...
            sessionData{SALab(ii),sMatIDCol},sessionData{SALab(ii),sSessionCol},sessionData{SALab(ii),sFellowsCol});
    else
        fprintf(fid,',%i,%i, %s_%i,%s\n',sessionData{SALab(ii),sDateCol}(2),sessionData{SALab(ii),sDateCol}(3),...
            sessionData{SALab(ii),sMatIDCol},sessionData{SALab(ii),sSessionCol},sessionData{SALab(ii),sFellowsCol});
    end
end


%%
fclose(fid);
fprintf(['Summary saved in:\n\t',weeklyCheckFile,'\n']);
disp(' ');
disp('---------------------------------------------------Done---------------------------------------------------')

else
disp('---------------------------------------------------Done---------------------------------------------------')
end


cd(origDir)
rmpath('../QueryTools')