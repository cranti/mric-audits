%AUDITGRAPHS_YEARS This function creates and saves a series of graphs based on
%data queried from MRIC for a specified date range.
%
% INPUTS:
%       startdate (string) - Beginning of the date range for the query (YYYY-MM-DD)
%       enddate (string) - End of the date range for the query (YYYY-MM-DD)
%
% SAVED GRAPHS:
%       1) Number of clips seen by rounded age
%       1a) Number of clips seen per binned age (x2: 0-36m, school age)
%       2) Number of eye tracking sessions by month 
%       2a) Graph 2 split by protocol categories (x3: Infant, toddler,
%           school age)
%       3) Percent successful sessions by binned age (x2: 0-36m, school age)
%       4) Number of successful/unsuccessful sessions (x2: 0-36m, school age)
%       5) Mean viewing time per age (x2: 0-36m binned, 0-36m rounded)
%       6) Number of sessions by viewing time
%
% Query is only run again if it can't be found
%
% Graphs are saved twice (.eps and .fig), so that the figures can be edited
% later. (This is mostly so that squished axis labels can be fixed).
%
% Graphs are saved in a subfolder of /Users/etl/Desktop/DataQueries/Graphs/
% (named for the date range of the query). Figs are saved in a further
% subfolder (Figs). If the /Graph subfolder for the query already exists,
% function alerts user and asks them if they want to continue (possibly
% overwriting any existing graphs).
%
% All graphs are closed after the function is run.
%
% REMOVING WASH-U SESSIONS (as of 5.22.2014)

% Written by Carolyn Ranti
% 5.21.2014 - for longer term queries - graphing by YEAR, skipping protocol
% graphs. it's a little rough, and there are some graphs that aren't
% totally relevant/necessary

%Debugging/non function version
clear all
startdate='2006-01-01';
enddate='2013-12-31';


%function auditGraphs_YEARS(startdate,enddate)

disp('----------------------------------------------------------------------------------------------------------')
disp('                                           Running auditGraphs.m                                          ')

origDir = pwd;
graphDir = ['/Users/etl/Desktop/DataQueries/Graphs/',startdate,'_',enddate];
queryDir = ['/Users/etl/Desktop/DataQueries/',startdate,'_',enddate];

%Create date specific dir in Graph folder. If it already exists, ask user if they
%want to continue (and possibly overwrite existing graphs)
[~,mess]=mkdir(graphDir);
if ~isempty(mess)
    disp(' ')
    disp('Looks like there''s already a graph directory for this query.')
    
    while (1)
        cont=input('Do you want continue and overwrite any existing graphs? (Y/N): ','s');
        if strcmpi(cont,'n') || strcmpi(cont,'y')
            break
        end
    end
else
    cont='y';
end

%%
if strcmpi(cont,'n')
    disp('Goodbye!');
else
%%

processData=0; 
%if the query dir can't be found, runPython should be set to 1
if ~exist(queryDir,'dir')
    runPython=1; %this catch exists in processAuditQuery, too
else
    fprintf(['Looks like this query exists in the following directory:\n\t',queryDir]);
    runPython=strcmpi('y',input('\nWould you like to run it again and overwrite any existing files? (y/n): ','s'));
    
    %CATCH: if the mat file with processed data cannot be found, processData should be 1
    cd(queryDir)
    if ~processData && ~exist([startdate,'_',enddate,'.mat'],'file')
        disp(' ')
        disp('Cannot find processed data matfile - processing.');
        processData=1;
    end
end

%Run the query (runPython) and/or process query output (~runPython & processData) 
%and/or load already processed query output (~runPython & ~processData)
if processData || runPython
    cd(origDir)
    [sessionFields,sessionData,runFields,runData,AllProtocols,sProtLogic,rProtLogic]=processAuditQuery(startdate,enddate,runPython);
else
    cd(queryDir)
    load([startdate,'_',enddate])
end


%% REMOVE WASHU SESSIONS
sWashuProtLogic=logical(sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'wash')),AllProtocols)),2));
rWashuProtLogic=logical(sum(rProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'wash')),AllProtocols)),2));

sessionData=sessionData(~sWashuProtLogic,:);
sProtLogic=sProtLogic(~sWashuProtLogic,:);
runData=runData(~rWashuProtLogic,:);
rProtLogic=rProtLogic(~rWashuProtLogic,:);


%% Data from the session query for graphing:

%Dates
sDateCol = strcmpi('Date',sessionFields);
sDateMonths = cell2mat(cellfun(@(x) x(1:2), sessionData(:,sDateCol),'UniformOutput',false));
sUnqDateMonths = unique(sDateMonths,'rows');

sYears = cell2mat(cellfun(@(x) x(1), sessionData(:,sDateCol),'UniformOutput',false));
sUnqYears = unique(sYears,'rows');

sDateLabels={}; %Labels for graphing (convert Month/Year to string: M(M)-YYYY
for a=1:length(sUnqDateMonths)
    sDateLabels{a}=[num2str(sUnqDateMonths(a,2)),'-',num2str(sUnqDateMonths(a,1))];
end

%Binned Ages
sBinnedAgeCol = strcmpi('Binned Age',sessionFields);
sBinnedAges=cell2mat(sessionData(:,sBinnedAgeCol));
sUnqBinnedAges=unique(sBinnedAges);
%for looping purposes
binnedAgeGroups=struct('minAge',{0,6,60},...
                    'maxAge',{5,36,216},...
                    'title',{'Infants','Toddlers','SchoolAge'});

%Round ages
sAgeCol = strncmpi('Age',sessionFields,3);
sRoundAges=cellfun(@round,sessionData(:,sAgeCol),'UniformOutput',false);
sRoundAges(cellfun(@isempty,sRoundAges))={-1}; %convert empty cells to -1 (flag for ages that aren't in database)
sRoundAges=cell2mat(sRoundAges);
sUnqRoundAges=unique(sRoundAges);

    
%# of clips seen (per person)
sNumClipsCol=strcmpi('Number of clips',sessionFields);
sNumClips=cell2mat(sessionData(:,sNumClipsCol));

%Quality
sQualCol = strcmpi('Quality',sessionFields);
sQualities = cell2mat(sessionData(:,sQualCol));

% %Logicals to split sessionData by protocols
% %CR: Missing the ace-center grant right now...arg. Check with Warren...
% sInfantProtLogic=((sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'infant')),AllProtocols)),2))...
%     |(sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'eye-tracking')),AllProtocols)),2)))...%this should get the ace center eye-tracking grant
%     &~(sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'older-sib')),AllProtocols)),2)); %avoid the older sib people
% sToddlerProtLogic=logical(sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'toddler')),AllProtocols)),2));
% sSchoolProtLogic=logical(sum(sProtLogic(:,cellfun(@(x) ~isempty(strfind(x,'school')),AllProtocols)),2));

% %for looping purposes
% %for looping purposes
% sProtLogs=struct('logical',{sInfantProtLogic,sToddlerProtLogic,sSchoolProtLogic},...
%                 'title',{'Infant Protocols','Toddler Protocols','School Age Protocols'}); %washuProtLogic,'Wash U Protocols'
            




%% Get data from the RUN query for graphing

%Unique sessions
rSessionIDCol=strcmpi('Session ID',runFields);
rSessionIDs=runData(:,rSessionIDCol);
rUnqSessionIDs=unique(rSessionIDs);

%Sample count, fix count, and lost count (corresponds to rUnqSessionIDs)
rSampleCol=strcmpi('Sample count',runFields);
sampleCounts=zeros(size(rUnqSessionIDs));
for ii=1:length(rUnqSessionIDs)
    sampleCounts(ii)=sum(cell2mat(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rSampleCol)));
end
rFixCol=strcmpi('Fix count',runFields);
fixCounts=zeros(size(rUnqSessionIDs));
for ii=1:length(rUnqSessionIDs)
    fixCounts(ii)=sum(cell2mat(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rFixCol)));
end
rLostCol= strcmpi('Lost count',runFields);
lostCounts=zeros(size(rUnqSessionIDs));
for ii=1:length(rUnqSessionIDs)
    lostCounts(ii)=sum(cell2mat(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rLostCol)));
end

%Binned ages (also corresponds to rUnqSessionIDs)
rBinAgeCol = strcmpi('Binned Age',runFields);
rBinnedAges=zeros(size(rUnqSessionIDs));
for ii=1:length(rUnqSessionIDs)
    rBinnedAges(ii)=min(cell2mat(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rBinAgeCol)));
end
rUnqBinnedAges=unique(rBinnedAges);

