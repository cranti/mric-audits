%WEEKLYCHECK This function can be used to run basic audits on the
%   MRIC database for a specified date range and save a csv summary.
%
% INPUTS:
%       startdate (string) - Beginning of the date range for the query (YYYY-MM-DD)
%       enddate (string) - End of the date range for the query (YYYY-MM-DD)
%
% This script uses processAuditQuery and processPhaseQuery to run a set of 
% queries for the date range specified in the inputs and process the 
% output. This script produces summaries of the data, to facilitate our
% (roughly) weekly checks/data audits.
%
% Saves a csv file in a directory specified in the script. The csv contains
% the following information:
%   - Date range of the MRIC query
%   - Summary of the sessions run in the date range & their qualities,
%   broken up by 1) lab (age range) and 2) binned age
%   - A list of all the sessions run and the dates that they were run on
%   (in the date range), split up by lab (to facilitate checking against
%   paper checklists)
%   - A list of any issues with the phases of individuals who were
%   compensated in the date range.
%
% Notes:
%   > Needs: processAuditQuery.m, processPhaseQuery.m, dataquery.py (V5)
%   > if the query has been run and/or the summary already exists, the
%   user will be asked whether they want to overwrite those files.
%
% EDIT: add phase check that will make sure dates in session match the
% phase completion date
%
% Possible future edits:
%   > LIVE- Print out what fellows are in charge of the NONC videos?


%Written by Carolyn Ranti 
%4.2.14
% >Edited 4.18.14 - fixed age=-1 issue (being put in infant lab), added
% row/column totals for quality by age table
% >Edited 5.1.14 - Changed the phase query so that it catches more issues,
% and updated this script accordingly
% >Edited 6.27.14 - Changed phase query again (in dataquery.py V5), updated
% this script. Results should be easier to interpret now.
% >Edited 7.7.14 - Fixed a bug from the phase query change. 
% >Updated 7.25.14

%DEBUGGING:
% startdate='2013-12-31';enddate='2014-04-25';

function weeklyCheck(startdate,enddate)



disp('----------------------------------------------------------------------------------------------------------')
disp('                                           Running weeklyCheck.m                                          ')

origDir = pwd;
queryDir = ['/Users/etl/Desktop/DataQueries/',startdate,'_',enddate];
fileDir = '/Users/etl/Desktop/DataQueries/WeeklyChecks';
FILENAME = ['WeeklyCheck',startdate,'_',enddate,'.csv'];

temp=strsplit(startdate,'-');
STARTYEAR=str2double(temp{1});
STARTMONTH=str2double(temp{2});
STARTDAY=str2double(temp{3});
temp=strsplit(enddate,'-');
ENDYEAR=str2double(temp{1});
ENDMONTH=str2double(temp{2});
ENDDAY=str2double(temp{3});

%% Run query & process query output, if necessary

%if the query dir can't be found, runPython should be set to 1
if ~exist(queryDir,'dir')
    runPython=1; %this catch exists in processAuditQuery, too
    processData=1;
else
    %If the query dir already exists, do not run query again
    disp(' ')
    disp('%%%%');
    fprintf(['Looks like this query exists in the following directory:\n\t',queryDir]);
    runPython=strcmpi('y',input('\nWould you like to run it again and overwrite any existing files? (y/n): ','s'));
    disp('%%%%');
    disp(' ');
    
    if ~runPython
        %If the mat file with processed data cannot be found, processData should be 1
        cd(queryDir)
        if ~exist([startdate,'_',enddate,'.mat'],'file')
            processData=1;
        else
            processData=0;
        end
    else
        processData=1; %it doesn't really matter what this is...
    end
end


%Run the query (runPython) and/or process query output (~runPython & processData) 
%and/or load already processed query output (~runPython & ~processData)
if processData || runPython
    cd(origDir)
    [sessionFields,sessionData,~,~,AllProtocols,sProtLogic,~]=processAuditQuery(startdate,enddate,runPython); %rollup info doesn't matter
else
    cd(queryDir)
    load([startdate,'_',enddate])
end

%date the query was run --> set as modification date for the folder
d = dir(queryDir);
queryRunDate = d(1).date; 

%Process phase query or load mat file
if ~exist([startdate,'_',enddate,'_phase.mat'],'file')
    cd(origDir)
    [phaseFields,phaseData]=processPhaseQuery(startdate,enddate);
