#!/usr/bin/python

""" dataquery.py
Version 5.2

    This script runs data queries that are useful for ETL audits.
    
    When the script is run, it asks for a username and password for the MRIC database,
    a start date for the query, and an end date. The following queries are run:
        
        1) Session query
            > Table: /session
            > Filter: specified date range.
            > Columns returned:
            'Date','Protocol','Iscan Type','ID','Matlab ID','Session number','Age (months)',
            'Quality','Fellows','Number of clips'
        2) Run query
            > Table /run
            > Filter: specified date range.
            > Columns returned:
            'Date','Session ID','Protocol','Age (months)','Quality','Clip','Status',
            'Sample count','Fix count','Lost count'
        3) Phase editor query
            > Table: /requirement
            > Filter: participants returned in Query 1, phase must include 
            "compensation" or "tracking"
            > Columns returned:
            'Matlab ID', 'ID', 'Study Code', 'Protocol', 'Enrollment Date', 'Phase', 'Requirement', 
            'Status', 'Ideal Date', 'Fulfillment Date'
    
    The script creates a CSV file for each of the queries, all saved in a subdirectory of
    QUERY_PATH. The CSV files are named by the range of dates for the query and a keyword
    If the subdirectory already exists, the script will not run the query again - it will
    inform the user that they should rename or delete that folder if they want to run the 
    query again.

    After running the query and saving the results, the script will ask the user if they
    want to run another query. If the user says yes, the script will prompt them again for 
    start/end dates. 

    Start and end dates can also be specified as command line arguments (in same format).
    If the dates are specified in this way, the script will exit after the first query -
    aka it will not give the user the option to run queries on additional date ranges.


    ****HISTORY****
    (see Versions for more details)

    V2 UPDATES
    - Outputting protocols
    - Added session_rollup query
   
    V3 UPDATES (3.2014, 4.2014)
    - Added phase editor query (so we can check if we phase edited properly). 
    - Pulls session notes out separately - saving in a separate csv
    - Removed session_rollup query, added run query.
        
    V4 UPDATES (4.25.2014)
    - Cleaned up code (during/post BNR)
    - Fixed phase query (description above not updated)
    - Parsing Protocol column within the script -- it's important that the column is returned
    from MRIC with the header 'Protocol' in order to capture this.
    - FIXED: Run query has issues with queries spanning multiple years

    V5 UPDATES (5.21.2014, )
    5.21.2014 V5.0
    - Queries are run in full access
    - Phase and notes queries are optional
    6.27.14 V5.1
    - Changed the phase query, so that it finds all subjects who have had compensation AND/OR
    eye-tracking phases completed in the last week. This should fix ambiguity in weekly check script.
    8.13.14 V5.2
    - Removed notes query, and it's no longer an option to run only some queries

    ***************

    Written by Carolyn Ranti, Feb 2014

    - EDIT - make the list parsing (currently just for Protocol output) more flexible

"""

import os, sys
import re
import csv, time, datetime
from sys import stdin, stdout
from time import sleep
from htsql_client import login, HTSQL_Error
from htsql.identifiers import escape, quote

###
#where the csv files are saved, and the suffix for the filename
QUERY_PATH = '/Users/etl/Desktop/DataQueries/'
RESULTSFILE = '.csv'
###

def _login(u=None, p=None , perspective='full_access'):
    """Log into the HTSQL server"""
    return login("https://marcus-ric.rexdb.net", u, p,perspective='full_access')

def datecheck(date,delim='-'):
    '''
    Check that date is formatted properly. If so, return None. If not, return 
    string explaining the issue.
    '''
    if len(date)!=10:
        return delim.join(("Incorrect length. Format must be YYYY","MM","DD"))
    elif not (date[4]==delim and date[7]==delim): #dashes in the right spots
        return delim.join(("Format must be YYYY","MM","DD"))
    (y,m,d)=date.split(delim)
    if not (y.isdigit() and m.isdigit() and d.isdigit()): #all are numbers:
        return "Error converting to numbers"
    try:
        datetime.date(int(y),int(m),int(d))
    except ValueError, e:
        return e
    return None

def datestr_conv(date,delim='-'):
    '''
    Convert date to tuple of three integers [Y, M, D]
    '''
    (y,m,d)=date.split(delim)
    return int(y),int(m),int(d)

def getdatestr():
    '''
    Read in date from user input. If it's not formatted properly, raise an exception.
    '''
    date = stdin.readline().strip()
    # if not date:
    #     date = '-'.join([str(a) for a in datetime.date.today()]
    if datecheck(date):
        raise RuntimeError("Invalid date format: " + datecheck(date))
    return date

def print_headers(csv_writer,keyOrder): 
    csv_writer.writerow(keyOrder)
    return

