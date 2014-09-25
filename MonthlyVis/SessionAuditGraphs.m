function SessionAuditGraphs(dirToSave,graphTitle,fields,data,protocols)
%SESSIONAUDITGRAPHS Visualize the results of a session table query of eye
%tracking data from MRIC, written for monthly audits.
%   SessionAuditGraphs(dirToSave,graphTitle,fields,data) creates a series
%   of graphs for all of the rows in data.
%   SessionAuditGraphs(dirToSave,graphTitle,fields,data,protocols) filters
%   data by protocols that match those in protocols
%
%INPUTS
%   dirToSave (str) -- where to save the graphs (full path)
%   graphTitle (str) -- added to the beginning of the title of every graph.
%   fields (cell) -- column headers that correspond to the columns of data.
%   data (cell) -- each row corresponds to a row of the database query.
%   protocols (cell) -- applies a filter to the data only
%   
%GRAPHS
%   1a. # Successful sessions VS rounded age
%    b. % Successful sessions VS rounded age
%   2a. # Successful sessions VS time
%    b. % Successful sessions VS time
%   3a. Average # clips seen per session VS time -- Q>=2 (w/ error bars)
%    b. Average # clips seen per session VS binned age -- Q>=2 (w/ error bars)
%    c. Histogram of # clips seen
%
%OTHER NOTES
% > The following column headers are necessary for the script to run:
%       NumberOfClips, Quality, Date, WeekStart, BinnedAge (OR Age)
% > A Protocol column is necessary if protocols input is specified.
% > All column headers are case insensitive. In addition, the age column is
%   only matched for the first 3 characters (e.g. Age(months) is fine).
% > Date bins are determined by the range of the query. If it is less than
%   20 weeks, binned by week. Less than or equal to 2 yrs, binned by month.
%   Anything greater, binned by 3 months.
%
%
% See also: AUDITQUERY, READINQUERY, RUNAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 9.9.2014

% NOTE ABOUT rotateXLabels -- Set YLim after xlabels have been rotated, or
% it messes up positioning (for some reason)


%% Error checking

assert(logical(exist(dirToSave,'dir')),...
    ['Error in SessionAuditGraphs: cannot find dir where graphs should be saved:\n\t' dirToSave]);
assert(size(data,2)==size(fields,2),'Error in SessionAuditGraphs: DATA and FIELDS must have the same number of columns.');

% Necessary columns:
dateCol = strcmpi('Date',fields);
numClipsCol=strcmpi('NumberOfClips',fields);
qualCol = strcmpi('Quality',fields);
binAgeCol = strcmpi('BinnedAge',fields);
weekStartCol = strcmpi('WeekStart',fields);

%%Process data further if BinnedAge or WeekStart are missing
if sum(binAgeCol)==0
   ageCol = strncmpi('Age',fields,3);
   [fields,data] = AddBinnedAge(fields,data,ageCol);
   binAgeCol = strcmpi('BinnedAge',fields);
   assert(sum(binAgeCol)==1,'Error in SessionAuditGraphs: there must be either a "BinnedAge" or an "Age" column in FIELDS');
