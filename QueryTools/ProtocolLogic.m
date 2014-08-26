function [allProtocols,protLogic] = ProtocolLogic(data,colNum)
%PROTOCOLLOGIC
%
% DATA is
% COLNUM must be a column of DATA with cells (each w/ 0 or more strings).
% This script finds the unique items in the entire column of data
% (ALLPROTOCOLS) and creates a logical matrix (PROTLOGIC) indicating
% whether each unique item appears in the row of DATA. PROTLOGIC has one
% column per item in ALLPROTOCOLS, and the rows correspond to the rows of
% DATA.
%
% Written to be used with arrays of protocols, but could be used for any
% similarly organized data.
%
% See also AUDITQUERY, READINQUERY

% Written by Carolyn Ranti
% CVAR 8.21.2014

%finish documenting!

%%
%Find unique protocols 
allProtocols={};
for ii=1:size(data,1)
    for i2=1:size(data{ii,colNum},2)
        if ~isempty(data{ii,colNum}{i2})
        	allProtocols={allProtocols{:},data{ii,colNum}{i2}};
        end
    end
end    
allProtocols=unique(allProtocols);

%make logical array: [# sessions]x[# unique protocols]
protLogic=false(size(data,1),length(allProtocols));

for ii=1:size(data,1) %for every row in data
    for i2=1:length(data{ii,colNum}) %for every protocol in the row
        if ~isempty(data{ii,colNum}{i2})
            protPositions = strcmp(data{ii,colNum}{i2},allProtocols);
            protLogic(ii,protPositions) = true; 
        end
    end
end