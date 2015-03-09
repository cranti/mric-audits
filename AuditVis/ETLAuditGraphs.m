function ETLAuditGraphs(startdate,enddate,varargin)
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
% Optional parameters:
%   'unfilteredQs'  1 or 0 -- run unfiltered queries (currently just
%                   Session table)
%   'verbose'       1 or 0 -- if 0, only a few messages are printed to the
%                   command line (passed to RunAuditGraphs and
%                   SessionAuditGraphs)
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
% CVAR 3.9.15
%%
dbclear if error
home
disp('------------------------------------------------------------------------------------------')
disp('                                 Running ETLAuditGraphs.m                                 ')

finalWarnings = {};

%% CHANGE FOR INITIAL SET UP: directories and a loop to go through all protocol types
baseQueryDir = '/Users/etl/Desktop/DataQueries/BaseQueries/'; % where base queries are saved
mainResultsDir = '/Users/etl/Desktop/DataQueries/Graphs/'; % subdirectories will be created (named by date)

% This should be updated/checked periodically
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

%% parse inputs (verbosity, select which queries to run)

%default verbosity is on
verbose = 1;

%default is to do 'em all
doSessionQuery = 1; 
doRunQuery = 1;
doUnfSessionQuery = 1;
doUnfRunQuery = 1;

if ~isempty(varargin)
    assert(mod(length(varargin),2)==0,'Optional inputs must be in name, value pairs (odd number of parameters passed in).');
    for i = 1:2:length(varargin)
        switch lower(varargin{i})
            case 'unfilteredqs'
                temp = varargin{i+1};
                assert(temp==1 || temp==0, 'unfilteredQs must be either 1 or 0');
                doUnfSessionQuery = temp;
                doUnfRunQuery = temp;
            case 'verbose'
                verbose = varargin{i+1};
            otherwise
                warning('Unidentified parameter name: %s',varargin{i});
        end
    end
end

if nargin==0
    disp(' ');
    disp('No dates entered -- only running unfiltered.');
    disp(' ');
    doSessionQuery = 0;
    doRunQuery = 0;
end
            
%% Add things to the path
origDir = pwd;
nameOfFunc = 'ETLAuditGraphs.m';
funcPath = which(nameOfFunc);
funcPath = funcPath(1:end-length(nameOfFunc));
cd(funcPath);
cd ..
basePathDir = pwd;
addpath([basePathDir,'/AuditVis'],[basePathDir,'/QueryTools'])

%% 
sprintf(' ** NOTE: You''ll be prompted to log in to MRIC %i time(s).\n', sum([doSessionQuery,doRunQuery,doUnfSessionQuery,doUnfRunQuery]));
disp('!! Careful typing in your username and password -- you cannot use backspace');
disp(' ');


%% Session query
resultsDir = [mainResultsDir,startdate,'_',enddate,'/'];
textResultsDir = [resultsDir, 'files/'];


if doSessionQuery
   try 
        %QUERY MRIC
        baseQueryFile = [baseQueryDir,'sessionQuery.txt'];
        try
            [fields,data] = AuditQuery(textResultsDir, baseQueryFile, startdate, enddate);
        catch
            disp(' ');
            disp('The query was unsuccessful -- try again');
            %if this fails again, it will be caught by the bigger try/catch
            [fields,data] = AuditQuery(textResultsDir, baseQueryFile, startdate, enddate); 
        end
        
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

            SessionAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol, 'verbose', verbose);
            close all
        end

        cd(origDir)
   catch
       finalWarnings{end+1} = 'Date-filtered session query failed.';
   end
end

%% Run query

if doRunQuery
    try
        baseQueryFile=[baseQueryDir,'runQuery.txt']; 

        try
            [fields,data] = AuditQuery(textResultsDir, baseQueryFile, startdate, enddate);
        catch
            disp(' ');
            disp('The query was unsuccessful -- try again');
            %if this fails again, it will be caught by the bigger try/catch
            [fields,data] = AuditQuery(textResultsDir, baseQueryFile, startdate, enddate);  
        end
        
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

            RunAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol, 'verbose', verbose);
            close all
        end

        cd(origDir)
    catch
       finalWarnings{end+1} = 'Date-filtered run query failed.';
    end
end


%% Session query for ENTIRE session table


UNFresultsDir = [mainResultsDir,'SessionsUpTo',datestr(today,'yyyy-mm-dd'),'/'];
UNFtextResultsDir = [UNFresultsDir,'/files/'];

if doUnfSessionQuery
    try
        baseQueryFile=[baseQueryDir,'sessionQuery_noFilters.txt']; 
        try
            [fields,data] = AuditQuery(UNFtextResultsDir,baseQueryFile);
        catch
            disp(' ');
            disp('The query was unsuccessful -- try again');
            %if this fails again, it will be caught by the bigger try/catch
            [fields,data] = AuditQuery(UNFtextResultsDir,baseQueryFile);
        end
        
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

            SessionAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol, 'verbose', verbose);
            close all
        end
        cd(origDir)
    catch
       finalWarnings{end+1} = 'Unfiltered session query failed.';
    end
end


%% Run query for ENTIRE run table - TODO (not currently working). Also, not up-to-date with try/catch, etc
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
%         RunAuditGraphs(dirToSaveGraphs,graphLoop(ii).title,fields,data,graphLoop(ii).protocol, 'verbose', verbose);
%     end
%     close all
%     cd(origDir)
% end

disp(' ');
for w = 1:length(finalWarnings)
    warning(finalWarnings{w})
end

disp('------------------------------------------Done--------------------------------------------')