end
if sum(weekStartCol)==0
    [fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
    weekStartCol = strcmpi('WeekStart',fields);
end

assert(sum(dateCol)==1,'Error in SessionAuditGraphs: there must be exactly one "Date" column in FIELDS');
assert(sum(numClipsCol)==1,'Error in SessionAuditGraphs: there must be exactly one "NumberOfClips" column in FIELDS');
assert(sum(qualCol)==1,'Error in SessionAuditGraphs: there must be exactly one "Quality" column in FIELDS');
assert(sum(binAgeCol)==1,'Error in SessionAuditGraphs: there must be exactly one "BinnedAge" column in FIELDS');
assert(sum(weekStartCol)==1,'Error in SessionAuditGraphs: there must be exactly one "WeekStart" column in FIELDS');


%% Pull data for graphing

%Select only the specified protocols
if ~isempty(protocols)
    colNum=find(cellfun(@(x) ~isempty(strfind(x,'Protocol')),fields));
    assert(length(colNum)==1,'Error in SessionAuditGraphs: there must be exactly one "Protocol" column in fields');

    [allProtocols,allProtLogic] = ProtocolLogic(data,colNum);
    
    if ~iscell(protocols)
        protocols={protocols};
    end
    
    protSelect=zeros(size(allProtLogic,1),1);
    for ii=1:length(protocols)
        protSelect=protSelect|sum(allProtLogic(:,cellfun(@(x) ~isempty(strfind(x,protocols{ii})),allProtocols)),2);
    end
    data=data(protSelect,:);
end

%Binned Ages
binAges = cell2mat(data(:,binAgeCol));
unqBinAges = unique(binAges);
unqBinAges = unqBinAges(unqBinAges>0); %exclude unknown ages from graphs

%# of clips seen per session
numClips = data(:,numClipsCol);
numClips(cellfun(@isempty,numClips)) = {-1}; %flag empty cells w/ -1
numClips = cell2mat(numClips);

%Quality
qualities=data(:,qualCol);
qualities(cellfun(@isempty,qualities))={-1}; %flag empty cells w/ -1
qualities=cell2mat(qualities);


%%DATES/LABELS
%unique "week starts"
weekStarts = cell2mat(data(:,weekStartCol));
unqWeekStarts = unique(weekStarts,'rows');
unqWeekStarts = unqWeekStarts(sum(unqWeekStarts,2)>0,:); % exclude missing dates from graphs
unqWeekStarts = sortrows(unqWeekStarts,[1,2,3]);

%Actual date range
dates = cell2mat(data(:,dateCol));
sortedDates = sortrows(dates(sum(dates,2)>0,:));
startDate = datenum(sortedDates(1,:));
endDate = datenum(sortedDates(end,:));

%Figure out how many bins:
startWeekDate = datenum(unqWeekStarts(1,1),unqWeekStarts(1,2),unqWeekStarts(1,3));
endWeekDate = datenum(unqWeekStarts(end,1),unqWeekStarts(end,2),unqWeekStarts(end,3));
numWeeks = floor((endWeekDate - startWeekDate)/7);

if numWeeks <= 20 %less than 20 weeks of data --> bin by week
    dateBins = [];
    currDate = startWeekDate;
    while currDate <= endDate
        temp = datevec(currDate);
        dateBins = [dateBins; temp(1:3)];
        currDate = currDate + 7;
    end
elseif numWeeks < 104 %more than 20 weeks, less than 2 years --> bin by month

    dateBins = [];
    if year(startDate) == year(endDate)
        YEAR = year(startDate);
        for MONTH = month(startDate):month(endDate)
           dateBins = [dateBins; YEAR, MONTH, 1]; 
        end
    else
        YEAR = year(startDate);
        for MONTH = month(startDate):12
            dateBins = [dateBins; YEAR, MONTH, 1];
        end
        YEAR = year(endDate);
        for MONTH = 1:month(endDate)
            dateBins = [dateBins; YEAR, MONTH, 1];
        end
    end
    
    %Iterate through weekStarts and change to the first of the month
    for a = 1:size(weekStarts,1);
        weekStarts(a,:) = [dates(a,1),dates(a,2),1];
    end
else %more than 2 years of data --> bin by 3 months
    MONTH = month(startDate);
    YEAR = year(startDate);
    dateBins = [];
    while YEAR <= year(endDate)
        %make sure MONTH is in the right range; iterate year if needed
        if MONTH > 12 
            MONTH = mod(MONTH-1,12)+1;
            YEAR = YEAR + 1;
        end
        
        %break if out of the date range
        if (YEAR == year(endDate) && MONTH > month(endDate))
           break 
        end
        
        %add to tempLabels, iterate month
        dateBins = [dateBins; YEAR, MONTH, 1];
        MONTH = MONTH + 3;
    end
            
    %Iterate through weekStarts and change to the first of the month
    for a = 1:size(weekStarts,1);
        weekStarts(a,:) = [dates(a,1),dates(a,2),1];
    end 
end

numDateLabels = size(dateBins,1);
dateLabels = cell(numDateLabels,2); %xtick location + labels for graphing. 
for a = 1:numDateLabels
    dateLabels(a,:) = {a,datestr([dateBins(a,:),0,0,0],'mmm dd, yyyy')};
end

%% GRAPHS
origDir=pwd;
% addpath(origDir); TODO - is this necessary?
cd(dirToSave)

%% #1 Success rate VS binned age

% #1a NUMBER SUCCESSFUL
graph=[];
graph(:,1)=unqBinAges;
graph(:,2)=zeros(size(graph,1),1);
graph(:,3)=zeros(size(graph,1),1);

for ii=1:size(graph,1)
    numSuccess=sum(binAges==graph(ii,1)&qualities>=3); %# successful sessions
    n=sum(binAges==graph(ii,1)); %n
    graph(ii,2:3)=[numSuccess,n];
end

figure();
axes1=axes('XTick',graph(:,1),'XTickLabel',graph(:,1));
hold(axes1,'all');
bar1=bar(axes1,graph(:,1),[graph(:,2),graph(:,3)-graph(:,2)],'BarLayout','stacked');
set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
legend('Successful (Q>=3)','Unsuccessful (Q<3)');
xlabel('Age (months)','FontSize',13);
ylabel('# Sessions','FontSize',13);
title([graphTitle,': Successful/Unsuccessful Sessions by Age'],'FontSize',15);

saveas(axes1,['01a_#Success_BinAge- ',graphTitle,'.fig']);
saveas(axes1,['01a_#Success_BinAge- ',graphTitle,'.eps']);

% #1b PERCENT SUCCESSFUL
figure();
axes1=axes('XTick',graph(:,1),'XTickLabel',graph(:,1),'YLim',[0,1]);
hold(axes1,'all');
bar(axes1,graph(:,1),graph(:,2)./graph(:,3));
xlabel('Age (months)','FontSize',13);
ylabel('% Successful Sessions','FontSize',13);
title([graphTitle,': % Successful Sessions (Q>=3) by Age'],'FontSize',15);

saveas(axes1,['01b_%Success_BinAge- ',graphTitle,'.fig']);
saveas(axes1,['01b_%Success_BinAge- ',graphTitle,'.eps']);



%% #2 Success VS time

% #2a NUMBER SUCCESSFUL/UNSUCCESSFUL 
%(assume that if quality is missing, it was unsuccessful)
graph=[];
graph(:,1)=zeros(size(graph,1),1); %# successful
graph(:,2)=zeros(size(graph,1),1); %n

for ii = 1:size(dateBins,1)
    graph(ii,1)=sum(qualities>=3&weekStarts(:,1)==dateBins(ii,1)&...
        weekStarts(:,2)==dateBins(ii,2)&weekStarts(:,3)==dateBins(ii,3));
    graph(ii,2)=sum(weekStarts(:,1)==dateBins(ii,1)&...
        weekStarts(:,2)==dateBins(ii,2)&weekStarts(:,3)==dateBins(ii,3));
end

figure();
axes2=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(dateBins,1)+1]);
rotateXLabels(gca(),30);
hold(axes2,'all');
bar1=bar(axes2,1:size(dateBins,1),[graph(:,1),graph(:,2)-graph(:,1)],'BarLayout','stacked');
set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
legend('Successful (Q>=3)','Unsuccessful (Q<3)');
ylabel('# Sessions','FontSize',13);
title([graphTitle,': Successful/Unsuccessful Sessions'],'FontSize',15);

