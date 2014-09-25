%TESTQUERYTOOLS
%
% Test that the scripts in QueryTools are working as expected. 
% Currently testing:
%   AddBinnedAge.m
%   AddWeekStart.m - TODO: split some of the weird inputs out of test 1
%   ProtocolLogic.m (only 1 test currently) - - TODO: add empty cell in one row
%   AuditQuery.m 
%   ReadInQuery.m
%
% To do (in entire suite):
%   change file validation  -- don't use fid == -1, ust exist() first
%   open files as read only
%   write log files?
%   error catching in master script --> if one throws an error, do I want
%   to try the next query?

% Written by Carolyn Ranti
% CVAR 9.25.2014

function testQueryTools
curDir = pwd;
addpath(curDir);
cd('/Users/etl/Desktop/mric-audits/QueryTools')

if strcmpi(input('clc command window? (y/n)','s'),'y')
    clc;
else
    home;
end

aba = testAddBinnedAge;
aws = testAddWeekStart;
pl = testProtocolLogic;
riq = testReadInQuery;
aq = testAuditQuery;

disp(' ');
disp('----------------------------------------');
disp('---------testQueryTools Summary---------');
disp(' ');
disp(['AddBinnedAge.m: ',aba]);
disp(['AddWeekStart.m: ',aws]);
disp(['ProtocolLogic.m: ',pl]);
disp(['ReadInQuery.m: ',riq]);
disp(['AuditQuery.m: ',aq]);
disp(' ');
disp('(see messages above for details)');
disp('----------------------------------------');
disp('----------------------------------------');

rmpath(curDir);
end

%% test AddBinnedAge.m
% Tests:
%   1 (normal inputs, check one of each age)
%	2 (binned age column already exists)
function msg = testAddBinnedAge
disp(' ');
disp('Testing AddBinnedAge.m...');
pass = true;

%% test case 1 (normal, check a few of each age):
e = '';
fieldsIn = {'Col1','Col2'};
matchFieldsOut = {'Col1','Col2','BinnedAge'};
inAgeCol = 1;

matchDataOut = {[],'abc',-1; %empty = -1
        {6},'abc',-1; % cell = -1
        {'6'},'abc',-1; %cellstring = -1
        '6','abc',-1; %string = -1
        1.2,'abc',1;
        6.1,'abc',6;
        6.8,'abc',6;
        8.1,'abc',9;
        9.9,'abc',9;
        11.4,'abc',12;
        12.9,'abc',12;
        14.1,'abc',15;
        15.9,'abc',15;
        20,'abc',18;
        29.1,'abc',24;
        29.9,'abc',36;
        43,'abc',48;  %3.58yrs = 4
        66,'abc',72; %5.5yrs = 6
        73,'abc',72}; %6.1yrs = 6
dataIn = matchDataOut(:,1:2);

disp('****** 2 warnings should be printed: ******'); %cells and strings (one warning for each)
try [fieldsOut,dataOut] = AddBinnedAge(fieldsIn,dataIn,inAgeCol);
catch e
end
disp('*******************************************');

if isempty(e)
    if ~isequal(fieldsOut,matchFieldsOut)
        pass = false;
        disp('Test 1 FAIL: fields do not match');
    end
    
    if ~isequal(dataOut,matchDataOut)
        pass = false;
        disp('Test 1 FAIL: data does not match');
    end
else
    pass = false;
    disp('Test 1 FAIL: produced error for inputs that it should be able to handle.');
end


%% test case 2 (binned age column already exists):
fieldsIn = {'Col1','Age','BinnedAge'};
dataIn = {1,2,3;4,5,6};
inAgeCol = 2;

[fieldsOut,dataOut] = AddBinnedAge(fieldsIn,dataIn,inAgeCol);

if ~isequal(fieldsOut,fieldsIn)
    pass = false;
    disp('Test 4 FAIL: fields should not have changed');
end

if ~isequal(dataOut,dataIn)
    pass = false;
    disp('Test 4 FAIL: data should not have changed');
end

%% Overall
if pass
    disp('All tests passed!');
    msg = 'PASS';
else
    msg = 'FAIL';
end

end

%% test AddWeekStart.m
% Tests:
%   1 (acceptable inputs, no start date specified)
%   2 (startDay = 'wed')
%   3 (startDay is not a real day of the week)
%   4 (WeekStart column already exists)
function msg = testAddWeekStart
disp(' ');
disp('Testing AddWeekStart.m...')
pass = true;

