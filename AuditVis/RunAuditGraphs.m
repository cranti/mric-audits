function RunAuditGraphs(dirToSave,graphTitle,fields,data,protocols)
%RUNAUDITGRAPHS Visualize the results of a run table query of MRIC data,
%written for monthly audits.
%   RunAuditGraphs(dirToSave,graphTitle,fields,data) creates a series of
%       graphs for all of the rows in DATA.
%   RunAuditGraphs(dirToSave,graphTitle,fields,data,protocols) filters data
%       by protocols that match those in the cell PROTOCOLS.
%
%INPUTS
%   dirToSave (str) -- where to save the graphs (full path)
%   graphTitle (str) -- added to the beginning of the title of every graph.
%   fields (cell) -- column headers that correspond to the columns of data.
%   data (cell) -- each row corresponds to a row of the database query.
%   protocols (cell) -- applies a filter to the data only
%
%GRAPHS SAVED (numbering continued from SESSIONAUDITGRAPHS.M)
%    4a Average viewing time/session VS time -- w/ error bars
%     b Histogram of viewing time
%    5  Number of sessions/clip ID (stacked bars: included vs excluded)
%    6  % Fixation VS clip ID (only included clips)
%    7  % Fixation VS binned age (only included clips)
%    8  Histogram of % fixation (only included clips)
%
%OTHER NOTES
% >The following column headers (in FIELDS) are necessary:
%     SessionID, Clip, SampleCount, FixCount, LostCount, Status,
%     WeekStart (OR Date), BinnedAge (OR Age)
% > A Protocol column is necessary if protocols input is specified.
% > All column headers are case insensitive. In addition, the age column is
%   only matched for the first 3 characters (e.g. Age(months) is fine).
% > Date bins are determined by the range of the query. If it is less than
%   20 weeks, binned by week. Less than or equal to 2 yrs, binned by month.
%   Anything greater, binned by 3 months.
%
%
% See also: AUDITQUERY, READINQUERY, SESSIONAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 1.6.2015

% NOTE ABOUT rotateXLabels -- Set axis limits (XLim, YLim) after xlabels
% have been rotated, or it messes up positioning


%% Error checking

assert(logical(exist(dirToSave,'dir')),...
    ['Error in RunAuditGraphs: cannot find dir where graphs should be saved:\n\t' dirToSave]);
assert(size(data,2)==size(fields,2),'Error in RunAuditGraphs: DATA and FIELDS must have the same number of columns.');

% Necessary columns:
dateCol = strcmpi('Date',fields);
sessionIDCol=strcmpi('SessionID',fields);
clipIDCol = strcmpi('Clip',fields);
sampleCol=strcmpi('SampleCount',fields);
fixCol=strcmpi('FixCount',fields);
lostCol = strcmpi('LostCount',fields);
statusCol = strcmpi('Status',fields);
binAgeCol = strncmpi('BinnedAge',fields,3);
weekStartCol=strcmpi('WeekStart',fields);

%%Process data further if BinnedAge or WeekStart are missing
if sum(binAgeCol)==0
    ageCol = strncmpi('Age',fields,3);
    [fields,data] = AddBinnedAge(fields,data,ageCol);
    binAgeCol = strcmpi('BinnedAge',fields);
    assert(sum(binAgeCol)==1,'Error in RunAuditGraphs: there must be either a "BinnedAge" or an "Age" column in FIELDS');
