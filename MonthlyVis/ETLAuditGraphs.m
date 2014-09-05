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
% Results saved WHERE?
% Graphs saved WHERE?
%
%
%
%
% * Remember to update the list of protocols over time (see the variable
% graphLoop, which is set near the top of the script)
%
% *** If running the script on a computer for the first time ***
% - Change default directories (at top of script)
% - Change directories in AuditGraphs (pythonDir and the defaults)
% - The way the path is currently being set, the folder organization should
%   be as follows:
%       > In some parent directory, there should be two folders:
%               MonthlyVis/     QueryTools/
%       > This script should be saved in MonthlyVis/
%       > Recommended that SessionAuditGraphs and RunAuditGraphs are also
%       saved in MonthlyVis/
%       > All supporting scripts should be saved in QueryTools/, including
%       the Python scripts
%
% - NOTE: to make this script compatible with P&T computer (ie MATLAB2012),
%   replace strsplit and strjoin in supporting scripts with strsplit_CR and
%   strjoin_CR, respectively. Currently, I believe only ReadInQuery.m is
%   using strsplit.
%
% See also: AUDITQUERY, READINQUERY, SESSIONAUDITGRAPHS, RUNAUDITGRAPHS

% EDITS TO MAKE
% > Dates!! -- currently, pretty sure it's looping through all "weekly
% starts" where there are sessions. Change so that it graphs an empty spot
% if there aren't any sessions there. (fix this after i figure out whether
% to bin by week or month)
%
% > Assessments query
% 
% > Run query -- is there a limit to the number of rows returned? This could
% be an issue if running long audits
% 
% > error checking
% > finish documenting everything, check that it's all working
%
% > Process the queries further in HERE (add binned age/week start column)
% -- resave the matfile with the extra input.

% Written by Carolyn Ranti 8.18.2014
% CVAR 9.5.14

%%
% dbstop if error
home
disp('*** ETLAuditGraphs ***')

%% CHANGE FOR INITIAL SET UP: directories and a loop to go through all protocol types
baseQueryDir = '/Users/etl/Desktop/DataQueries/BaseQueries/'; %where base queries are saved
mainResultsDir = '/Users/etl/Desktop/DataQueries/Graphs/'; %subdirectories will be created (named by date)


%TODO - check all of these. also, where does 'infant-sibs.infant-sibs-high-risk-older-sib-2011-12' belong? 
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
    doSessionQuery = 1; %strcmpi('y',input('Run the date-filtered Session Table query? (y/n): ','s'));
    doRunQuery = 1;
end
doUnfSessionQuery = 1;
doUnfRunQuery = 0; %not working right now -- change this once the query stuff is fixed :(

disp('Let''s visualize some data!')

%% Session query
if doSessionQuery
    baseQueryFile = [baseQueryDir,'sessionQuery.txt'];
    resultsDir = [mainResultsDir,startdate,'_',enddate,'/'];
    
    [fields,data] = AuditQuery(resultsDir,baseQueryFile,startdate,enddate);

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