%% test case 1 (various inputs, no start date specified)
e='';
fieldsIn = {'Col1','Col2'};
matchFieldsOut = {'Col1','Col2','WeekStart'};
dateCol = 1;

matchDataOut = {[],'abc',[-1,-1,-1]; %empty
        '2014-09-15','abc',[-1 -1 -1]; %datestrings are not converted
        'hello','abc',[-1 -1 -1]; %strings are not converted
        [2014 9],'abc',[-1 -1 -1]; %not enough numbers = not converted
        [2014 9 1 5],'abc',[-1 -1 -1]; %too many numbers = not converted
        [2014 9 15],'abc',[2014 9 15]; %monday
        [2014 9 16],'abc',[2014 9 15]; %tuesday
        [2014 9 18],'abc',[2014 9 15]; %thursday
        [2014 9 21],'abc',[2014 9 15]}; %sunday
dataIn = matchDataOut(:,1:2);


disp('****** 5 warnings should be printed: ******');
try [fieldsOut,dataOut] = AddWeekStart(fieldsIn,dataIn,dateCol);
catch e
end
disp('*******************************************');

if isempty(e)
    if ~isequal(fieldsOut,matchFieldsOut)
        pass = false;
        disp('Test 1 FAIL: fields do not match');
    end
    
    if ~isequal(dataOut,matchDataOut)
        pass = false;
        disp('Test 1 FAIL: data does not match');
    end
else
    pass = false;
    disp('Test 1 FAIL: produced error for inputs that it should be able to handle.')
end

%% test case 2 (startDay = 'wed')
e = '';
fieldsIn = {'Col1','Col2'};
matchFieldsOut = {'Col1','Col2','WeekStart'};
dateCol = 1;

matchDataOut = {[2014 9 15],'abc',[2014 9 10]; %monday
        [2014 9 16],'abc',[2014 9 10]; %tuesday
        [2014 9 18],'abc',[2014 9 17]; %thursday
        [2014 9 21],'abc',[2014 9 17]}; %sunday
dataIn = matchDataOut(:,1:2);

[fieldsOut,dataOut] = AddWeekStart(fieldsIn,dataIn,dateCol,'wed');

if isempty(e)
    if ~isequal(fieldsOut,matchFieldsOut)
        pass = false;
        disp('Test 2 FAIL: fields do not match');
    end
    
    if ~isequal(dataOut,matchDataOut)
        pass = false;
        disp('Test 2 FAIL: data does not match');
    end
else
    pass = false;
    disp('Test 2 FAIL: produced error for inputs that it should be able to handle.');
end


%% test case 3 (startDay is not a real day of the week)
fieldsIn = {'Col'};
dataIn = {[1 2 3]};
dateCol = 1;
startDay = 'fir';

clear e; e.identifier = '';
try AddWeekStart(fieldsIn,dataIn,dateCol,startDay);
catch e
end

if ~strcmpi(e.identifier,'QueryTools:badInput')
    disp('Test 3 FAIL: should throw badInput error if there are more fields than data columns');
    pass = false;
end

%% test case 4 (WeekStart column already exists)
fieldsIn = {'Col1','Week','WeekStart'};
dataIn = {1,2,3;4,5,6};
dateCol = 2;

[fieldsOut,dataOut] = AddWeekStart(fieldsIn,dataIn,dateCol);

if ~isequal(fieldsOut,fieldsIn)
    pass = false;
    disp('Test 4 FAIL: fields should not have changed');
end

if ~isequal(dataOut,dataIn)
    pass = false;
    disp('Test 4 FAIL: data should not have changed');
end


%% 
if pass
    disp('All tests passed!');
    msg = 'PASS';
else
    msg = 'FAIL';
end

end

%% test ProtocolLogic.m
%   1. Normal input.
function msg = testProtocolLogic
disp(' ');
disp('Testing ProtocolLogic.m...');
disp('NOTE: currently have only 1 test case.');
pass = true;

%% Test Case 1

dataIn = {{'etl.participant','infant-sibs.infant-sibs-high-risk-2011-12','urc-button-pressing.urc-asd-2014-06'},[2014,8,4],4;
    {'ace-center-2012.CAC-LR-TDX-0-36m-2012-11','ace-center-2012.eye-tracking-0-36m-2012-11','ace-center-2012.vocal-recording-0-36m-2013-07'},[2014,8,4],3;
    {'toddler.toddler-asd-dd-2011-07','voice-quality.EGG-study-0-6Y-2013-09'},[2014,8,1],3;
    {'wash-u.williams-syndrome-2014-08'},[2014,8,1],3;
    {'wash-u.toddler-twin-longitudinal-nontwinsib-2013-06'},[2014,8,4],2};