saveas(axes2,['02a_#Success_Time- ',graphTitle,'.fig']);
saveas(axes2,['02a_#Success_Time- ',graphTitle,'.eps']);


% #2b PERCENT SUCCESSFUL
figure();
axes2=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(dateBins,1)+1]);
rotateXLabels(gca(),30);
set(axes2,'YLim',[0,1]);
hold(axes2,'all');
bar(axes2,1:size(dateBins,1),graph(:,1)./graph(:,2));
ylabel('% Successful Sessions','FontSize',13);
title([graphTitle,': % Successful Sessions (Q>=3)'],'FontSize',15);

saveas(axes2,['02b_%Success_Time- ',graphTitle,'.fig']);
saveas(axes2,['02b_%Success_Time- ',graphTitle,'.eps']);
     

%% #3a	Average # clips seen per session VS time -- Q>=2 (w/ error bars)

graph=[];
for ii=1:size(dateBins,1)
    clipsSeenVec=numClips(qualities>=2 & numClips>=0 & ...
        weekStarts(:,1)==dateBins(ii,1) & ...
        weekStarts(:,2)==dateBins(ii,2) & ... 
        weekStarts(:,3)==dateBins(ii,3));
    avgClipsSeen=mean(clipsSeenVec);
    n=length(clipsSeenVec);
    stdErr=std(clipsSeenVec)/sqrt(n);
    graph=[graph;avgClipsSeen,stdErr,n];
