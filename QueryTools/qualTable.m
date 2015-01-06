%QUALTABLE - Create a summary table with the number of sessions per quality
% rating (0-5) for the latest time bin and the total number across all time
% bins.
% 
% Inputs: 
%   > weekStarts - dates that will be used to bin qualities. Must be
%           an nx3 matrix, with Y M D in each row. 
%   > qualities - nx1 vector with quality ratings (0-5). Rows correspond to
%       weekStarts.
%   > filename (str, optional) - name of file to write out summary to. If
%       this is not included, table will be printed to command window.
%
% Note: excludes sessions with missing dates 

% Written by Carolyn Ranti 1.5.2015
% TODO - clean up doc, error checking

function output = qualTable(weekStarts, qualities, filename)

%% error checking
% weekStarts must have 3 columns
% weekStarts and qualities must be same # rows
% filename must end in .csv or no extension

%%
%find the latest week
unqWeekStarts = unique(weekStarts,'rows');
unqWeekStarts = unqWeekStarts(sum(unqWeekStarts,2)>0,:); % exclude sessions w/ missing dates
unqWeekStarts = sortrows(unqWeekStarts,[1,2,3]);
thisWeek = datenum(unqWeekStarts(end,:));

weekStarts = datenum(weekStarts);

output = zeros(2,6);
for ii = 0:5
    output(1,ii+1) = sum(qualities==ii & weekStarts==thisWeek);
    output(2,ii+1) = sum(qualities==ii);
end


%if a filename is entered, write out the summary table. otherwise, print to
%command window
if nargin == 3
    fid = fopen(filename,'w');
else
    fid = 1;
end
fprintf(fid, 'N per Quality Rating\n\n');
fprintf(fid, ',0,1,2,3,4,5\n');
fprintf(fid, '%s,', sprintf('Bin starting %s',datestr(thisWeek,'mm-dd-yyyy')));
fprintf(fid, '%i, %i, %i, %i, %i, %i\n', output(1,:));
fprintf(fid, 'Total,');
fprintf(fid, '%i, %i, %i, %i, %i, %i\n', output(2,:));
