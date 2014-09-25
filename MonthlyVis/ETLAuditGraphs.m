function ETLAuditGraphs(startdate,enddate)
%ETLAuditGraphs - Audit eye-tracking data in MRIC and visualize the
%results.
% 
% Usage:    ETLAuditGraphs(startdate,enddate) -- runs the queries filtered
%               by the specified date range. Also runs a session table
%               query that is NOT filtered by dates. 
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
% infant protocols, toddler protocols, and school age protocols), and they
% are saved in separate subdirectories
% * Remember to update the list of protocols over time (see the variable
% graphLoop, which is set near the top of the script).
%
%
%
% *** If running the script on a computer for the first time ***
% - Create folders for base queries and results
% - Change default directories (at top of this script)
% - Change directories in AuditQuery.m (pythonDir and the defaults)
% - The way the path is currently being set, the folder organization should
%   be as follows:
%       > In some parent directory, there should be two folders:
%               MonthlyVis/     QueryTools/
%       > This script should be saved in MonthlyVis/
%       > Recommended that SessionAuditGraphs and RunAuditGraphs are also
%       saved in MonthlyVis/
%       > All supporting scripts should be saved in QueryTools/, including
%       the Python scripts
% - Can use testQueryTools.m to validate scripts in QueryTools/ 
%
% - NOTE: to make this script compatible with P&T computer (ie MATLAB2012),
%   replace strsplit with strsplit_CR in ReadInQuery.m.
%
% See also: AUDITQUERY, READINQUERY, SESSIONAUDITGRAPHS, RUNAUDITGRAPHS

% TODO
% > Assessments query
% > Run query -- get around the limit to the number of rows returned
% > Check protocol list w/ WJ

% Written by Carolyn Ranti 8.18.2014
% CVAR 9.25.14

%%
home
disp('*** ETLAuditGraphs ***')

%% CHANGE FOR INITIAL SET UP: directories and a loop to go through all protocol types
baseQueryDir = '/Users/etl/Desktop/DataQueries/BaseQueries/'; %where base queries are saved
mainResultsDir = '/Users/etl/Desktop/DataQueries/Graphs/'; %subdirectories will be created (named by date)

%TODO - check all of these w/ WJ. also, where does 'infant-sibs.infant-sibs-high-risk-older-sib-2011-12' belong? 
graphLoop = struct('dir',{'InfantGraphs','ToddlerGraphs','SchoolAgeGraphs'},...
    'title',{'Infant','Toddler','School Age'},...
    'protocol',{{'ace-center-2012.eye-tracking-0-36m-2012-11';'infant-sibs.infant-sibs-high-risk-2011-12';'infant-sibs.infant-sibs-low-risk-2011-12'}... 
                {'toddler.toddler-asd-dd-2011-07','toddler.toddler-asd-dd-2012-11','toddler.toddler-td-2011-07'}...
                {'school-age.school-age-asf-fellowship-asd-dd-2012-07','school-age.school-age-asf-fellowship-td-2012-07'}});

            
            
%% Add things to the path
origDir = pwd;
nameOfFunc = 'ETLAuditGraphs.m';
funcPath = which(nameOfFunc);
funcPath = funcPath(1:end-length(nameOfFunc));
cd(funcPath);
cd ..
basePathDir = pwd;
addpath([basePathDir,'/MonthlyVis'],[basePathDir,'/QueryTools'])

%% Select which queries to run
if nargin==0
    disp(' ');
    disp('No dates entered -- will not run the queries that require a date range.');
    disp(' ');
    doSessionQuery = 0;
    doRunQuery = 0;
else
    doSessionQuery = 1; 
    doRunQuery = 1;
end

doUnfSessionQuery = 1;
doUnfRunQuery = 0; %TODO - not running unfiltered run query yet

disp('Let''s visualize some data!')

disp(' ');
disp('NOTE:');
disp(['   You''ll be prompted to log in to MRIC ',num2str(sum([doSessionQuery,doRunQuery,doUnfSessionQuery,doUnfRunQuery])),' time(s).']);
disp(' ');
%% Session query
if doSessionQuery
    baseQueryFile = [baseQueryDir,'sessionQuery.txt'];
    resultsDir = [mainResultsDir,startdate,'_',enddate,'/'];
    
    [fields,data] = AuditQuery(resultsDir,baseQueryFile,startdate,enddate);
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
    end
    close all
    cd(origDir)
end


%% Run query
if doRunQuery
    baseQueryFile=[baseQueryDir,'runQuery.txt']; 
    resultsDir = [mainResultsDir,startdate,'_',enddate,'/'];
    
    [fields,data] = AuditQuery(resultsDir,baseQueryFile,startdate,enddate);
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
    end
    close all
    cd(origDir)
end


%% Session query for ENTIRE session table
if doUnfSessionQuery
    baseQueryFile=[baseQueryDir,'sessionQuery_noFilters.txt']; 
    resultsDir = [mainResultsDir,'SessionsUpTo',datestr(today,'yyyy-mm-dd'),'/'];
    
    [fields,data] = AuditQuery(resultsDir,baseQueryFile);
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
    end
    close all
    cd(origDir)
end


%% Run query for ENTIRE run table
if doUnfRunQuery
    baseQueryFile = [baseQueryDir,'runQuery_noFilters.txt']; 
    resultsDir = [mainResultsDir,'SessionsUpTo',datestr(today,'yyyy-mm-dd'),'/'];
    
    [fields,data] = AuditQuery(resultsDir,baseQueryFile);
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
    end
    close all
    cd(origDir)
end

%% Assessment queries
% #8 	Assessments -- expected vs actual for each assessment


%% Remove extra things from path
rmpath([basePathDir,'/MonthlyVis'],[basePathDir,'/QueryTools'])