end
if sum(weekStartCol)==0
    [fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
    weekStartCol = strcmpi('WeekStart',fields);
end

assert(sum(dateCol)==1,'Error in RunAuditGraphs: there must be exactly one "Date" column in FIELDS');
assert(sum(sessionIDCol)==1,'Error in RunAuditGraphs: there must be exactly one "SessionID" column in FIELDS');
assert(sum(clipIDCol)==1,'Error in RunAuditGraphs: there must be exactly one "Clip" column in FIELDS');
assert(sum(sampleCol)==1,'Error in RunAuditGraphs: there must be exactly one "SampleCount" column in FIELDS');
assert(sum(fixCol)==1,'Error in RunAuditGraphs: there must be exactly one "FixCount" column in FIELDS');
assert(sum(lostCol)==1,'Error in RunAuditGraphs: there must be exactly one "LostCount" column in FIELDS');
assert(sum(statusCol)==1,'Error in RunAuditGraphs: there must be exactly one "Status" column in FIELDS');
assert(sum(binAgeCol)==1,'Error in RunAuditGraphs: there must be exactly one "BinnedAge" column in FIELDS');
assert(sum(weekStartCol)==1,'Error in RunAuditGraphs: there must be exactly one "WeekStart" column in FIELDS');


%% Select only the specified protocols
if ~isempty(protocols)
    colNum=find(cellfun(@(x) ~isempty(strfind(x,'Protocol')),fields));
    assert(length(colNum)==1,'Error in RunAuditGraphs: there must be exactly one "Protocol" column in FIELDS');
    
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
%Unique sessions
sessionIDsALL = data(:,sessionIDCol);
unqSessionIDs = unique(sessionIDsALL);

%include N in titles
NLABEL = sprintf('(%i sessions)',length(unqSessionIDs));

%Clip IDs
clipIDsALL = cell2mat(data(:,clipIDCol));
unqClipIDs = unique(clipIDsALL);
unqClipIDs = unqClipIDs(unqClipIDs~=9999); % exclude 9999DEMO

%Include/exclude
statusALL = data(:,statusCol);

%Binned Ages
binAgesALL = cell2mat(data(:,binAgeCol));
unqBinAges = unique(binAgesALL);
unqBinAges = unqBinAges(unqBinAges>0); %exclude unknown ages from graphs

%Sample count
sampleCountsALL=cell2mat(data(:,sampleCol));

% Fix count
fixCountsALL=cell2mat(data(:,fixCol));

%%DATES/LABELS
weekStartsALL = cell2mat(data(:,weekStartCol));
%sort unique "week starts"
unqWeekStarts = unique(weekStartsALL,'rows');
unqWeekStarts = unqWeekStarts(sum(unqWeekStarts,2)>0,:); %remove missing dates
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
    for a = 1:size(weekStartsALL,1);
        weekStartsALL(a,:) = [dates(a,1),dates(a,2),1];
    end
end

%date labels for the graphs
numDateLabels = size(datebins,1);
dateLabels = cell(numDateLabels,2); %xtick location + labels for graphing.
for a = 1:numDateLabels
    dateLabels(a,:) = {a,datestr([datebins(a,:),0,0,0],'mmm dd, yyyy')};
end

% Vectors for each variable corresponding to unique session IDs
weekStarts = zeros(size(unqSessionIDs,1),3);
binAges = zeros(size(unqSessionIDs));
sampleCounts = zeros(size(unqSessionIDs));
fixCounts = zeros(size(unqSessionIDs));
for ii = 1:length(unqSessionIDs)
    ind = find(strcmpi(unqSessionIDs{ii},sessionIDsALL));
    ind = ind(1); %first occurrence of the session ID
    
    weekStarts(ii,:) = weekStartsALL(ind,:);
    binAges(ii) = binAgesALL(ind);
    
    sampleCounts(ii) = sum(cell2mat(data(strcmpi(sessionIDsALL,unqSessionIDs(ii)),sampleCol)));
    fixCounts(ii) = sum(cell2mat(data(strcmpi(sessionIDsALL,unqSessionIDs(ii)),fixCol)));
end

%% GRAPHS %%
origDir=pwd;
cd(dirToSave)

%% #4a Average viewing time/session VS time -- w/ error bars

graph=[];
allViewTimes=[];
for ii = 1:size(datebins,1)
    viewTime=sampleCounts(weekStarts(:,1)==datebins(ii,1) &...
        weekStarts(:,2)==datebins(ii,2) & weekStarts(:,3)==datebins(ii,3))/(30*60);
    n=length(viewTime);
    stderr=std(viewTime)/sqrt(n);
    graph=[graph;mean(viewTime),stderr,n];
    allViewTimes = [allViewTimes;viewTime];
end

figure();
axes4a=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2));
rotateXLabels(gca(),30);
hold(axes4a,'all');
bar(axes4a,1:size(datebins,1),graph(:,1),'w');
errorbar(1:size(datebins,1),graph(:,1),graph(:,2),'.');
ylabel('Viewing Time (min)','FontSize',13);
title({[graphTitle,' ',NLABEL]; 'Mean Viewing Time'},'FontSize',15);

saveas(axes4a,['04a_MeanViewTime_Week- ',graphTitle,'.fig']);
saveas(axes4a,['04a_MeanViewTime_Week- ',graphTitle,'.eps']);

%% #4b Histogram of viewing time

figure();
nbins=10;
hist(allViewTimes,nbins);
hold on
xlabel('Viewing Time (min)','FontSize',13);
ylabel('Number of Sessions','FontSize',13);
title({[graphTitle,' ',NLABEL]; 'Histogram - Viewing Time'},'FontSize',15);

saveas(gcf,['04b_HistViewTime- ',graphTitle,'.fig']);
saveas(gcf,['04b_HistViewTime- ',graphTitle,'.eps']);

%% #5 Number of sessions/clip ID (stacked bars: included vs excluded)

graph=[];
for ii = 1:length(unqClipIDs)
    graph(ii,1) = sum(clipIDsALL==unqClipIDs(ii)&strcmpi('include',statusALL));
    graph(ii,2) = sum(clipIDsALL==unqClipIDs(ii)&strcmpi('exclude',statusALL));
end