%Round ages
rAgeCol = strncmpi('Age',runFields,3);
rRoundAges=zeros(size(rUnqSessionIDs));
for ii=1:length(rUnqSessionIDs)
    if isempty(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rAgeCol))
        rRoundAges(ii)=-1; %(flag for ages that aren't in database)
    else
        try %if there's an empty cell, it won't be flagged...
            rRoundAges(ii)=round(min(cell2mat(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rAgeCol))));
        catch
            rRoundAges(ii)=-1;
        end
    end
end
rUnqRoundAges=unique(rRoundAges);

%Dates
rDateCol = strcmpi('Date',runFields);
rDateMonths=zeros(size(rUnqSessionIDs));
rYears=zeros(size(rUnqSessionIDs));
for ii=1:length(rUnqSessionIDs)
    temp=cell2mat(runData(strcmpi(rSessionIDs,rUnqSessionIDs(ii)),rDateCol));
    rYears(ii)=temp(1,1);
end
rUnqYears = unique(rYears,'rows');

%GRAPH THINGS 
cd(graphDir)

%% RATE OF DATA COLLECTION

%%%%%%%%%%%%%%%%
%GRAPH1: Total number of clips seen by rounded age (session query)
graph1=[];
for ii=1:length(sUnqRoundAges)
    if sUnqRoundAges(ii)~=-1 && sUnqRoundAges(ii)<=240 %-1 is flag - no age in database
        totalClipsSeen=sum(sNumClips(sRoundAges==sUnqRoundAges(ii)));
        n=length(sNumClips(sRoundAges==sUnqRoundAges(ii)));
        %store age, sum, and number of data points in matrix
        graph1=[graph1;sUnqRoundAges(ii),totalClipsSeen,n];
    end
end

figure();
axes1=axes(); %('XTick',graph1(:,1),'XTickLabel',graph1(:,1));
hold(axes1,'all');
bar(axes1,graph1(:,1),graph1(:,2));
xlabel('Binned Age (months)','FontSize',13);
ylabel('Total Number of Clips Seen','FontSize',13);
title({'Total Number of Clips Seen per Rounded Age'},'FontSize',15);

saveas(axes1,'01_NumClipsSeen_RoundAge.fig');
saveas(axes1,'01_NumClipsSeen_RoundAge.eps');

%%%%%%%%%%%%%%%%
%GRAPH1a: Total number of clips seen by BINNED age (session query) - split by age groups
%specified above

for i=1:length(binnedAgeGroups)
    graph1a=[];
    ageGroupBin=sUnqBinnedAges(sUnqBinnedAges>=binnedAgeGroups(i).minAge & sUnqBinnedAges<=binnedAgeGroups(i).maxAge);
    for ii=1:length(ageGroupBin)
        totalClipsSeen=sum(sNumClips(sBinnedAges==ageGroupBin(ii)));
        n=length(sNumClips(sBinnedAges==ageGroupBin(ii)));
        %store age, sum, and number of data points in matrix
        graph1a=[graph1a;ageGroupBin(ii),totalClipsSeen,n];
    end
    
    figure();
    axes1a=axes('XTick',graph1a(:,1),'XTickLabel',graph1a(:,1));
    hold(axes1a,'all');
    bar(axes1a,graph1a(:,1),graph1a(:,2));
    xlabel('Binned Age (months)','FontSize',13);
    ylabel('Total Number of Clips Seen','FontSize',13);
    title({'Total Number of Clips Seen per Age Group'},'FontSize',15);

    saveas(axes1a,['01a_NumClipsSeen_BinAge- ',binnedAgeGroups(i).title,'.fig']);
    saveas(axes1a,['01a_NumClipsSeen_BinAge- ',binnedAgeGroups(i).title,'.eps']);
end
%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%
%GRAPH2: Number of sessions/YEAR
graph2=[];
for ii = 1:size(sUnqYears,1)
    graph2(ii,1)=sum(sYears==sUnqYears(ii));
end

figure();
axes2=axes('XTick',1:length(sUnqYears),'XTickLabel',sUnqYears+2000); %when excel data is used, it chops off the beginning...
hold(axes2,'all');
bar(axes2,1:length(sUnqYears),graph2);
xlabel('Year','FontSize',13);
ylabel('# Sessions','FontSize',13);
title('Number of Eye-tracking Sessions Per Year (All Protocols)','FontSize',15);

saveas(axes2,'02_NumSessions_Year.fig');
saveas(axes2,'02_NumSessions_Year.eps');

%GRAPH2a: Total number of sessions seen by year -- graphs split by BINNED age

