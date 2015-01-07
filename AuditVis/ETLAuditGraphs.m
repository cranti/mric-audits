function ETLAuditGraphs(startdate,enddate,doUnf)
%ETLAuditGraphs - Audit eye-tracking data in MRIC and visualize the
%results.
% 
% Usage:    ETLAuditGraphs(startdate,enddate,[1 or 0]) -- runs the queries
%               filtered by the specified date range. Optional 3rd input
%               allows user to specify whether to run unfiltered version
%               of the session query (i.e. returning the entire session
%               table).
%           ETLAuditGraphs() -- only runs the session table query that is
%               unfiltered by date range.
%
% Runs queries on the session table and the run table, and calls functions
% to visualize the results.
%
% File outputs include:
%       - a .txt file with each unique query that is run
%       - a .csv file with the results of each query
%       - a .mat file with processed results from each query
%       - .eps and .fig versions of each figure created
% All of these files are saved in subdirectories of 
%       /Users/etl/Desktop/DataQueries/Graphs/
%
% Figures are created separately for different protocol groupings (i.e.
% infant protocols, toddler protocols, and school age protocols), as well
% as for each protocol on its own. They are saved in separate
% subdirectories.
% * Remember to update the list of protocols over time (see the variable
% graphLoop, which is set near the top of the script).
%
% See also: AUDITQUERY, READINQUERY, SESSIONAUDITGRAPHS, RUNAUDITGRAPHS

% TODO
% > Analysis types x protocol 
% > Run query -- get around the limit to the number of rows returned

% Written by Carolyn Ranti 8.18.2014
% CVAR 1.5.15

%%
home
disp('*** ETLAuditGraphs ***')

%% CHANGE FOR INITIAL SET UP: directories and a loop to go through all protocol types
baseQueryDir = '/Users/etl/Desktop/DataQueries/BaseQueries/'; % where base queries are saved
mainResultsDir = '/Users/etl/Desktop/DataQueries/Graphs/'; % subdirectories will be created (named by date)

%TODO - save this in a mat file
field_names = {'dir', 'title', 'protocol'};
setup_loop = {'AllInfants', 'All Infant Protocols', {'ace-center-2012.eye-tracking-0-36m-2012-11';'infant-sibs.infant-sibs-high-risk-2011-12';'infant-sibs.infant-sibs-low-risk-2011-12'};
            'AllToddlers', 'All Toddler Protocols', {'toddler.toddler-asd-dd-2011-07','toddler.toddler-asd-dd-2012-11','toddler.toddler-td-2011-07','wash-u.toddler-twin-longitudinal-nontwinsib-2013-06','wash-u.toddler-twin-longitudinal-twinsib-2013-06'};
            'AllSchoolAge', 'All School Age Protocols', {'school-age.school-age-asf-fellowship-asd-dd-2012-07','school-age.school-age-asf-fellowship-td-2012-07'};
            'ace-center-2012.eye-tracking-0-36m-2012-11', 'ACE Eye Tracking 0-36M 2012-11', {'ace-center-2012.eye-tracking-0-36m-2012-11'};
            'infant-sibs.infant-sibs-high-risk-2011-12', 'Infant Sibs High Risk 2011-12', {'infant-sibs.infant-sibs-high-risk-2011-12'};
            'infant-sibs.infant-sibs-low-risk-2011-12', 'Infant Sibs Low Risk 2011-12', {'infant-sibs.infant-sibs-low-risk-2011-12'};
            'toddler.toddler-asd-dd-2011-07', 'Toddler ASD-DD 2011-07', {'toddler.toddler-asd-dd-2011-07'};
            'toddler.toddler-asd-dd-2012-11', 'Toddler ASD-DD 2012-12', {'toddler.toddler-asd-dd-2012-11'};
            'toddler.toddler-td-2011-07', 'Toddler TD 2011-07', {'toddler.toddler-td-2011-07'};
            'school-age.school-age-asf-fellowship-asd-dd-2012-07', 'School Age ASF Fellowship ASD-DD 2012-07', {'school-age.school-age-asf-fellowship-asd-dd-2012-07'};
            'school-age.school-age-asf-fellowship-td-2012-07', 'School Age ASF Fellowship TD 2012-07', {'school-age.school-age-asf-fellowship-td-2012-07'};
            'wash-u.toddler-twin-longitudinal-nontwinsib-2013-06', 'Wash U Toddler Twin Longitudinal Non-Twin Sib 2013-06', {'wash-u.toddler-twin-longitudinal-nontwinsib-2013-06'};
            'wash-u.toddler-twin-longitudinal-twinsib-2013-06', 'Wash U Toddler Twin Longitudinal Twin Sib 2013-06', {'wash-u.toddler-twin-longitudinal-twinsib-2013-06'};
};
graphLoop = cell2struct(setup_loop, field_names, 2);

            
%% Add things to the path
origDir = pwd;
nameOfFunc = 'ETLAuditGraphs.m';
funcPath = which(nameOfFunc);
funcPath = funcPath(1:end-length(nameOfFunc));
cd(funcPath);
cd ..
basePathDir = pwd;
addpath([basePathDir,'/AuditVis'],[basePathDir,'/QueryTools'])


