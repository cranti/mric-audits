function [fields,data] = AuditQuery(resultsDir,baseQueryFile,varargin)
%AUDITQUERY
%
% Inputs: 
%       resultsDir -- where should the edited query and the query results b
%         be saved. Can pass a full path. If full path isn't passed,
%         defaults to /Users/etl/Desktop/DataQueries/AuditGraphs/
%       baseQueryFile -- name of a text file with the base query (see below
%         for details). Can pass a full path. If full path isn't passed,
%         looks in /Users/etl/Desktop/DataQueries/BaseQueries/
%       varargin -- strings to fill in the gaps in the base query (see
%         below for details)
%
% Outputs:
%       fields (cell) -- column headers corresponding to data
%       data (cell) -- results of the query. Data are read in as numbers
%         where possible, and strings otherwise. See notes about base
%         queries for information about special array case.
%   
% BASE QUERIES:
%   HTSQL query, saved as a .txt file. It can be a complete query OR it can
%   have fields that will be filled in flexibly (e.g., if you want to run
%   the same query for different date ranges). To create a flexible query, 
%   use %X in place of any field that will be filled in later. Then, when 
%   running this script, pass in string arguments in the order that they 
%   should be inserted into the script.
%       FOR EXAMPLE: 
%       A session query for a date range that will be specified at the time
%       that the script is run might look like this:
%           /session?date>='%X'&date<='%X'
%       The query above should be saved in a text file (e.g. 'exampleQuery.txt')
%       Running this script with the following command:
%           auditQuery('exampleDir','exampleQuery.txt','2014-08-01','2014-08-15')
%       will produce the following query to MRIC:
%           /session?date>='2014-08-01'&date<='2014-08-15'
%   Be careful to have single quotes for any field that should be in the query
%   as a string.
%   If the query is returning an array, include array in the column title (e.g.
%   Protocolarray) so that READINQUERY can process it as such.
%   The script will error out if it cannot find the base query, or if it doesn't
%   have enough arguments to replace the "%X"s.
% 
% FILE NAMING SCHEME:
%   All results are saved in the specified resultsDir. If that folder does not
%   exist, the script will create it.
%   Results from the query are saved as 
%       Results_[name of base query file].txt
%   by the Python script flexibleQuery.py. If that file already exists in the
%   resultsDir, the script will ask the user whether they want to overwrite
%   the data. 
%   The script will produce an error if it cannot open the results file (e.g. if 
%   there is an error in the Python script)
%
%   The text file is read in using READINQUERY, and the resulting variables
%   data and fields are saved as a matfile called 
%       Results_[name of base query file].mat 
%   Currently, the script will always reprocess results, overwriting any
%   matfile that exists with that name.
%
% INITIAL SCRIPT SET UP:   
%   Change the default directories (top of script)
%   Make sure flexibleQuery.py exists on computer, and the script knows where
%       to look for it.
%
% See also: READINQUERY, ETLAUDITGRAPHS, SESSIONAUDITGRAPHS, RUNAUDITGRAPHS

% Written by Carolyn Ranti 8.15.14
% CVAR 8.20.14

%%
origDir = pwd;

% DEFAULT DIRECTORIES:
pythonDir = 'Users/etl/Desktop/mric-audits/QueryTools/';

% If full paths aren't passed in, script looks in these folders
resultsDirBasePath = '/Users/etl/Desktop/DataQueries/Graphs/';
baseQueryDir = '/Users/etl/Desktop/DataQueries/BaseQueries/';


%% Check for existence of base query 

% if full path isn't passed in for the base query file, look in baseQueryDir
if ~strcmpi(baseQueryFile(1),'/')
    baseQueryName = strsplit(baseQueryFile,'.');
    baseQueryName = baseQueryName{1};
    baseQueryFile = [baseQueryDir,baseQueryFile];
else
    temp = strsplit(baseQueryFile,'/');
    temp = temp{end};
    temp = strsplit(temp,'.');
    baseQueryName = temp{1};
end

assert(logical(exist(baseQueryFile,'file')),['Error in AuditQuery: cannot find the base query file ',baseQueryFile]);

%% Check for results directory and file

% if full path isn't passed in for the results directory, default to resultsDirBasePath
if ~strcmpi(resultsDir(1),'/')
    resultsDir = [resultsDirBasePath,resultsDir];
end

% add trailing / if it's missing
if ~strcmpi(resultsDir(end),'/')
    resultsDir = [resultsDir,'/'];
end

if ~exist(resultsDir,'dir')   
    mkdir(resultsDir)
end

% File naming
newQueryFile = [resultsDir,baseQueryName,'.txt']; 
resultsFile = [resultsDir,'Results_',baseQueryName,'.csv'];
matFileName = ['Results_',baseQueryName];

% if results file already exists, ask user if they want to overwrite
if exist(resultsFile,'file')
    disp(' ')
    disp(['A results file already exists with the name specified (',resultsFile,')']);
    runPython=strcmpi('y',input('Would you like to run the query again and overwrite existing files? (y/n): ','s'));
else
    runPython=1;
end


%%
if runPython
    %% Edit the base query
    %read in base query
    fid = fopen(baseQueryFile);
    baseQuery = fgetl(fid);
    fclose(fid);
    
    %find/replace "%X"s -- if there aren't enough optional arguments, error
    %EDIT - check that it still works with %X and change baseQueries
    repSpots = strfind(baseQuery,'%X');
    if length(repSpots)~=length(varargin)
        error('Incorrect number of arguments to fill in the base query.');
    end
    
    %replace %% with varargin
    for i=1:length(repSpots)
        baseQuery=[baseQuery(1:repSpots(i)-1),varargin{i},baseQuery(repSpots(i)+2:end)];
        repSpots=repSpots+(length(varargin{i})-2);
    end
    
    %save the new query in the directory where these graphs will be saved
    fidN = fopen(newQueryFile,'w');
    fprintf(fidN,baseQuery);
    fclose(fidN);
    
    
    %% Call script to run the queries (flexibleQuery.py) 
    cd(pythonDir)
    disp(' ')
    disp('-----RUNNING flexibleQuery.py-----')
    system(['python flexibleQuery.py ',newQueryFile,' ',resultsDir]); %MATLAB command line will display prompts for MRIC username/password
    disp('----------------------------------')
    cd(origDir)
    
    % Produce error if the results file doesn't exist
    if ~exist(resultsFile,'file')
        error(['Cannot find results file: ',resultsFile])
    end
    
    
end

%% Read in queries, do some formatting
%only reprocess if necessary (if query was run OR matfile doesn't exist)
cd(resultsDir)
processQuery = 0;
if runPython || ~exist(matFileName,'file')
    processQuery = 1;
else %otherwise, load in existing matfile and check for variables
    load(matFileName); %this will give fields and data
    if ~exist('fields','var') || exist('data','var')
        processQuery = 1;
    end
end

if processQuery
    disp(' ')
    disp('Reading in query results...');
    [fields,data] = ReadInQuery(resultsFile);

    save(matFileName,'fields','data'); 
    disp(['Processed results saved: ',matFileName,'.mat']);
end

cd(origDir)