colNum = 1;

allProtsExpected = {'ace-center-2012.CAC-LR-TDX-0-36m-2012-11',...
                'ace-center-2012.eye-tracking-0-36m-2012-11',...
                'ace-center-2012.vocal-recording-0-36m-2013-07',...
                'etl.participant','infant-sibs.infant-sibs-high-risk-2011-12',...
                'toddler.toddler-asd-dd-2011-07',...
                'urc-button-pressing.urc-asd-2014-06',...
                'voice-quality.EGG-study-0-6Y-2013-09',...
                'wash-u.toddler-twin-longitudinal-nontwinsib-2013-06',...
                'wash-u.williams-syndrome-2014-08'};
protLogicExpected = logical([0, 0, 0, true, true, 0, true, 0, 0, 0;
                            true, true, true, 0, 0, 0, 0, 0, 0, 0;
                            0, 0, 0, 0, 0, true, 0, true, 0, 0;
                            0, 0, 0, 0, 0, 0, 0, 0, 0, true;
                            0, 0, 0, 0, 0, 0, 0, 0, true, 0]);

[allProts,protLogic] = ProtocolLogic(dataIn, colNum);
if ~isequal(allProts,allProtsExpected)
    disp('Test 1 FAIL: allProtocols mismatch');
    pass = false;
end
if ~isequal(protLogic,protLogicExpected)
    disp('Test 1 FAIL: protLogic mismatch');
    pass = false;
end


%%
if pass
    disp('All tests passed!');
    msg = 'PASS';
else
    msg = 'FAIL';
end           
                
end

%% test ReadInQuery.m
%	1: number conversion (ReadInQueryTest1.csv)
%	2: array function (ReadInQueryTest2.csv)
%	3: date conversion (ReadInQueryTest3.csv)
function msg = testReadInQuery
disp(' ');
disp('Testing ReadInQuery.m...');
pass = true;

%% Test 1: number conversion (ReadInQueryTest1.csv)

%create the test file
fileDir = '/Users/etl/Desktop/mric-audits/QueryTools/TestFiles/';
if ~exist(fileDir,'dir')
    mkdir(fileDir)
end
testFile = 'ReadInQueryTest1.csv';

fid = fopen([fileDir,testFile],'w');
fprintf(fid,'Nums,Strings,Mixed\n');
fprintf(fid,'1,a,a\n');
fprintf(fid,'2.1,abc,2\n\n');%NOTE the empty row in the middle
fprintf(fid,'123,1/2,');
fclose(fid);

% What the output should look like:
testFields = {'Nums','Strings','Mixed'};
testData = {1,'a','a';
            2.1,'abc',2;
            [],[],[];
            123,'1/2',[]};

e='';
try [fieldsOut,dataOut] = ReadInQuery([fileDir,testFile]);
catch e
end

if isempty(e)
    if ~isequal(testFields,fieldsOut)
        pass = false;
        disp('Test 1 FAIL: fields did not match.');
    end
    if ~isequal(testData, dataOut)
        pass = false;
        disp('Test 1 FAIL: data did not match.');
    end
else
    pass = false;
    disp('Test 1 FAIL: unexpected error.');
end

%% Test 2: array function (ReadInQueryTest2.csv)

% The file has the following columns:
%   Protocol array (should be read in as a cell)
%   Protocol (the same content, but should be read in as strings)
%   Quality array (should read in a cell w/ numbers)

%create the test file (ReadInQueryTest.csv)
fileDir = '/Users/etl/Desktop/mric-audits/QueryTools/TestFiles/';
testFile = 'ReadInQueryTest2.csv';

fid = fopen([fileDir,testFile],'w'); 
fprintf(fid,'Protocol array,Protocol,Quality array\n');
fprintf(fid,'[a###b###c],[a###b###c],[1###2###3]\n');
fprintf(fid,'a###b###c,a###b###c,1a###2###3\n');
fprintf(fid,'[],[a],[1]\n');
fprintf(fid,',[],[###2]');
fclose(fid);

%What the output should look like:
testFields = {'Protocol',   'Protocol',     'Quality'}; 
testData = {{'a','b','c'},  '[a###b###c]',  {1,2,3};
            {'a','b','c'},  'a###b###c',    {'1a',2,3};
            {},             '[a]',          {1};   
            {},             '[]',           {'',2}};   