for i=1:length(binnedAgeGroups)
    graph2a=[];
    
    for ii = 1:size(sUnqYears,1)
        graph2a(ii,1)=sum(sYears==sUnqYears(ii) & sBinnedAges>=binnedAgeGroups(i).minAge & sBinnedAges<=binnedAgeGroups(i).maxAge);
    end

    figure();
    axes2a=axes('XTick',1:length(sUnqYears),'XTickLabel',sUnqYears+2000); %when excel data is used, it chops off the beginning...
    hold(axes2a,'all');
    bar(axes2a,1:length(sUnqYears),graph2a);
    xlabel('Year','FontSize',13);
    ylabel('# Sessions','FontSize',13);
    title(['Number of Eye-tracking Sessions Per Year (',num2str(binnedAgeGroups(i).minAge),'-',num2str(binnedAgeGroups(i).maxAge),' month olds)'],'FontSize',15);

    saveas(axes2a,['02a_NumClipsSeen_Year- ',binnedAgeGroups(i).title,'.fig']);
    saveas(axes2a,['02a_NumClipsSeen_Year- ',binnedAgeGroups(i).title,'.eps']);
end
%%%%%%%%%%%%%%%%

%{
%% QUALITY
% 
% %%%%%%%%%%%%%%%%
% %GRAPH3&4: split by age groups (specified above)
% %   3) Percent successful sessions by age in months (EDIT: right now, only doing up to 36mo)
% %   4) Number of successful vs unsuccessful sessions by age
% for i=1:length(binnedAgeGroups)
% 
%     graph3=[];
%     graph3(:,1)=sUnqBinnedAges(sUnqBinnedAges>=binnedAgeGroups(i).minAge & sUnqBinnedAges<=binnedAgeGroups(i).maxAge);
%     graph3(:,2)=zeros(length(graph3),1);
%     graph3(:,3)=zeros(length(graph3),1);
% 
%     for ii=1:length(graph3)
%         n=sum(sBinnedAges==graph3(ii,1)); %n
%         numSuccess=sum(sBinnedAges==graph3(ii,1)&sQualities>=3); %# successful sessions
%         graph3(ii,2:3)=[numSuccess,n];
%     end
% 
%     figure();
%     axes3=axes('XTick',graph3(:,1),'XTickLabel',graph3(:,1),'YLim',[0,1]);
%     hold(axes3,'all');
%     bar(axes3,graph3(:,1),graph3(:,2)./graph3(:,3));
%     xlabel('Age (months)','FontSize',13);
%     ylabel('% Successful Sessions','FontSize',13);
%     title('% Successful Sessions (Q>=3) by Age','FontSize',15);
% 
%     saveas(axes3,['03_PerSuccessSessions_Age- ',binnedAgeGroups(i).title,'.eps']);
%     saveas(axes3,['03_PerSuccessSessions_Age- ',binnedAgeGroups(i).title,'.fig']);
%     
%     %GRAPH4
%     figure();
%     axes4=axes('XTick',graph3(:,1),'XTickLabel',graph3(:,1));
%     hold(axes4,'all');
%     bar1=bar(axes4,graph3(:,1),[graph3(:,2),graph3(:,3)-graph3(:,2)],'BarLayout','stacked');
%     set(bar1(2),'FaceColor',[0.83 0.81 0.78]);
%     legend('Successful (Q>=3)','Unsuccessful (Q<3)');
%     xlabel('Age (months)','FontSize',13);
%     ylabel('Number of Sessions','FontSize',13);
%     title('Successful vs Unsuccessful Sessions by Age','FontSize',15);
% 
%     saveas(axes4,['04_NumSuccessSessions_Age- ',binnedAgeGroups(i).title,'.eps']);
%     saveas(axes4,['04_NumSuccessSessions_Age- ',binnedAgeGroups(i).title,'.eps']);
%     
%     
% end
%%%%%%%%%%%%%%%%
%}

%% Run level query graphs

%%%%%%%%%%%%%%%%
%GRAPH5: Mean duration of viewing time by age in months (1- first binned
%age group (infants and toddlers), and 2- rounded ages up to 40)

graph5=[];
ageGroupBin=rUnqBinnedAges(rUnqBinnedAges>=0 & rUnqBinnedAges<=36);
for ii=1:length(ageGroupBin)
    viewingTime=mean(sampleCounts(rBinnedAges==ageGroupBin(ii))/(30*60)); %CR EDIT - make sure it's 30, not 60!!!
    n=length(sampleCounts(rBinnedAges==ageGroupBin(ii)));
    %store age, sum, and number of data points in matrix
    graph5=[graph5;ageGroupBin(ii),viewingTime,n];
