function [fields,data] = AddWeekStart(fields,data,dateCol,startDay)
%ADDWEEKSTART
%
% Add week start column to data, output updated data and fields (with
% new column header "WeekStart"). Will not make any changes to DATA or
% FIELDS if there is already a column called WeekStart.
%
% USAGE AddWeekStart(fields, data, dateCol) -- finds the Monday before each
%           date, adds the date as a vector [Y M D] to a new column of data
%           (preserving row). 
%       AddWeekStart(fields, data, dateCol, startDay) -- allows the user to
%           specify which day of the week should be considered the first.
%           Enter as a string with the first three letters of the day of
%           week (e.g. 'Sun', 'Mon', etc.) Case insensitive.
%
% See also AUDITQUERY, READINQUERY

% Written by Carolyn Ranti
% CVAR 9.5.2014

%%
assert(size(data,2)==size(fields,2),'Error in AddWeekStart: DATA and FIELDS must have the same number of columns.');

%%

% is there already a column called WeekStart? if so, output fields and data
% without any changes.
existWeekStartCol = sum(strcmpi('WeekStart',fields));
if ~existWeekStartCol
    if nargin==3
        startDay='mon';
    end

    temp = cell(size(data,1),1);
    for ii = 1:size(data,1)

        if sum(data{ii,dateCol})<0 %missing dates flagged with -1s
            Y = -1;
            M = -1;
            D = -1;
        else
            weekStart=datenum(data{ii,dateCol});
            %find the first day of that week
            while ~strcmpi(datestr(weekStart,'ddd'),startDay)
                weekStart=weekStart-1;
            end
            [Y,M,D]=datevec(weekStart);
        end
        temp(ii)={[Y,M,D]};
    end

    data(:,size(data,2)+1) = temp;
    fields{1,size(data,2)} = 'WeekStart';
end