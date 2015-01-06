function SessionAuditGraphs(dirToSave,graphTitle,fields,data,protocols)
%SESSIONAUDITGRAPHS Visualize the results of a session table query of eye
%tracking data from MRIC, written for monthly audits.
%   SessionAuditGraphs(dirToSave,graphTitle,fields,data) creates a series
%       of graphs for all of the rows in DATA.
%   SessionAuditGraphs(dirToSave,graphTitle,fields,data,protocols) filters
%       data by protocols that match those in the cell PROTOCOLS.
%
%INPUTS
%   dirToSave (str) -- where to save the graphs (full path)
%   graphTitle (str) -- added to the beginning of the title of every graph.
%   fields (cell) -- column headers that correspond to the columns of data.
%   data (cell) -- each row corresponds to a row of the database query.
%   protocols (cell) -- applies a filter to the data only
%
%GRAPHS SAVED
%   1a. # Successful sessions VS rounded age
%    b. % Successful sessions VS rounded age
%   2a. # Successful sessions VS time
%    b. % Successful sessions VS time
%   3a. Average # clips seen per session VS time -- Q>=2 (w/ error bars)
%    b. Average # clips seen per session VS binned age -- Q>=2 (w/ error bars)
%    c. Histogram of # clips seen
%
%OTHER NOTES
% > The following column headers (in FIELDS) are necessary:
%       NumberOfClips, Quality, Date, WeekStart, BinnedAge (OR Age)
% > A Protocol column is necessary if protocols input is specified.
% > All column headers are case insensitive. In addition, the age column is
%   only matched for the first 3 characters (e.g. Age(months) is fine).
% > Date bins are determined by the range of the query. If it is less than
%   20 weeks, binned by week. Less than or equal to 2 yrs, binned by month.
%   Anything greater, binned by 3 months.
%
% See also: AUDITQUERY, READINQUERY, RUNAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 1.6.2015

% NOTE ABOUT rotateXLabels -- Set axis limits (XLim, YLim) after xlabels
% have been rotated, or it messes up positioning


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


%% Select only the specified protocols
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

%only make graphs if there is data from the selected protocols
if sum(protSelect) == 0
    return
end

%% Pull data for graphing
%include N in titles
NLABEL = sprintf('(%i sessions)',size(data,1));

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
unqWeekStarts = unqWeekStarts(sum(unqWeekStarts,2)>0,:); % exclude sessions w/ missing dates from graphs
unqWeekStarts = sortrows(unqWeekStarts,[1,2,3]);

%Figure out how many bins:
startWeekDate = datenum(unqWeekStarts(1,1:3));
endWeekDate = datenum(unqWeekStarts(end,1:3));
numWeeks = (endWeekDate - startWeekDate)/7 + 1;

if numWeeks <= 20 %less than 20 weeks of data --> bin by week
    datebins = BinDates(startWeekDate, endWeekDate, 'week');
elseif numWeeks < 104 %more than 20 weeks, less than 2 years --> bin by month
    datebins = BinDates(startWeekDate, endWeekDate, 'month');
else %more than 2 years --> bin by 3 months
    datebins = BinDates(startWeekDate, endWeekDate, '3months');
end

if numWeeks > 20 %if binning by a month, change weekStarts to the first of the month (for the real date)
    dates = cell2mat(data(:,dateCol));
    for a = 1:size(weekStarts,1);
        weekStarts(a,:) = [dates(a,1),dates(a,2),1];
    end
end

%date labels for the graphs
numDateLabels = size(datebins,1);
dateLabels = cell(numDateLabels,2); %xtick location + labels for graphing.
for a = 1:numDateLabels
    dateLabels(a,:) = {a,datestr([datebins(a,:),0,0,0],'mmm dd, yyyy')};
end

%% GRAPHS
origDir=pwd;
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

if size(graph,1)>1 %need at least 2 x-points to create a stacked graph (TODO - workaround?)
    figure();
    axes1=axes('XTick',graph(:,1),'XTickLabel',graph(:,1));
    hold(axes1,'all');
    bar1=bar(axes1,graph(:,1),[graph(:,2),graph(:,3)-graph(:,2)],'BarLayout','stacked');
    set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
    legend('Successful (Q>=3)','Unsuccessful (Q<3)');
    xlabel('Age (months)','FontSize',13);
    ylabel('# Sessions','FontSize',13);
    title({[graphTitle,' ',NLABEL]; 'Successful/Unsuccessful Sessions by Age'},'FontSize',15);
    
    saveas(axes1,['01a_#Success_BinAge- ',graphTitle,'.fig']);
    saveas(axes1,['01a_#Success_BinAge- ',graphTitle,'.eps']);
end

% #1b PERCENT SUCCESSFUL
figure();
axes1=axes('XTick',graph(:,1),'XTickLabel',graph(:,1),'YLim',[0,1]);
hold(axes1,'all');
bar(axes1,graph(:,1),graph(:,2)./graph(:,3));
xlabel('Age (months)','FontSize',13);
ylabel('% Successful Sessions','FontSize',13);
title({[graphTitle,' ',NLABEL]; '% Successful Sessions (Q>=3) by Age'},'FontSize',15);