%% Select which queries to run

%default is to do 'em all
doSessionQuery = 1; 
doRunQuery = 1;
doUnfSessionQuery = 1;
doUnfRunQuery = 1;

if nargin==0
    disp(' ');
    disp('No dates entered -- only running unfiltered.');
    disp(' ');
    doSessionQuery = 0;
    doRunQuery = 0;
    
elseif nargin==3
    doUnfSessionQuery = doUnf;
%     doUnfRunQuery = doUnf;
end


%% 
disp('Let''s visualize some data!')
disp([' ** NOTE: You''ll be prompted to log in to MRIC ',num2str(sum([doSessionQuery,doRunQuery,doUnfSessionQuery,doUnfRunQuery])),' time(s).']);
disp(' ');


%% Session query

resultsDir = [mainResultsDir,startdate,'_',enddate,'/'];
textResultsDir = [resultsDir, 'files/'];

if doSessionQuery
    
    %QUERY MRIC
    baseQueryFile = [baseQueryDir,'sessionQuery.txt'];
    [fields,data] = AuditQuery(textResultsDir, baseQueryFile, startdate, enddate);
    
    % Add binned ages column
    ageCol = strncmpi('Age',fields,3);
    [fields,data] = AddBinnedAge(fields,data,ageCol);
    % Add week start column
    dateCol = strcmpi('Date',fields);
    [fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
    
    for ii=1:length(graphLoop)
        dirToSaveGraphs=[resultsDir,graphLoop(ii).dir];
        if ~exist(dirToSaveGraphs,'dir')
            mkdir(dirToSaveGraphs)
        end

        SessionAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol);
        close all
    end
    
    cd(origDir)
end


%% Run query
if doRunQuery
    baseQueryFile=[baseQueryDir,'runQuery.txt']; 
    
    [fields,data] = AuditQuery(textResultsDir,baseQueryFile,startdate,enddate);
    % Add binned ages column
    ageCol = strncmpi('Age',fields,3);
    [fields,data] = AddBinnedAge(fields,data,ageCol);
    % Add week start column
    dateCol = strcmpi('Date',fields);
    [fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
    
    for ii=1:length(graphLoop)
        dirToSaveGraphs=[resultsDir,graphLoop(ii).dir];
        if ~exist(dirToSaveGraphs,'dir')
            mkdir(dirToSaveGraphs)
        end

        RunAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol);
        close all
    end
    
    cd(origDir)
end


%% Session query for ENTIRE session table

UNFresultsDir = [mainResultsDir,'SessionsUpTo',datestr(today,'yyyy-mm-dd'),'/'];
UNFtextResultsDir = [UNFresultsDir,'/files/'];

if doUnfSessionQuery
    baseQueryFile=[baseQueryDir,'sessionQuery_noFilters.txt']; 
    
    [fields,data] = AuditQuery(UNFtextResultsDir,baseQueryFile);
    % Add binned ages column
    ageCol = strncmpi('Age',fields,3);
    [fields,data] = AddBinnedAge(fields,data,ageCol);
    % Add week start column
    dateCol = strcmpi('Date',fields);
    [fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
    
    
    for ii=1:length(graphLoop)
        dirToSaveGraphs=[UNFresultsDir,graphLoop(ii).dir];
        if ~exist(dirToSaveGraphs,'dir')
            mkdir(dirToSaveGraphs)
        end

        SessionAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol);
    end
    close all
    cd(origDir)
end


%% Run query for ENTIRE run table - TODO (not currently working)
% if doUnfRunQuery
%     baseQueryFile = [baseQueryDir,'runQuery_noFilters.txt']; 
%     resultsDir = [mainResultsDir,'SessionsUpTo',datestr(today,'yyyy-mm-dd'),'/'];
%     
%     [fields,data] = AuditQuery(UNFtextResultsDir,baseQueryFile);
%     % Add binned ages column
%     ageCol = strncmpi('Age',fields,3);
%     [fields,data] = AddBinnedAge(fields,data,ageCol);
%     % Add week start column
%     dateCol = strcmpi('Date',fields);
%     [fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
%     
%     for ii=1:length(graphLoop)
%         dirToSaveGraphs=[UNFresultsDir,graphLoop(ii).dir];
%         if ~exist(dirToSaveGraphs,'dir')
%             mkdir(dirToSaveGraphs)
%         end
% 
%         RunAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol);
%     end
%     close all
%     cd(origDir)
% end

%% Remove extra things from path
rmpath([basePathDir,'/AuditVis'], [basePathDir,'/QueryTools'])
