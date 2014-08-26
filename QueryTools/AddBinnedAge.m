function [fields,data] = AddBinnedAge(fields,data,monthAgeCol)
%ADDBINNEDAGE
%
% Add binned ages column to DATA, output updated DATA and FIELDS. Looks for
% ages to round in the column specified by the input MONTHAGECOL. Ages are
% binned such that the actual age matches what visit the child was probably
% fulfilling.
%
% See also AUDITQUERY, READINQUERY

% Written by Carolyn Ranti
% CVAR 8.21.2014

%% Error checking
assert(size(data,2)==size(fields,2),'Error in AddBinnedAge: DATA and FIELDS must have the same number of columns.');


%%

temp=cellfun(@round,data(:,monthAgeCol),'UniformOutput',false);
temp(cellfun(@isempty,temp))={-1}; %convert empty cells to -1 (flag for ages that aren't in database)
temp=cell2mat(temp);

temp(temp==7) = 6;
temp(temp==8) = 9;
temp(temp==10) = 9;
temp(temp==11) = 12;
temp(temp==13) = 12;
temp(temp==14) = 15;
temp(temp==16) = 15;
temp(temp==17) = 18;
temp(temp==19) = 18;
temp(temp==20) = 18;
temp(temp>20&temp<=29) = 24;
temp(temp>29&temp<=42) = 36;

%SCHOOL AGE BINNING -- to year
temp(temp>=54&temp<72) = 60; 
temp(temp>=72&temp<84) = 72;
temp(temp>=84&temp<96) = 84;
temp(temp>=96&temp<108) = 96;
temp(temp>=108&temp<120) = 108;
temp(temp>=120&temp<132) = 120;
temp(temp>=132&temp<144) = 132;
temp(temp>=144&temp<156) = 144;
temp(temp>=156&temp<168) = 156;
temp(temp>=168&temp<180) = 168;
temp(temp>=180&temp<192) = 180;
temp(temp>=192&temp<204) = 192;
temp(temp>=204&temp<216) = 204;
temp(temp>=216&temp<228) = 216;

data(:,size(data,2)+1)=num2cell(temp);
fields{1,size(data,2)}='BinnedAge';