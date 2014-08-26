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
% See also AUDITQUERY, ETLAUDITGRAPHS

% Written by Carolyn Ranti 8.15.2014
% CVAR 8.19.14

%%
assert(logical(exist(filename,'file')),['Error in ReadInQuery: cannot find the results file ',filename]);

fid = fopen(filename);

% Get column headers
line = fgetl(fid);
fields = strsplit(line,','); %preserves whitespace

%line by line
data={};
rowIndex=1;
line = fgetl(fid);
while ischar(line)
    tempData = strsplit(line,',','CollapseDelimiters',false); %split out columns using commas - do not collapse delimiters
    
    for colIndex=1:length(tempData)
        tempData{colIndex}=sscanf(tempData{colIndex},'%s'); %squeeze out white space 
        
        % If the column name includes keyword "array", read in as cell
        % Convert to numbers if possible
        if strfind(lower(fields{colIndex}),'array')
            %split out protocols using delimiter inserted by python script
            data{rowIndex,colIndex}=strsplit(tempData{colIndex}(2:end-1),{'###'}); 
            %convert to number if possible
            for i=length(data{rowIndex,colIndex})
                [numVersion]=str2double(data{rowIndex,colIndex}(i)); 
                if ~isnan(numVersion)
                    data{rowIndex,colIndex}(i)=numVersion;
                end
            end
            
        % Process dates -- array as numbers [Y M D]
        % Works for excel and database format (M(M)/D(D)/YY or YYYY-MM-DD)
        elseif strfind(lower(fields{colIndex}),'date')
            
            if isempty(tempData{colIndex})
                data{rowIndex,colIndex} = [-1 -1 -1]; %if date is missing, flag with -1s
            else
                temp = strsplit(tempData{colIndex},'/');
                if length(temp)==3
                    mo = temp{1};
                    temp{1} = temp{3}; %year
                    temp{3} = temp{2};
                    temp{2} = mo;
                else
                    temp = strsplit(tempData{colIndex},'-'); %in the right order
                end
                temp = cellfun(@str2num,temp);
                data{rowIndex,colIndex} = temp;
            end
            
        % Convert data to numbers if possible
        else
            if ~isempty(tempData{colIndex})
                %convert to number if possible
                [numVersion] = str2double(tempData{colIndex}); 
                if isnan(numVersion)
                    data{rowIndex,colIndex} = tempData{colIndex};
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