end

figure();
axes3a=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(dateBins,1)+1]);
rotateXLabels(gca(),30);
hold(axes3a,'all');
bar(axes3a,1:size(graph,1),graph(:,1),'FaceColor','w');
errorbar(axes3a,1:size(graph,1),graph(:,1),graph(:,2),'k.');
ylabel('# Clips Seen','FontSize',13);
title([graphTitle,': Average Clips Seen/Session (Q>=2)'],'FontSize',15);

saveas(axes3a,['03a_ClipsPerSess_Time- ',graphTitle,'.fig']);
saveas(axes3a,['03a_ClipsPerSess_Time- ',graphTitle,'.eps']);

%% #3b Average # clips seen per session VS binned age -- Q>=2 (w/ error bars) 

graph=[];
for ii=1:length(unqBinAges)
    clipsSeenVec=numClips(binAges==unqBinAges(ii) & qualities>=2 & numClips>=0);
    avgClipsSeen=mean(clipsSeenVec);
    n=length(clipsSeenVec);
    stdErr=std(clipsSeenVec)/sqrt(n);
    %store age, sum, and number of data points in matrix
    graph=[graph;avgClipsSeen,stdErr,n];
end

figure();
axes3b=axes('XTick',unqBinAges,'XTickLabel',unqBinAges);
hold(axes3b,'all');
bar(axes3b,unqBinAges,graph(:,1),'FaceColor','w');
errorbar(axes3b,unqBinAges,graph(:,1),graph(:,2),'k.');
xlabel('Binned Age (months)','FontSize',13);
ylabel('# Clips Seen','FontSize',13);
title([graphTitle,': Average # Clips Seen/Session vs Binned Age (Q>=2)'],'FontSize',15);

saveas(axes3b,['03b_ClipsPerSess_BinAge- ',graphTitle,'.fig']);
saveas(axes3b,['03b_ClipsPerSess_BinAge- ',graphTitle,'.eps']);

%% #3c Histogram of # clips seen

figure();
nbins=10;
hist(numClips(qualities>=2 & numClips>=0),nbins);
hold on
xlabel('# Clips Seen','FontSize',13);
ylabel('# Sessions','FontSize',13);
title([graphTitle,': Histogram - # Clips Seen/Session (Q>=2)'],'FontSize',15);

saveas(gca,['03c_HistClipsPerSess- ',graphTitle,'.fig']);
saveas(gca,['03c_HistClipsPerSess- ',graphTitle,'.eps']);

%%%%%%%%%%%%%%%%

%% Clean up
%move all the .fig files to a subfolder
if ~exist('figs','dir')
    mkdir('figs');
end
movefile('*.fig','figs/');

%close all
disp(' ')
fprintf(['Session graphs saved in\n\t',dirToSave,'\n']);

cd(origDir)