end

figure();
axes5=axes('XTick',graph5(:,1),'XTickLabel',graph5(:,1));
hold(axes5,'all');
bar(axes5,graph5(:,1),graph5(:,2));
xlabel('Binned Age (months)','FontSize',13);
ylabel('Viewing Time (min)','FontSize',13);
title({'Mean Viewing Time per Age'},'FontSize',15);

saveas(axes5,'05_MeanViewTime_BinAge- Inf&Todd.fig');
saveas(axes5,'05_MeanViewTime_BinAge- Inf&Todd.eps');

%repeat for rounded ages
graph5=[];
for ii=1:length(rUnqRoundAges)
    if rUnqRoundAges(ii)>=0 && rUnqRoundAges(ii)<=40 
        viewingTime=mean(sampleCounts(rRoundAges==rUnqRoundAges(ii))/(30*60));
        n=length(sampleCounts(rRoundAges==rUnqRoundAges(ii)));
        %store age, sum, and number of data points in matrix
        graph5=[graph5;rUnqRoundAges(ii),viewingTime,n];
    end
end

figure();
axes5=axes();
hold(axes5,'all');
bar(axes5,graph5(:,1),graph5(:,2));
xlabel('Rounded Age (months)','FontSize',13);
ylabel('Viewing Time (min)','FontSize',13);
title({'Mean Viewing Time per Age'},'FontSize',15);

saveas(axes5,'05_MeanViewTime_RoundAge- Inf&Todd.fig');
saveas(axes5,'05_MeanViewTime_RoundAge- Inf&Todd.eps');

%%%%%%%%%%%%%%%%

%%
%%%%%%%%%%%%%%%%
%5a: Mean duration of sessions within each lab, by year

for i=1:length(binnedAgeGroups)
    graph5a=[];
    
    for ii = 1:size(rUnqYears,1)
        viewingTime=sampleCounts(rYears==rUnqYears(ii) & rBinnedAges>=binnedAgeGroups(i).minAge & rBinnedAges<=binnedAgeGroups(i).maxAge)/(30*60);
        n=length(viewingTime);
        stderr=std(viewingTime)/sqrt(n);
        graph5a=[graph5a;rUnqYears(ii),mean(viewingTime),stderr,n];
    end

    figure();
    axes5a=axes('XTick',graph5a(:,1),'XTickLabel',graph5a(:,1)+2000);
    hold(axes5a,'all');
    bar(axes5a,graph5a(:,1),graph5a(:,2),'w');
    errorbar(graph5a(:,1),graph5a(:,2),graph5a(:,3),'.');
    xlabel('Year','FontSize',13);
    ylabel('Viewing Time (min)','FontSize',13);
    title(['Mean Viewing Time (',num2str(binnedAgeGroups(i).minAge),'-',num2str(binnedAgeGroups(i).maxAge),' month olds)'],'FontSize',15);
    
    saveas(axes5a,['05a_MeanViewTime_Year- ',binnedAgeGroups(i).title,'.fig']);
    saveas(axes5a,['05a_MeanViewTime_Year- ',binnedAgeGroups(i).title,'.eps']);
end

%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%
%GRAPH6: duration of viewing time (count of participants by viewing time)
%{
%%


indViewTime=round(sampleCounts/(30*60)); %CR EDIT - make sure it's 30, not 60!!!
viewTimeRange=0:max(indViewTime);
graph6=[];
for ii=viewTimeRange
    graph6=[graph6;ii,sum(indViewTime==ii)];
end
    
figure();
axes6=axes();
hold(axes6,'all');
bar(axes6,graph6(:,1),graph6(:,2)); 
xlabel('Viewing time (min)','FontSize',13);
ylabel('Number of sessions','FontSize',13);
title({'Number of Sessions per Viewing Time'},'FontSize',15);

saveas(axes6,'06_NumSessions_ViewTime.fig');
saveas(axes6,'06_NumSessions_ViewTime.eps');
%%%%%%%%%%%%%%%%

%}

%% Clean up

%move all the .fig files to a subfolder
[~,~]=mkdir('figs');
movefile('*.fig','figs/');

close all
disp(' ')
disp(['Graphs saved in ',graphDir]);

end

cd(origDir)
disp(' ')
disp('---------------------------------------------------Done---------------------------------------------------')