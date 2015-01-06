%BINDATES Returns bins for dates between a provided start date and end
%date. Bin size can be week, month, or 3 months (specified by user).
%
%INPUTS
%   startDate -- [Y M D] (integers)
%   endDate -- [Y M D] (integers)
%   binSize -- 'week', 'month', or '3months'
%
%OUTPUTS
%   bins -- nx3 matrix. Row for each bin, date formatted Y M D
%
% Note - last bin will be greater than or equal to the endDate provided.
%
% Currently very little error checking. 

% Written by Carolyn Ranti 1.6.2015


function bins = BinDates(startDate, endDate, binSize)

bins = [];
switch binSize
    case 'week'
        currDate = startDate;
        while currDate <= endDate
            [YEAR, MONTH, DAY] = datevec(currDate);
            bins = [bins; YEAR, MONTH, DAY];
            currDate = currDate + 7;
        end
        
    case 'month'
        if year(startDate) == year(endDate)
            YEAR = year(startDate);
            for MONTH = month(startDate):month(endDate)
                bins = [bins; YEAR, MONTH, 1];
            end
        else
            YEAR = year(startDate);
            while YEAR <= year(endDate)
                if YEAR == year(startDate)
                    startMonth = month(startDate);
                else
                    startMonth = 1;
                end
                if YEAR == year(endDate)
                    endMonth = month(endDate);
                else
                    endMonth = 12;
                end
                
                for MONTH = startMonth:endMonth
                    bins = [bins; YEAR, MONTH, 1];
                end
                YEAR = YEAR + 1;
            end
        end
        
    case '3months'
        MONTH = month(startDate);
        YEAR = year(startDate);
        while YEAR <= year(endDate)
            %if MONTH is >12, mod and iterate year
            if MONTH > 12
                MONTH = mod(MONTH-1,12)+1;
                YEAR = YEAR + 1;
            end
            
            %break if out of the date range
            if (YEAR == year(endDate) && MONTH > month(endDate))
                break
            end
            
            bins = [bins; YEAR, MONTH, 1];
            MONTH = MONTH + 3;
        end
        
    otherwise
        error('Error in BinDates: unexpected value for binSize');
end