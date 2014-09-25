function [fields,data] = AddBinnedAge(fields,data,monthAgeCol)
%ADDBINNEDAGE
%
% Add binned ages column to DATA, output updated DATA and FIELDS (with new
% column header, "BinnedAge"). Looks for ages to round in the column 
% specified by the input MONTHAGECOL. Ages are binned such that the actual
% age matches what visit the child was probably fulfilling. 
% Will not make any changes to DATA or FIELDS if there is already a column
% called BinnedAge.
% Flags missing ages or non-numbers with -1. Warns user if there are
% strings or nested cells in the column specified.
%
% See also AUDITQUERY, READINQUERY

% Written by Carolyn Ranti
% CVAR 9.25.2014

%% Check input
assert(size(data,2)==size(fields,2),'QueryTools:badInput','Error in AddBinnedAge: DATA and FIELDS must have the same number of columns.');

%% Bin ages

% is there a column called binned age? if so, don't change data or fields -- output as is.
existBinAgeCol = sum(strcmpi('BinnedAge',fields));

if ~existBinAgeCol
    OrigAges = data(:,monthAgeCol);
    
    %get rid of strings in the column
    isString = cellfun(@isstr,OrigAges);
    if sum(isString)>0
       warning('Age column contains strings - these entries will not be binned!');
       OrigAges(isString) = {-1};
    end
    
    %get rid of nested cells in the column
    isCell = cellfun(@iscell,OrigAges);
    if sum(isCell)>0
       warning('Age column contains nested cells - these entries will not be binned!');
       OrigAges(isCell) = {-1};
    end
    
    
    temp=cellfun(@round,OrigAges,'UniformOutput',false);
    temp(cellfun(@isempty,temp))={-1}; %convert empty cells to -1
    temp=cell2mat(temp);

    temp(temp==7) = 6;
    temp(temp>7&temp<=10) = 9;
    temp(temp>10&temp<=13) = 12;
    temp(temp>13&temp<=16) = 15;
    temp(temp>16&temp<=20) = 18;
    temp(temp>20&temp<=29) = 24;
    temp(temp>29&temp<=42) = 36;

    %SCHOOL AGE BINNING -- to year.
    temp(temp>42) = round(temp(temp>42)/12)*12;

    data(:,size(data,2)+1)=num2cell(temp);
    fields{1,size(data,2)}='BinnedAge';
end