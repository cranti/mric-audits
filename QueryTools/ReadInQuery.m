function [fields,data] = ReadInQuery(filename)
%READINQUERY
% 
% Read in a csv file (filename) with headers and data from a database
% query. The query is converted to a cell, preserving the row/column
% organization. Headers are output in the cell FIELDS, with columns that
% correspond to those in DATA. Data converted to numbers if possible,
% otherwise preserved as strings, with the exception of the following two
% special cases:
%   - If the column title contains "date", that column of data will be
%       converted to [Y M D]. Can handle dates that are formatted in MRIC's
%       output format (YYYY-MM-DD) or Excel's default (M(M)/D(D)/YY)
%   - If the column title contains "array", each item in the column is placed
%       in a cell, and split into individual entries using the delimiter
%       ###. This corresponds to the output of the script flexibleQuery.py
%
% NOTE: to make this script compatible with P&T computer (ie MATLAB2012),
%   replace strsplit with strsplit_CR
%
% See also AUDITQUERY, ETLAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 9.25.14

%%
assert(logical(exist(filename,'file')),'QueryTools:fileNotFound',['Error in ReadInQuery: ',filename,' does not exist']);

if ~strcmpi(filename((end-3):end),'.csv')
   warning(['File name (',filename,') does not end with ''.csv'' - ReadInQuery may not work properly.']); 
end

fid = fopen(filename);

% Get column headers
line = fgetl(fid);
fields = strsplit(line,','); %preserves whitespace

%line by line
data={};
rowIndex=1;
line = fgetl(fid);
while ischar(line)
    
    %split out columns using commas - do not collapse delimiters
    row = strsplit(line,',','CollapseDelimiters',false); 
    
    for colIndex=1:length(row)
        entry = sscanf(row{colIndex},'%s'); %squeeze out white space 
        
        % If the column name includes keyword "array", read in as cell
        % (& convert to numbers if possible). MRIC sandwiches arrays in [ ]
        % -- remove these if present
        if strfind(lower(fields{colIndex}),'array')
            if strcmpi(entry,'[]')
                data{rowIndex,colIndex}={};
            elseif ~isempty(entry)
                %remove '[' and ']' from beginning and end
                if strcmp(entry(1),'[')
                    entry = entry(2:end);
                end
                if strcmp(entry(end),']')
                    entry = entry(1:end-1);
                end

                %split out protocols using delimiter inserted by python script
                data{rowIndex,colIndex}=strsplit(entry,{'###'}); 

                %convert to number if possible
                for i=1:length(data{rowIndex,colIndex})
                    [numVersion]=str2double(data{rowIndex,colIndex}(i)); 
                    if ~isnan(numVersion)
                        data{rowIndex,colIndex}{i}=numVersion;
                    end
                end
            else
                data{rowIndex,colIndex}={};
            end
        % Process dates -- array as numbers [Y M D]
        % Works for excel and database format (M(M)/D(D)/YY or YYYY-MM-DD)
        elseif strfind(lower(fields{colIndex}),'date')
            
            if isempty(entry)
                data{rowIndex,colIndex} = [-1 -1 -1]; %if date is missing, flag with -1s
            else
                try
                    temp = strsplit(entry,'/');
                    if length(temp)==3
                        mo = temp{1};
                        temp{1} = temp{3}; %year  %TODO: what if year is only 2 digits?
                        temp{3} = temp{2};
                        temp{2} = mo;
                    else
                        temp = strsplit(entry,'-'); %in the right order
                    end
                    if length(temp{1}) == 2
                        warning('Date had a year that was only 2 digits -- assumed to be in the 2000s, but reformat the dates if this is not true'); 
                        temp{1} = ['20',temp{1}];
                    end
                    temp = cellfun(@str2num,temp);
                    data{rowIndex,colIndex} = temp;
                catch
                    warning(['Date not converted properly. Entry: ',entry]);
                    data{rowIndex,colIndex} = [-1 -1 -1]; %if date is missing, flag with -1s
                end
            end
            
        % Convert data to numbers if possible, or insert place holder 
        else
            if ~isempty(entry)
                %convert to number if possible
                [numVersion] = str2double(entry); 
                if isnan(numVersion)
                    data{rowIndex,colIndex} = entry;
                else
                    data{rowIndex,colIndex} = numVersion;
                end
            else
                data{rowIndex,colIndex} = [];
            end
        end
    end
    
    rowIndex = rowIndex+1;
    line = fgetl(fid);
end

%Remove "array" from column names, strip whitespace
fields = cellfun(@(x) strrep(x,'array',''),fields,'UniformOutput',false);
fields = cellfun(@(x) sscanf(x,'%s'),fields,'UniformOutput',false);

fclose(fid);