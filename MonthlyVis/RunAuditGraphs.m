function RunAuditGraphs(dirToSave,graphTitle,fields,data,protocols)
%RUNAUDITGRAPHS Visualize the results of a run table query of MRIC data, 
%written for monthly audits.
%   RunAuditGraphs(dirToSave,graphTitle,fields,data) creates a series of graphs for
%   all of the rows in data.
%   RunAuditGraphs(dirToSave,graphTitle,fields,data,protocols) filters data by
%   protocols that match those in the cell, protocols
%
%INPUTS
%   dirToSave (str) -- where to save the graphs (full path)
%   graphTitle (str) -- added to the beginning of the title of every graph.
%   fields (cell) -- column headers that correspond to the columns of data.
%   data (cell) -- each row corresponds to a row of the database query.
%   protocols (cell) -- applies a filter to the data only
%   
%GRAPHS (numbering continued from SESSIONAUDITGRAPHS)
%    4a Average viewing time/session VS time -- w/ error bars
%     b Histogram of viewing time
%    5  Number of sessions/clip ID (stacked bars: included vs excluded)
%    6  % Fixation VS clip ID (only included clips)
%    7  % Fixation VS binned age (included AND excluded clips -- ask WJ if this is what he wants)
%    8  Histogram of % fixation (included AND excluded clips)
%
%OTHER NOTES
% The following column headers are necessary for the script to run:
%   Date, SessionID, Clip, Age, SampleCount, FixCount, LostCount, Status
% A Protocol column is necessary if protocols input is specified.
% All column headers are case insensitive. In addition, the age column is
% only matched for the first 3 characters (e.g. Age(months) is acceptable).
%
% See also: AUDITQUERY, READINQUERY, SESSIONAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 9.5.2014


% Graph 6 should ONLY be included clips
%
% Add a histogram -- % fix/clip (included AND excluded clips)
%
% !! Change the way that dates are being binned -- rather than always
% binning by week/month, make it dependent on the range of dates. Do a
% minimum of binning by week, but if there are > 20 weeks, bin by month. If
% there are more than 24 months, bin by 3 months. Also, make sure that
% every bin btwn the start and end are included -- should plot empty bars
% (or whatever) rather than skipping them.
%
% xticks? would be useful for graphs over time (w/ rotated labels)
% Finish documenting/testing

%% Error checking

assert(logical(exist(dirToSave,'dir')),...
    ['Error in RunAuditGraphs: cannot find dir where graphs should be saved:\n\t' dirToSave]);
assert(size(data,2)==size(fields,2),'Error in RunAuditGraphs: DATA and FIELDS must have the same number of columns.');

% Necessary columns:
dateCol=find(cellfun(@(x) ~isempty(strfind(x,'Date')),fields));
sessionIDCol=strcmpi('SessionID',fields);
clipIDCol = strcmpi('Clip',fields);
ageCol = strncmpi('Age',fields,3);
sampleCol=strcmpi('SampleCount',fields);
fixCol=strcmpi('FixCount',fields);
lostCol = strcmpi('LostCount',fields);
statusCol = strcmpi('Status',fields);

assert(length(dateCol)==1,'Error in RunAuditGraphs: there must be exactly one "Date" column in FIELDS');
assert(sum(sessionIDCol)==1,'Error in RunAuditGraphs: there must be exactly one "SessionID" column in FIELDS');
assert(sum(clipIDCol)==1,'Error in RunAuditGraphs: there must be exactly one "Clip" column in FIELDS');
assert(sum(ageCol)==1,'Error in RunAuditGraphs: there must be exactly one "Age" column in FIELDS');
assert(sum(sampleCol)==1,'Error in RunAuditGraphs: there must be exactly one "SampleCount" column in FIELDS');
assert(sum(fixCol)==1,'Error in RunAuditGraphs: there must be exactly one "FixCount" column in FIELDS');
assert(sum(lostCol)==1,'Error in RunAuditGraphs: there must be exactly one "LostCount" column in FIELDS');
assert(sum(statusCol)==1,'Error in RunAuditGraphs: there must be exactly one "Status" column in FIELDS');