e='';
try [fieldsOut,dataOut] = ReadInQuery([fileDir,testFile]);
catch e
end

if isempty(e)
    if ~isequal(testFields,fieldsOut)
        pass = false;
        disp('Test 2 FAIL: fields did not match.');
    end
    if ~isequal(testData, dataOut)
        pass = false;
        disp('Test 2 FAIL: data did not match.');
    end
else
    pass = false;
    disp('Test 2 FAIL: unexpected error.');
end

% %delete the test file
% delete([fileDir,testFile]);

%% Test 3: date conversion (ReadInQueryTest3.csv)

%create the test file 
fileDir = '/Users/etl/Desktop/mric-audits/QueryTools/TestFiles/';
testFile = 'ReadInQueryTest3.csv';

fid = fopen([fileDir,testFile],'w'); 
fprintf(fid,'Pad,Date,Pad\n');
fprintf(fid,',,\n'); %empty date
fprintf(fid,',2014-09-24,\n'); %MRIC format
fprintf(fid,',09/24/2014,\n'); %excel format, 4 digit year
fprintf(fid,',9/24/14,\n'); %excel format, 2 digit year (should produce warning)
fprintf(fid,',invalidString,'); %invalid string (should produce warning)
fclose(fid);

%What the output should look like:
testFields = {'Pad','Date','Pad'}; 
testData = {[] [-1 -1 -1]  [];
            [] [2014,9,24] [];
            [] [2014,9,24] [];   
            [] [2014,9,24] [];
            [] [-1 -1 -1]  []};   

disp('****** 2 warnings should be printed: ******');
e='';
try [fieldsOut,dataOut] = ReadInQuery([fileDir,testFile]);
catch e
end
disp('*******************************************');

if isempty(e)
    if ~isequal(testFields,fieldsOut)
        pass = false;
        disp('Test 3 FAIL: fields did not match.');
    end
    if ~isequal(testData, dataOut)
        pass = false;
        disp('Test 3 FAIL: data did not match.');
    end
else
    pass = false;
    disp('Test 3 FAIL: unexpected error.');
end

% %delete the test file
% delete([fileDir,testFile]);

%%
if pass
    disp('All tests passed!');
    msg = 'PASS';
else
    msg = 'FAIL';
end

end

%% test AuditQuery
%   1. Fewer varargins than %Xs in base query
%   2. More varargins than %Xs in base query
%   3. Check that base query is output properly // Check that error is thrown when results file does not exist
%   4. Make sure that the csv is read in and that outputs are correct
%   5. Make sure that a matfile is saved, and that the variables in the matfile are correct
function msg = testAuditQuery
disp(' ');
disp('Testing AuditQuery.m...');
pass = true;

%% Make testing files
%create folders where test files can be saved:
resultsDir = [pwd,'/TestFiles/'];
baseQueryDir = [resultsDir,'BaseQueries/'];
if ~exist(resultsDir,'dir')
    mkdir(resultsDir)
end
if ~exist(baseQueryDir,'dir')
    mkdir(baseQueryDir)
end

%write out the bad query:
badQuery = 'badQuery.txt'; %will not run properly (3 %Xs)
badQueryName = 'badQuery';
fid = fopen([baseQueryDir,badQuery],'w');
fprintf(fid,'/this{is,%%X,bad,query}?a>%%X & b==%%X'); %the double percents print as 1 (escape character)
fclose(fid);


% TEST CASES
%% 1. fewer varargins than %Xs in base query
clear e; e.identifier = '';
try AuditQuery(resultsDir,[baseQueryDir,badQuery],'1','2')
catch e
end

if ~strcmpi(e.identifier,'QueryTools:badInput');
    disp('Test 1 FAIL: should throw a badInput error if there are fewer varargs than %Xs in the base query');
    pass = false;
end

%% 2. more varargins than %Xs in base query
clear e; e.identifier = '';
try AuditQuery(resultsDir,[baseQueryDir,badQuery],'Protocol array','1','2','3','4');
catch e
end

if ~strcmpi(e.identifier,'QueryTools:badInput');
    disp('Test 2 FAIL: should throw a badInput error if there are more varargs than %Xs in the base query');
    pass = false;
end

%% 3. Check that base query is output properly // Check that error is thrown when results file does not exist
disp('>>>> Enter any characters for username & password <<<<');