if size(graph,1)>1 %need at least 2 x-points to create a stacked graph (TODO - workaround?)
    figure()
    axes5=axes('XTick',1:length(unqClipIDs),'XTickLabel',unqClipIDs,'XLim',[0,length(unqClipIDs)+1]);
    hold(axes5,'all');
    bar5=bar(axes5,1:length(unqClipIDs),[graph(:,1),graph(:,2)],'BarLayout','stacked');
    set(bar5(2),'FaceColor',[0.83 0.81 0.78]);
    set(gcf,'Position',[10, 550, 1800, 420],'PaperPositionMode','auto') %resize. PaperPositionMode prevents resizing when saving
    legend('Include','Exclude');
    xlabel('Clip ID','FontSize',13);
    ylabel('Number of Sessions','FontSize',13);
    title({[graphTitle,' ',NLABEL]; 'Included/Excluded Sessions per Clip'},'FontSize',15);
    
    saveas(axes5,['05_Sessions_Clip- ',graphTitle,'.fig']);
    saveas(axes5,['05_Sessions_Clip- ',graphTitle,'.eps']);
end

%% #6 	% Fixation VS clip ID (included clips)

graph=[];
for ii = 1:length(unqClipIDs)
    clipAllPerFix = fixCountsALL(clipIDsALL==unqClipIDs(ii)&strcmpi('include',statusALL))...
        ./sampleCountsALL(clipIDsALL==unqClipIDs(ii)&strcmpi('include',statusALL));
    avgPerFix = mean(clipAllPerFix);
    n = length(clipAllPerFix);
    stdErr = std(clipAllPerFix)/sqrt(n);
    graph(ii,:) = [avgPerFix,stdErr,n];
end

figure()
axes6 = axes('XTick',1:length(unqClipIDs),'XTickLabel',unqClipIDs,'XLim',[0,length(unqClipIDs)+1]);
hold(axes6,'all');
bar(axes6,1:length(unqClipIDs),graph(:,1));
errorbar(axes6,1:length(unqClipIDs),graph(:,1),graph(:,2),'k.');
xlabel('Clip','FontSize',13);
ylabel('% Fixation','FontSize',13);
set(gcf,'Position',[10, 550, 1800, 420],'PaperPositionMode','auto') %resize. PaperPositionMode prevents resizing when saving
title({[graphTitle,' ',NLABEL]; '% Fixation per Clip (included clips)'},'FontSize',15);

saveas(axes6,['06_PerFix_Clip- ',graphTitle,'.fig']);
saveas(axes6,['06_PerFix_Clip- ',graphTitle,'.eps']);


%% #7 % Fixation VS binned age (included clips)

graph=[];
for ii = 1:length(unqBinAges)
    ageAllPerFix = fixCountsALL(binAgesALL==unqBinAges(ii) & strcmpi('include',statusALL))...
        ./sampleCountsALL(binAgesALL==unqBinAges(ii) & strcmpi('include',statusALL));
    avgPerFix = mean(ageAllPerFix);
    n = length(ageAllPerFix);
    stdErr = std(ageAllPerFix)/sqrt(n);
    graph(ii,:) = [avgPerFix,stdErr,n];
end

figure()
axes7=axes('XTick',unqBinAges,'YLim',[0,1]);
hold(axes7,'all');
bar(axes7,unqBinAges,graph(:,1));
errorbar(axes7,unqBinAges,graph(:,1),graph(:,2),'k.');
xlabel('Binned Age (months)','FontSize',13);
ylabel('% Fixation','FontSize',13);
title({[graphTitle,' ',NLABEL]; '% Fixation vs Age (included clips)'},'FontSize',15);

saveas(axes7,['07_PerFix_Age- ',graphTitle,'.fig']);
saveas(axes7,['07_PerFix_Age- ',graphTitle,'.eps']);

%% #8 Histogram of % fixation (included clips)

allPerFix=fixCountsALL(strcmpi('include',statusALL))./sampleCountsALL(strcmpi('include',statusALL));

figure()
binInc=.1;
datebins=[0:binInc:1]+binInc/2;
hist(allPerFix,datebins);
hold on
set(gca,'XLim',[0,1]);
xlabel('% Fixation','FontSize',13);
ylabel('# Clips','FontSize',13);
title({[graphTitle,' ',NLABEL]; 'Histogram - % Fixation (included clips)'},'FontSize',15);

saveas(gca,['08_HistClipsPerSess- ',graphTitle,'.fig']);
saveas(gca,['08_HistClipsPerSess- ',graphTitle,'.eps']);

%%%%%%%%%%%%%%%%

%% Clean up graph files
%move all the .fig files to a subfolder
if ~exist('figs','dir')
    mkdir('figs');
end
movefile('*.fig','figs/');

disp(' ')
fprintf(['Run graphs saved in\n\t',dirToSave,'\n']);

%%
cd(origDir)