else
    cd(queryDir)
    load([startdate,'_',enddate,'_phase.mat']);
end

%% Find column indices
pMatIDCol=find(strcmpi('Matlab ID',phaseFields));
pIDCol = find(strcmpi('ID',phaseFields));
pFullDateCol=find(strcmpi('Fulfillment Date',phaseFields));
pPhaseCol=find(strcmpi('Phase',phaseFields));
pReqCol=find(strcmpi('Requirement',phaseFields));
pStatusCol=find(strcmpi('Status',phaseFields));
pProtCol=find(strcmpi('Protocol',phaseFields));

sDateCol=find(strcmpi('Date',sessionFields));
sIDCol=find(strcmpi('ID',sessionFields));
sMatIDCol=find(strcmpi('Matlab ID',sessionFields));
sSessionCol=find(strncmpi('Session',sessionFields,7));
sQualCol=find(strcmpi('Quality',sessionFields));
sBinAgeCol=find(strcmpi('Binned Age',sessionFields));
sFellowsCol=find(strcmpi('Fellows',sessionFields));

%% Summary of sessions
cd(fileDir)
if exist(FILENAME,'file') && ~runPython
    disp(' ');
    disp('%%%%');
    fprintf(['A summary for this date range already exists in the following location:\n\t',fileDir,FILENAME]);
    overwriteFile=strcmpi('y',input('\nDo you want to overwrite the file? (y/n): ','s'));
    disp('%%%%');
    disp(' ');
else
    overwriteFile = 1;
end

if overwriteFile

fid=fopen(FILENAME,'w+');
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
% 1. Take out all wash u from session table
sWashuProtLogic=logical(sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'wash')),AllProtocols)),2));
sessionData=sessionData(~sWashuProtLogic,:);
sProtLogic=sProtLogic(~sWashuProtLogic,:);

% 2. if the MATLAB ID is empty, copy the individual id over (as a string)
for i = 1:size(phaseData,1)
    if isempty(phaseData{i,pMatIDCol})
        phaseData{i,pMatIDCol}=num2str(phaseData{i,pIDCol});
    end
end

% 3. Take out anyone who doesn't have an eye-tracking session
ETfilter=cellfun(@(x) ~isempty(strfind(x,'Tracking')),phaseData(:,pReqCol));
eyetrackedFilter=ismember(phaseData(:,pMatIDCol),phaseData(ETfilter,pMatIDCol))&... %only matlab ids that were eye-tracked
    ismember(phaseData(:,pProtCol),phaseData(ETfilter,pProtCol)); %only eye-tracking protocols
phaseData=phaseData(eyetrackedFilter,:);

%%%%%%%%%

%output is phaseCheck - first column is IDs (MATLAB if it exists,
%individual otherwise). One row per ID
pUnqPeople=unique(phaseData(:,pMatIDCol));
phaseCheck(:,1) = pUnqPeople;

%Next cols:
%  > Eye-tracking not phase edited (insert specific phase, otherwise empty)
%  > Did not upload session (# of sessions with issues)
%  > All phases in phase query
%  > Binned ages in session query
%  > Compensation not phase edited 

% EDIT: check that the dates match (eye-tracking and compensation)

for i=1:length(pUnqPeople)
    person = pUnqPeople(i);
    if isnumeric(person)
        person = str2num(person);
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
    
    %list of phases from phase query, list of binned ages from session
    %query
    phaseCheck{i,4} = strjoin(tempPhase(tempETFilter,pPhaseCol)','; '); %filtering by ET phases, so that there aren't repeats w/ compensation
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
    fprintf(fid,',Individual,# Sessions Missing,Compensated Phases,Uploaded Sessions (age in months)\n');
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
% 
% if ~isempty(otherPhasesToCheck)
%     fprintf(fid,'\n** There is data in the session table but this person was not phase edited properly for eye-tracking and/or compensation requirements.\n');
% end

%%
%Print all sessions that were run, split by lab
fprintf(fid,'\n\n*******************************\n*** SESSIONS ***\n');
fprintf(fid,'(Compare to paper checklists)\n');
fprintf(fid,',Month, Day, Case\n');

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
cd(origDir)
disp(['Results saved in ',fileDir,'/',FILENAME]);
disp(' ');
disp('---------------------------------------------------Done---------------------------------------------------')

else
disp('---------------------------------------------------Done---------------------------------------------------')
end