%% Process queries 

% Add binned ages column
[fields,data] = AddBinnedAge(fields,data,ageCol);
binAgeCol = strcmpi('BinnedAge',fields);
if sum(binAgeCol)==0; error('Error in RunAuditGraphs: no BinnedAge column -- AddBinnedAge() may not have run properly.'); end

% Add week start column
[fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
weekStartCol = strcmpi('WeekStart',fields);
if sum(weekStartCol)==0; error('Error in RunAuditGraphs: no WeekStart column -- AddWeekStart() may not have run properly.'); end


%Select only the specified protocols
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


%% Pull data for graphing:

%Unique sessions
sessionIDs=data(:,sessionIDCol);
unqSessionIDs=unique(sessionIDs);

%Clip IDs
clipIDsALL = cell2mat(data(:,clipIDCol));
unqClipIDs = unique(clipIDsALL);
unqClipIDs = unqClipIDs(unqClipIDs~=9999); % exclude 9999DEMO

%Include/exclude 
statusALL = data(:,statusCol);

%Dates/Labels
weekStartsALL = cell2mat(data(:,weekStartCol));
unqWeekStarts = unique(weekStartsALL,'rows');
unqWeekStarts = unqWeekStarts(sum(unqWeekStarts,2)>0,:); % exclude missing dates from graphs
unqWeekStarts = sortrows(unqWeekStarts,[1,2,3]);
weekStarts = zeros(size(unqSessionIDs,1),3);

% make date labels (spread out)
if size(unqWeekStarts,1)<10
    numDateLabels=size(unqWeekStarts,1);
elseif size(unqWeekStarts,1)<15
    numDateLabels=6;
else
    numDateLabels=10;
end
xTicks = 1:floor(size(unqWeekStarts,1)/numDateLabels):size(unqWeekStarts,1);

dateLabels = cell(numDateLabels,2); %xtick location + labels for graphing
for a = 1:numDateLabels
    xTick = xTicks(a);
    dateLabels(a,:) = {xTick,datestr([unqWeekStarts(xTick,:),0,0,0],'mmm dd, yyyy')};
end

%Binned Ages
binAgesALL = cell2mat(data(:,binAgeCol));
unqBinAges = unique(binAgesALL);
unqBinAges = unqBinAges(unqBinAges>0); %exclude unknown ages from graphs
binAges=zeros(size(unqSessionIDs,1));

%Sample count, fix count, and lost count
sampleCountsALL=cell2mat(data(:,sampleCol));
sampleCounts=zeros(size(unqSessionIDs,1));

% Fix count
fixCountsALL=cell2mat(data(:,fixCol));
fixCounts=zeros(size(unqSessionIDs,1));

% Corresponding to unique session IDs
for ii=1:length(unqSessionIDs)
    ind=find(strcmpi(unqSessionIDs{ii},sessionIDs));
    ind=ind(1); %first occurrence of the session ID
    
    weekStarts(ii,:)=weekStartsALL(ind,:);
    binAges(ii)=binAgesALL(ind);
    
    sampleCounts(ii)=sum(cell2mat(data(strcmpi(sessionIDs,unqSessionIDs(ii)),sampleCol)));
    fixCounts(ii)=sum(cell2mat(data(strcmpi(sessionIDs,unqSessionIDs(ii)),fixCol)));
end


%% GRAPHS %%
origDir=pwd;
cd(dirToSave)

%% #4a Average viewing time/session VS time (by week) -- w/ error bars

graph=[];
allViewTimes=[];
for ii = 1:size(unqWeekStarts,1)
    viewTime=sampleCounts(weekStarts(:,1)==unqWeekStarts(ii,1) &...
        weekStarts(:,2)==unqWeekStarts(ii,2) & weekStarts(:,3)==unqWeekStarts(ii,3))/(30*60);
    n=length(viewTime);
    stderr=std(viewTime)/sqrt(n);
    graph=[graph;mean(viewTime),stderr,n];
    allViewTimes = [allViewTimes;viewTime];
end

figure();
axes4a=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2));
rotateXLabels(gca(),30);
hold(axes4a,'all');
bar(axes4a,1:size(unqWeekStarts,1),graph(:,1),'w');
errorbar(1:size(unqWeekStarts,1),graph(:,1),graph(:,2),'.');
ylabel('Viewing Time (min)','FontSize',13);
title([graphTitle,': Mean Viewing Time'],'FontSize',15);