def print_query(csv_writer,queryResult,keyOrder):
    keymap=dict(zip(keyOrder,range(1,len(keyOrder)+1)))

    # fix the protocol output so that MATLAB can deal with it more easily...
    if 'Protocol' in keyOrder:
        for row in queryResult:
            temp = row['Protocol']
            if type(temp)==list:
                temp = [str(t) for t in temp]
            else:
                temp = [str(temp)]
            row['Protocol'] = '['+"###".join(temp)+']'

    if 'Fellows' in keyOrder:
        for row in queryResult:
            if row['Fellows']:
                row['Fellows']=row['Fellows'].replace(',','&')

    for row in queryResult:
        ordered_values = [row[key] for key in keyOrder]
        csv_writer.writerow(ordered_values)
        #EDIT! try/catch UnicodeEncodeError
    return

##write queries in here:
def main(fetch,argsin=None):
    ORIG_PATH=os.getcwd()

    if argsin:
        startdate=argsin[0]
        enddate=argsin[1]
    else:
        stdout.write("Enter start date for the range you're querying (YYYY-MM-DD) >> ")
        startdate = getdatestr()
        stdout.write("\nEnter end date for the range you're querying (YYYY-MM-DD) >> ") #EDIT! add this functionality: , or press enter to use today's date. >> ")
        enddate = getdatestr()
    
    # additional date checks
    (startyear, startmonth, startday) = datestr_conv(startdate)
    (endyear, endmonth, endday) = datestr_conv(enddate)
    if datetime.date(startyear,startmonth,startday) > datetime.date(endyear, endmonth, endday):
        raise RuntimeError("Start date must be earlier than or equal to end date")
    elif datetime.date.today() < datetime.date(endyear, endmonth, endday):
        raise RuntimeError("End date must be earlier than or equal to today")
    
    #create dir for results
    DATE_QUERY_PATH = QUERY_PATH+startdate+'_'+enddate
    if not os.path.exists(DATE_QUERY_PATH):
        os.mkdir(DATE_QUERY_PATH)
    # else:
        # print "\n  ** Looks like this query has already been run!"
        # print "  ** Rename or delete folder %s and try again.\nExiting.\n" % DATE_QUERY_PATH
        # sys.exit(-1)
        # return

    os.chdir(DATE_QUERY_PATH)

    #################################
    ##QUERY 1 - session table    
    queryResult_session=fetch("/session{date title 'Date'+, array(individual.participation.protocol) title 'Protocol',\
        iscan_type title 'Iscan Type', individual.id() title 'ID', individual.matlab_id title 'Matlab ID', \
        code title 'Session number', age_testing_months title 'Age (months)', quality title 'Quality', \
        experimenter title 'Fellows', count(run.clip) title 'Number of clips'} \
        ?date>=%s&date<=%s",startdate,enddate)
    
    #orderOfKeys must exactly match the queryResult keys! if query is changed, this line must also change to match it.
    #This is the order that will be used to print the results to a file 
    orderOfKeys_session=['Date','Protocol','Iscan Type','ID','Matlab ID',
    'Session number','Age (months)','Quality','Fellows','Number of clips']
    
    #open file that results of query will be written out to
    filename=''.join(('session_',startdate,'_',enddate,RESULTSFILE))
    with open(filename,'w') as f:
        f_csv = csv.writer(f)
        print_headers(f_csv,orderOfKeys_session)
        print_query(f_csv,queryResult_session,orderOfKeys_session)
    
    #################################
    ##QUERY 2 - run level query, to return fix/lost % for each clip. Replaces rollup query.
    #Because the query is so large, running it in chunks (month by month) and adding to the csv.

    orderOfKeys_run=['Date','Session ID','Protocol','Age (months)','Quality','Clip','Status','Sample count','Fix count','Lost count']
    
    filename_run=''.join(('run_',startdate,'_',enddate,RESULTSFILE))
    f = open(filename_run,'w')
    f_csv=csv.writer(f)
    
    firstLoop=1
    for year in xrange(startyear,endyear+1):
        if year==endyear: lastmonth=endmonth
        else: lastmonth=12
        
        if firstLoop: firstmonth = startmonth
        else: firstmonth = 1

        for month in xrange(firstmonth,lastmonth+1):
                
            #first loop, start with the startday, and include it
            if firstLoop: 
                loopStartDay=str(startday).zfill(2)
                startDateChar = '>='
            #otherwise, start with 1st day of the month, and don't include it
            else: 
                loopStartDay='01'
                startDateChar = '>'
            
            loopStartMonth=str(month).zfill(2)
            
            #for last loop, end with endday (in the same month as the starting date!)
            if year==endyear and month==endmonth: 
                loopEndYear=str(year)
                loopEndMonth=str(month).zfill(2)
                loopEndDay=str(endday).zfill(2)
                    
            elif month==12:
                loopEndYear=str(year+1)
                loopEndMonth='01'
                loopEndDay='01'
            else:
                loopEndYear=str(year)
                loopEndMonth=str(month+1).zfill(2)
                loopEndDay='01'
            
            startdate_run='-'.join((str(year),loopStartMonth,loopStartDay))
            enddate_run='-'.join((loopEndYear,loopEndMonth,loopEndDay))

            #compile query outside of fetch
            runQuery="/run{session.date title 'Date',session title 'Session ID',\
                array(session.individual.participation.protocol) title 'Protocol',session.age_testing_months title 'Age (months)',\
                session.quality title 'Quality',clip title 'Clip',status title 'Status',run_data.sample_count title 'Sample count',\
                run_data.fixation title 'Fix count',run_data.lost title 'Lost count'} \
                ?session.date%s'%s'&session.date<='%s'" % (startDateChar,startdate_run,enddate_run)
            
            queryResult_run=fetch(runQuery)
            if firstLoop:
                print_headers(f_csv,orderOfKeys_run)
                firstLoop=0
            print_query(f_csv,queryResult_run,orderOfKeys_run)

    f.close()

    
    #################################
    ##QUERY 3 - phase editor. First run a prelim query, finding all participants who were paid in the 
    # date range in question. Then run the real query, which looks for compensation AND eye tracking sessions for those
    # ID/phase/protocol combinations returned from the prelim query. 
    # NB: returns extra compensation requirements from people who were paid for reasons other than eye-tracking

    #query: who was paid within this date range?
    phaseQuery_prelim= "/requirement{phase.participation.individual title 'ID',\
    phase.participation.protocol title 'Protocol',\
    requirement_type.phase_type.title title 'Phase',fulfillment_date title 'FulDate'}?\
    ((requirement_type.title~'Compensation')&fulfillment_date>='"+startdate+"'&fulfillment_date<='"+enddate+"')|\
    ((requirement_type.title~'tracking')&fulfillment_date>='"+startdate+"'&fulfillment_date<='"+enddate+"')"
    phase_prelim = fetch(phaseQuery_prelim)


    #note: removing "Day..." from phases, so that it returns all eyetracking sessions (not just the day when they were compensated)
    PhaseFilters = ["(phase.participation.individual = '{ID}' & requirement_type.phase_type.title ~ '{Phase}'\
        & phase.participation.protocol='{Protocol}')".format(ID=row['ID'],Phase=re.split('Day',row['Phase'])[0],Protocol=row['Protocol']) for row in phase_prelim]
    PhaseFilters = '|'.join(PhaseFilters)
    #return the eye-tracking sessions for all of the unique ids in the 

    
    #compile query outside of function call
    phaseQuery="".join(("/requirement{fulfillment_date title 'Fulfillment Date'+,phase.participation.individual title 'ID',\
        phase.participation.individual.matlab_id title 'Matlab ID',phase.participation.protocol.study.code title 'Study Code',\
        phase.participation.protocol title 'Protocol',phase.participation.enrollment_date title 'Enrollment Date',\
        requirement_type.phase_type.title title 'Phase',requirement_type.title title 'Requirement',status title 'Status',\
        phase.ideal_date title 'Ideal Date'}?\
        (",PhaseFilters,")&((requirement_type.title=~'tracking'&status!='skipped')|(requirement_type.title=~'compensation'))")) 
    
    queryResult_phase=fetch(phaseQuery)  
    orderOfKeys_phase=['Matlab ID', 'ID', 'Study Code', 'Protocol', 'Enrollment Date', 'Phase', 'Requirement', 'Status', 'Ideal Date', 'Fulfillment Date']
    
    filename_phase=''.join(('phase_',startdate,'_',enddate,RESULTSFILE))
    with open(filename_phase,'w') as f:
        f_csv=csv.writer(f)
        print_headers(f_csv,orderOfKeys_phase)
        print_query(f_csv,queryResult_phase,orderOfKeys_phase)

    #################################

    os.chdir(ORIG_PATH)
    print "Queries complete. Results saved in %s" % (DATE_QUERY_PATH)


if '__main__' == __name__:
    import getpass
    q = True
    print "**Log in to MRIC**"
    stdout.write("Username: ")
    u = stdin.readline().strip()
    p = getpass.getpass("Password: ").strip()
    
    try:        
        fetch = _login(u, p,perspective='full_access') #EDIT: should be able to change perspective here/through fxn above, if needed
    except Exception, err: #EDIT: this is bad form! but it's unavoidable b/c of htsql_client!
        print "sorry, wrong username or password. \n more::", err
        sys.exit(-1)
        q = False
    
    # If 2 command line arguments are entered when the script is called, only one query will be 
    # run, assuming that the args are start date & end date.
    # With no command line arguments: prompt the user to enter dates & provide option of running multiple queries.
    if len(sys.argv)==3:
        main(fetch,sys.argv[1:3])
        print "Goodbye!"
    else:
        while q:
            main(fetch)
            stdout.write("Do you wish to run another query (y or n)? ")
            ans = stdin.readline().strip()
            q = (ans in ['y','Y'])
            print "Goodbye!"