badQueryExpected = '/this{is,1,bad,query}?a>2 & b==3';
clear e; e.identifier = '';
try AuditQuery(resultsDir,[baseQueryDir,badQuery],'1','2','3')
catch e
end

%check that the QUERY is a file that can be opened
fid = fopen([resultsDir,badQuery]);
if fid == -1
    pass = false;
    disp('Test 3 FAIL: base query file cannot be opened.');
else
    %Check the contents of base query file
    fileContents = [];
    while true
        nextLine = fgetl(fid);
        if nextLine == -1
            break
        end
        fileContents = [fileContents,nextLine];
    end
    fclose(fid);
    
    if ~isequal(fileContents,badQueryExpected)
        pass = false;
        disp('Test 3 FAIL: base query was not filled in as expected.');
    end
    
    delete([resultsDir,badQuery]); %delete the filled in query
end

%should have thrown an error because the results shouldn't exist
if ~strcmpi(e.identifier,'QueryTools:fileNotFound');
    pass = false;
    disp('Test 3 FAIL: should have thrown a fileNotFound error.');
end

if exist([resultsDir,'Results_',badQueryName,'.csv'],'file');
    disp('Test 3 FAIL: results file should not have been output for the bad query.');
    delete([resultsDir,'Results_',badQueryName,'.csv']);
    pass = false;
end



%% 4. Make sure that a matfile is saved, and that the variables in the matfile are correct

% Write out "fake" results (results exist, base query doesn't.)
fakeQuery = 'fakeQuery.txt'; 
fakeMatFile = [resultsDir,'Results_fakeQuery.mat'];
fakeQueryResults = 'Results_fakeQuery.csv';

%delete base query if the file exists...(just because)
if exist([baseQueryDir,fakeQuery],'file')
   delete([baseQueryDir,fakeQuery]);
end

%write out fake results
fid = fopen([resultsDir,fakeQueryResults],'w');
fprintf(fid,'Protocol array,Date,Quality\n');
fprintf(fid,'[etl.participant###infant-sibs.infant-sibs-high-risk-2011-12###urc-button-pressing.urc-asd-2014-06],8/4/2014,4\n');
fprintf(fid,'[ace-center-2012.CAC-LR-TDX-0-36m-2012-11###ace-center-2012.eye-tracking-0-36m-2012-11###ace-center-2012.vocal-recording-0-36m-2013-07],8/4/2014,3\n');
fprintf(fid,'[toddler.toddler-asd-dd-2011-07###voice-quality.EGG-study-0-6Y-2013-09],8/1/2014,3\n');
fprintf(fid,'[],8/1/2014,3\n'); %TODO - check this...
fprintf(fid,'[wash-u.toddler-twin-longitudinal-nontwinsib-2013-06],8/4/2014,2');
fclose(fid);

%this is what the output should look like...
fakeFields = {'Protocol','Date','Quality'};
fakeData = {{'etl.participant','infant-sibs.infant-sibs-high-risk-2011-12','urc-button-pressing.urc-asd-2014-06'},[2014,8,4],4;
    {'ace-center-2012.CAC-LR-TDX-0-36m-2012-11','ace-center-2012.eye-tracking-0-36m-2012-11','ace-center-2012.vocal-recording-0-36m-2013-07'},[2014,8,4],3;
    {'toddler.toddler-asd-dd-2011-07','voice-quality.EGG-study-0-6Y-2013-09'},[2014,8,1],3;
    {},[2014,8,1],3;
    {'wash-u.toddler-twin-longitudinal-nontwinsib-2013-06'},[2014,8,4],2};

%%%%%%

[fields, data] = AuditQuery(resultsDir,[baseQueryDir,fakeQuery]);

if ~exist(fakeMatFile,'file')
    disp('Test 4 FAIL: Mat file was not saved with results');
    pass = false;
else
    clear fields data
    load(fakeMatFile);
    if ~exist('fields','var') || ~exist('data','var');
        disp('Test 4 FAIL: Mat file does not contain the proper variables');
        pass = false;
    else
        if ~isequal(fields,fakeFields)
            disp('Test 4 FAIL: fields var in matfile is incorrect.');
            pass = false;
        end
        if ~isequal(data,fakeData)
            disp('Test 4 FAIL: data var in matfile is incorrect.');
            pass = false;
        end
    end
    delete(fakeMatFile);
end
    
%%    
if pass
    disp('All tests passed!');
    msg = 'PASS';
else
    msg = 'FAIL';
end

end