saveas(axes4a,['04a_MeanViewTime_Week- ',graphTitle,'.fig']);
saveas(axes4a,['04a_MeanViewTime_Week- ',graphTitle,'.eps']);

%% #4b Histogram of viewing time

figure();
nbins=10;
hist(allViewTimes,nbins);
hold on
xlabel('Viewing Time (min)','FontSize',13);
ylabel('Number of Sessions','FontSize',13);
title([graphTitle,': Histogram - Viewing Time'],'FontSize',15);

saveas(gcf,['04b_HistViewTime- ',graphTitle,'.fig']);
saveas(gcf,['04b_HistViewTime- ',graphTitle,'.eps']);

%% #5 Number of sessions/clip ID (stacked bars: included vs excluded)

graph=[];
for ii = 1:length(unqClipIDs)
    graph(ii,1) = sum(clipIDsALL==unqClipIDs(ii)&strcmpi('include',statusALL));
    graph(ii,2) = sum(clipIDsALL==unqClipIDs(ii)&strcmpi('exclude',statusALL));
end

figure()
axes5=axes('XTick',1:length(unqClipIDs),'XTickLabel',unqClipIDs,'XLim',[0,length(unqClipIDs)+1]);
hold(axes5,'all');
bar5=bar(axes5,1:length(unqClipIDs),[graph(:,1),graph(:,2)],'BarLayout','stacked');
set(bar5(2),'FaceColor',[0.83 0.81 0.78]);
legend('Include','Exclude');
xlabel('Clip ID','FontSize',13);
ylabel('Number of Sessions','FontSize',13);
title([graphTitle,': Included/Excluded Sessions per Clip'],'FontSize',15);

saveas(axes5,['05_Sessions_Clip- ',graphTitle,'.fig']);
saveas(axes5,['05_Sessions_Clip- ',graphTitle,'.eps']);

%% #6 	% Fixation VS clip ID
% only included clips 

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
set('Position',[1 1 1500 450]);
title([graphTitle,': % Fixation per Clip'],'FontSize',15);

saveas(axes6,['06_PerFix_Clip- ',graphTitle,'.fig']);
saveas(axes6,['06_PerFix_Clip- ',graphTitle,'.eps']);


%% #7 % Fixation VS binned age
% TODO - ask WJ if this should also be only included clips

graph=[];
for ii = 1:length(unqBinAges)
    ageAllPerFix = fixCountsALL(binAges==unqBinAges(ii))./sampleCountsALL(binAges==unqBinAges(ii));
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
title([graphTitle,': % Fixation vs Age'],'FontSize',15);

saveas(axes7,['07_PerFix_Age- ',graphTitle,'.fig']);
saveas(axes7,['07_PerFix_Age- ',graphTitle,'.eps']);

%% #8 Histogram of % fixation (included AND excluded clips)

allPerFix=fixCountsALL./sampleCountsALL;

figure()
binInc=.1;
bins=[0:binInc:1]+binInc/2;
hist(allPerFix,bins);
hold on
set(gca,'XLim',[0,1]);
xlabel('% Fixation','FontSize',13);
ylabel('# Clips','FontSize',13);
title([graphTitle,': Histogram - % Fixation'],'FontSize',15);

saveas(gca,['08_HistClipsPerSess- ',graphTitle,'.fig']);
saveas(gca,['08_HistClipsPerSess- ',graphTitle,'.eps']);

%%%%%%%%%%%%%%%%


%% Clean up
%move all the .fig files to a subfolder
if ~exist('figs','dir')
    mkdir('figs');
end
movefile('*.fig','figs/');

%close all
disp(' ')
fprintf(['Run graphs saved in\n\t',dirToSave,'\n']);

cd(origDir)