saveas(axes1,['01b_%Success_BinAge- ',graphTitle,'.fig']);
saveas(axes1,['01b_%Success_BinAge- ',graphTitle,'.eps']);


%% #2 Success VS time

% #2a NUMBER SUCCESSFUL/UNSUCCESSFUL
%(assume that if quality is missing, it was unsuccessful)
graph=zeros(size(datebins,1),2); %#successful, n

for ii = 1:size(datebins,1)
    graph(ii,1)=sum(qualities>=3&weekStarts(:,1)==datebins(ii,1)&...
        weekStarts(:,2)==datebins(ii,2)&weekStarts(:,3)==datebins(ii,3));
    graph(ii,2)=sum(weekStarts(:,1)==datebins(ii,1)&...
        weekStarts(:,2)==datebins(ii,2)&weekStarts(:,3)==datebins(ii,3));
end


if size(graph,1)>1 %need at least 2 x-points to create a stacked graph (TODO - workaround?)
    figure();
    axes2=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2));
    hold(axes2,'all');
    rotateXLabels(gca(),30);
    set(axes2,'XLim',[0,size(datebins,1)+1]);
    bar1=bar(axes2,1:size(datebins,1),[graph(:,1),graph(:,2)-graph(:,1)],'BarLayout','stacked');
    set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
    legend('Successful (Q>=3)','Unsuccessful (Q<3)');
    ylabel('# Sessions','FontSize',13);
    title({[graphTitle,' ',NLABEL]; 'Successful/Unsuccessful Sessions'}, 'FontSize',15);
    
    saveas(axes2,['02a_#Success_Time- ',graphTitle,'.fig']);
    saveas(axes2,['02a_#Success_Time- ',graphTitle,'.eps']);
end

% #2b PERCENT SUCCESSFUL
figure();
axes2=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(datebins,1)+1]);
rotateXLabels(gca(),30);
set(axes2,'YLim',[0,1]);
hold(axes2,'all');
bar(axes2,1:size(datebins,1),graph(:,1)./graph(:,2));
ylabel('% Successful Sessions','FontSize',13);
title({[graphTitle,' ',NLABEL]; '% Successful Sessions (Q>=3)'}, 'FontSize',15);

saveas(axes2,['02b_%Success_Time- ',graphTitle,'.fig']);
saveas(axes2,['02b_%Success_Time- ',graphTitle,'.eps']);


%% #3a	Average # clips seen per session VS time -- Q>=2 (w/ error bars)

graph=[];
for ii=1:size(datebins,1)
    clipsSeenVec=numClips(qualities>=2 & numClips>=0 & ...
        weekStarts(:,1)==datebins(ii,1) & ...
        weekStarts(:,2)==datebins(ii,2) & ...
        weekStarts(:,3)==datebins(ii,3));
    avgClipsSeen=mean(clipsSeenVec);
    n=length(clipsSeenVec);
    stdErr=std(clipsSeenVec)/sqrt(n);
    graph=[graph;avgClipsSeen,stdErr,n];
end

figure();
axes3a=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(datebins,1)+1]);
rotateXLabels(gca(),30);
hold(axes3a,'all');
bar(axes3a,1:size(graph,1),graph(:,1),'FaceColor','w');
errorbar(axes3a,1:size(graph,1),graph(:,1),graph(:,2),'k.');
ylabel('# Clips Seen','FontSize',13);
title({[graphTitle,' ',NLABEL]; 'Average Clips Seen/Session (Q>=2)'},'FontSize',15);

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
title({[graphTitle,' ',NLABEL]; 'Average # Clips Seen/Session vs Binned Age (Q>=2)'},'FontSize',15);

saveas(axes3b,['03b_ClipsPerSess_BinAge- ',graphTitle,'.fig']);
saveas(axes3b,['03b_ClipsPerSess_BinAge- ',graphTitle,'.eps']);

%% #3c Histogram of # clips seen

figure();
nbins=10;
hist(numClips(qualities>=2 & numClips>=0),nbins);
hold on
xlabel('# Clips Seen','FontSize',13);
ylabel('# Sessions','FontSize',13);
title({[graphTitle,' ',NLABEL]; 'Histogram - # Clips Seen/Session (Q>=2)'},'FontSize',15);

saveas(gca,['03c_HistClipsPerSess- ',graphTitle,'.fig']);
saveas(gca,['03c_HistClipsPerSess- ',graphTitle,'.eps']);

%%%%%%%%%%%%%%%%

%% Clean up graph files
%move all the .fig files to a subfolder
if ~exist('figs','dir')
    mkdir('figs');
end
movefile('*.fig','figs/');

disp(' ')
fprintf(['Session graphs saved in\n\t',dirToSave,'\n']);

%% Print quality summary table to a csv file
qualTable(weekStarts,qualities,'QualitySummary.csv');

%% 
cd(origDir)