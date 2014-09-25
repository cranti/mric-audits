function [fields,data] = AddWeekStart(fields,data,dateCol,startDay)
%ADDWEEKSTART
%
% Add week start column to data, output updated data and fields (with
% new column header "WeekStart"). Will not make any changes to DATA or
% FIELDS if there is already a column called WeekStart.
% Dates must be in vector form ([Y M D]).
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
% CVAR 9.25.2014

%% Check input
assert(size(data,2)==size(fields,2),'QueryTools:badInput','Error in AddWeekStart: DATA and FIELDS must have the same number of columns.');

if nargin==3
    startDay='mon';
end
assert(sum(strcmpi(startDay,{'mon','tue','wed','thu','fri','sat','sun'}))==1,'QueryTools:badInput',...
    'Error in AddWeekStart: startDay must be the first 3 letters of a day of the week.');

%%

% is there already a column called WeekStart? if so, output fields and data
% without any changes.
existWeekStartCol = sum(strcmpi('WeekStart',fields));
if ~existWeekStartCol

    temp = cell(size(data,1),1);
    for ii = 1:size(data,1)
        theDate = data{ii,dateCol};
        
        %check formatting
        if isnumeric(theDate) && size(theDate,1)==1 && size(theDate,2)==3 && sum(theDate)>0
            
            weekStart=datenum(theDate);
            
            if weekStart<datenum([1980,1,1])
                warning('Found a date earlier than Jan 1, 1980 - there may be a formatting error');
            elseif weekStart>today
                warning('Found a date that is in the future - there may be a formatting error');
            end
            
            %find the first day of that week
            n = 0;
            while ~strcmpi(datestr(weekStart,'ddd'),startDay) && n<7
                weekStart=weekStart-1;
                n = n+1; %limit to 7 iterations
            end
            [Y,M,D]=datevec(weekStart);
        elseif sum(theDate)<=0
            warning('Missing date.');
            Y = -1;
            M = -1;
            D = -1;
        else %if date is not formatted properly, make the week start -1 -1 -1
            warning('Error in date conversion.');
            Y = -1;
            M = -1;
            D = -1;
        end
        temp(ii)={[Y,M,D]};
    end

    data(:,size(data,2)+1) = temp;
    fields{1,size(data,2)} = 'WeekStart';
end