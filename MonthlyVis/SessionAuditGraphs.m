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
%   1.  Count of sessions VS week - remove? same as 2c, basically
%   2a. # Success VS rounded age
%       % Success VS rounded age
%    b. Single bar, stacked: 3+, <3 EDIT - won't let me do a single stacked bar...
%    c. # Success VS time (week)
%       % Success VS time (week)
%   3a. Average # clips seen per session VS time (by week) -- Q>=2 (w/ error bars)
%    b. Average # clips seen per session VS binned age -- Q>=2 (w/ error bars)
%    c. Histogram of # clips seen
%
%OTHER NOTES
% The following column headers are necessary for the script to run:
%   Date, Age, NumberOfClips, Quality
% A Protocol column is necessary if protocols input is specified.
% All column headers are case insensitive. In addition, the age column is
% only matched for the first 3 characters (e.g. Age(months) is acceptable).
%
% See also: AUDITQUERY, READINQUERY, SESSIONAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 8.21.14

% NOTE ABOUT rotateXLabels -- Set YLim after xlabels have been rotated, or
% it messes up positioning (for some reason)

% Finish documenting/testing
% What graphs should take into account the include/exclude status? or
%   quality?
% unqWeekStarts -- should be the entire range, even if there weren't
%   eye-tracking sessions! (make sure this doesn't mess up graphs...)
% xticks? would be useful for graphs over time (w/ rotated labels)



%% Error checking

assert(logical(exist(dirToSave,'dir')),...
    ['Error in SessionAuditGraphs: cannot find dir where graphs should be saved:\n\t' dirToSave]);
assert(size(data,2)==size(fields,2),'Error in SessionAuditGraphs: DATA and FIELDS must have the same number of columns.');

% Necessary columns:
ageCol = strncmpi('Age',fields,3);
dateCol = strcmpi('Date',fields);
numClipsCol=strcmpi('NumberOfClips',fields);
qualCol = strcmpi('Quality',fields);

assert(length(ageCol)==1,'Error in SessionAuditGraphs: there must be exactly one "Age" column in FIELDS');
assert(length(dateCol)==1,'Error in SessionAuditGraphs: there must be exactly one "Date" column in FIELDS');
assert(length(numClipsCol)==1,'Error in SessionAuditGraphs: there must be exactly one "NumberOfClips" column in FIELDS');
assert(length(qualCol)==1,'Error in SessionAuditGraphs: there must be exactly one "Quality" column in FIELDS');

%% 
origDir=pwd;
addpath(origDir);

%% Process queries further

% Add binned ages column
[fields,data] = AddBinnedAge(fields,data,ageCol);
binAgeCol = strcmpi('BinnedAge',fields);
if sum(binAgeCol)==0; error('Error in SessionAuditGraphs: no BinnedAge column -- AddBinnedAge() may not have run properly.'); end

% Add week start column
[fields,data] = AddWeekStart(fields,data,dateCol,'Mon');
weekStartCol = strcmpi('WeekStart',fields);
if sum(weekStartCol)==0; error('Error in SessionAuditGraphs: no "WeekStart" column -- AddWeekStart() may not have run properly.'); end

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
    
%Dates/Labels
weekStarts = cell2mat(data(:,weekStartCol));
unqWeekStarts = unique(weekStarts,'rows');
unqWeekStarts = unqWeekStarts(sum(unqWeekStarts,2)>0,:); % exclude missing dates from graphs
unqWeekStarts = sortrows(unqWeekStarts,[1,2,3]);

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

%Round ages
roundAges=cellfun(@round,data(:,ageCol),'UniformOutput',false);
roundAges(cellfun(@isempty,roundAges))={-1}; %flag empty cells w/ -1
roundAges=cell2mat(roundAges);
unqRoundAges=unique(roundAges);
unqRoundAges = unqRoundAges(unqRoundAges>0); %exclude unknown ages from graphs

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

%% GRAPHS
cd(dirToSave)

%% #1 Count of sessions VS week
graph=[];
for ii = 1:size(unqWeekStarts,1)
    graph(ii,1)=sum(weekStarts(:,1)==unqWeekStarts(ii,1)&...
        weekStarts(:,2)==unqWeekStarts(ii,2)&weekStarts(:,3)==unqWeekStarts(ii,3));
end

figure();
axes1=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(unqWeekStarts,1)+1]);
rotateXLabels(gca(),30);
hold(axes1,'all');
bar(axes1,1:length(unqWeekStarts),graph);
ylabel('# Sessions','FontSize',13);
title([graphTitle,': Sessions per Week'],'FontSize',15);

saveas(axes1,['01_Sessions_Week- ',graphTitle,'.fig']);
saveas(axes1,['01_Sessions_Week- ',graphTitle,'.eps']);


%% Success rate (as # AND %)

%% #2a Success VS rounded age

%NUMBER SUCCESSFUL
graph=[];
graph(:,1)=unqRoundAges;
graph(:,2)=zeros(size(graph,1),1);
graph(:,3)=zeros(size(graph,1),1);

for ii=1:length(graph)
    numSuccess=sum(roundAges==graph(ii,1)&qualities>=3); %# successful sessions
    n=sum(roundAges==graph(ii,1)); %n
    graph(ii,2:3)=[numSuccess,n];
end

figure();
axes2a=axes('XTick',graph(:,1),'XTickLabel',graph(:,1));
hold(axes2a,'all');
bar1=bar(axes2a,graph(:,1),[graph(:,2),graph(:,3)-graph(:,2)],'BarLayout','stacked');
set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
legend('Successful (Q>=3)','Unsuccessful (Q<3)');
xlabel('Age (months)','FontSize',13);
ylabel('# Sessions','FontSize',13);
title([graphTitle,': Successful/Unsuccessful Sessions by Age'],'FontSize',15);

saveas(axes2a,['02a_#Success_RoundAge- ',graphTitle,'.fig']);
saveas(axes2a,['02a_#Success_RoundAge- ',graphTitle,'.eps']);

%PERCENT SUCCESSFUL
figure();
axes2a=axes('XTick',graph(:,1),'XTickLabel',graph(:,1),'YLim',[0,1]);
hold(axes2a,'all');
bar(axes2a,graph(:,1),graph(:,2)./graph(:,3));
xlabel('Age (months)','FontSize',13);
ylabel('% Successful Sessions','FontSize',13);
title([graphTitle,': % Successful Sessions (Q>=3) by Age'],'FontSize',15);

saveas(axes2a,['02a_%Success_RoundAge- ',graphTitle,'.fig']);
saveas(axes2a,['02a_%Success_RoundAge- ',graphTitle,'.eps']);


%% #2b Single bar, stacked: 3+, <3 EDIT - won't let me do a single stacked bar...

% figure();
% axes2b=axes();
% bar2b=bar(axes2b,[sum(graph(:,2));sum(graph(:,3)-graph(:,2))],'stacked');
% set(bar2b(2),'FaceColor',[0.83 0.81 0.78]);

% saveas(axes2b,['02b_SingleBarSuccess- ',graphTitle,'.fig']);
% saveas(axes2b,['02b_SingleBarSuccess- ',graphTitle,'.eps']);

%% #2c Success VS time (week)

%NUMBER SUCCESSFUL/UNSUCCESSFUL (assume that if quality is missing, it was
%unsuccessful)
graph=[];
graph(:,1)=zeros(size(graph,1),1); %# successful
graph(:,2)=zeros(size(graph,1),1); %n

for ii = 1:size(unqWeekStarts,1)
    graph(ii,1)=sum(qualities>=3&weekStarts(:,1)==unqWeekStarts(ii,1)&...
        weekStarts(:,2)==unqWeekStarts(ii,2)&weekStarts(:,3)==unqWeekStarts(ii,3));
    graph(ii,2)=sum(weekStarts(:,1)==unqWeekStarts(ii,1)&...
        weekStarts(:,2)==unqWeekStarts(ii,2)&weekStarts(:,3)==unqWeekStarts(ii,3));
end

figure();
axes2c=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(unqWeekStarts,1)+1]);
rotateXLabels(gca(),30);
hold(axes2c,'all');
bar1=bar(axes2c,1:length(unqWeekStarts),[graph(:,1),graph(:,2)-graph(:,1)],'BarLayout','stacked');
set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
legend('Successful (Q>=3)','Unsuccessful (Q<3)');
ylabel('# Sessions','FontSize',13);
title([graphTitle,': Successful/Unsuccessful Sessions'],'FontSize',15);

saveas(axes2c,['02c_#Success_Time- ',graphTitle,'.fig']);
saveas(axes2c,['02c_#Success_Time- ',graphTitle,'.eps']);


%PERCENT SUCCESSFUL
figure();
axes2c=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(unqWeekStarts,1)+1]);
rotateXLabels(gca(),30);
set(axes2c,'YLim',[0,1]);
hold(axes2c,'all');
bar(axes2c,1:length(unqWeekStarts),graph(:,1)./graph(:,2));
ylabel('% Successful Sessions','FontSize',13);
title([graphTitle,': % Successful Sessions (Q>=3)'],'FontSize',15);

saveas(axes2c,['02c_%Success_Time- ',graphTitle,'.fig']);
saveas(axes2c,['02c_%Success_Time- ',graphTitle,'.eps']);
     

%% #3a	Average # clips seen per session VS time (by week) -- Q>=2 (w/ error bars)

graph=[];
for ii=1:length(unqWeekStarts)
    clipsSeenVec=numClips(qualities>=2 & numClips>=0 & ...
        weekStarts(:,1)==unqWeekStarts(ii,1) & ...
        weekStarts(:,2)==unqWeekStarts(ii,2) & ... 
        weekStarts(:,3)==unqWeekStarts(ii,3));
    avgClipsSeen=mean(clipsSeenVec);
    n=length(clipsSeenVec);
    stdErr=std(clipsSeenVec)/sqrt(n);
    graph=[graph;avgClipsSeen,stdErr,n];
end

figure();
axes3a=axes('XTick',cell2mat(dateLabels(:,1)),'XTickLabel',dateLabels(:,2),'XLim',[0,size(unqWeekStarts,1)+1]);
rotateXLabels(gca(),30);
hold(axes3a,'all');
bar(axes3a,1:size(graph,1),graph(:,1),'FaceColor','w');
errorbar(axes3a,1:size(graph,1),graph(:,1),graph(:,2),'k.');
ylabel('# Clips Seen','FontSize',13);
title([graphTitle,': Average Clips Seen/Session (Q>=2)'],'FontSize',15);

saveas(axes3a,['03a_ClipsPerSess_Time- ',graphTitle,'.fig']);
saveas(axes3a,['03a_ClipsPerSess_Time- ',graphTitle,'.eps']);

%% #3b Average # clips seen per session VS binned age (?) -- Q>=2 (w/ error bars) 
% this wasn't discussed with Warren, but seemed useful to keep it in

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