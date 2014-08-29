#!/usr/bin/python

""" weeklyCheckQuery.py

    This script runs data queries that are useful for ETL weekly audits.
    
    When the script is run, it asks for a username and password for the MRIC database,
    a start date for the query, and an end date. The following queries are run:
        
        1) Session query
            > Table: /session
            > Filter: specified date range.
            > Columns returned:
            'Date','Protocol array','Iscan Type','ID','Matlab ID','Session number','Age (months)',
            'Quality','Fellows','Number of clips'
        2) Phase editor query
            > Table: /requirement
            > Filter: participants returned in Query 1, phase must include 
            "compensation" or "tracking"
            > Columns returned:
            'Matlab ID', 'ID', 'Study Code', 'Protocol', 'Enrollment Date', 'Phase', 'Requirement', 
            'Status', 'Ideal Date', 'Fulfillment Date'
    
    The script creates a CSV file for each of the queries, all saved in a subdirectory of
    QUERY_PATH. The subdirectory is named by start and end date (e.g. 2014-08-01_2014-08-14).
    The CSV files are also named by the range of dates for the query plus a keyword 
    (e.g. session_2014-08-01_2014-08-14).

    After running the query and saving the results, the script will ask the user if they
    want to run another query. If the user says yes, the script will prompt them again for 
    start/end dates. 

    Start and end dates can also be specified as command line arguments (in same format).
    If the dates are specified in this way, the script will exit after the first query -
    aka it will not give the user the option to run queries on additional date ranges.

    * There is a function defined for a run table query, but not currently running it (b/c
    it isn't being used for our weekly checks).

    ***************
    
    Carolyn Ranti, 8.25.2014. Adapted from dataquery.py (V5.2)
"""

import os, sys
import re
import csv, time, datetime
import getpass
from sys import stdin, stdout
from htsql_client import login

###
ORIG_PATH=os.getcwd()
QUERY_PATH = '/Users/etl/Desktop/DataQueries/WeeklyChecks/' #where results are saved
RESULTSFILE = '.csv' # suffix for the filename
###

def _login(u=None, p=None, perspective='full_access'):
    """ Log in to MRIC """
    if not u or not p:
        print "**Log in to MRIC**"
        stdout.write("Username: ")
        u = stdin.readline().strip()
        p = getpass.getpass("Password: ").strip()
    #
    return login("https://marcus-ric.rexdb.net", u, p, perspective=perspective)

def datecheck(date,delim='-'):
    """ Check that date is formatted properly. If so, return None. If not, return 
    string explaining the issue. """
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
        return delim.join(("Format must be YYYY","MM","DD"))
    return None

def datestr_conv(date,delim='-'):
    """ Convert date to tuple of three integers [Y, M, D] """
    (y,m,d)=date.split(delim)
    return int(y),int(m),int(d)

def getdatestr():
    """ Read in date from user input. If it's not formatted properly, error. """
    date = stdin.readline().strip()
    # if not date:
    #     date = '-'.join([str(a) for a in datetime.date.today()]
    if datecheck(date):
        raise RuntimeError("Invalid date format: " + datecheck(date))
    return date

def print_headers(csv_writer,keyOrder): 
    """ Write out column headers """
    csv_writer.writerow(keyOrder)
    return

def print_query(csv_writer,queryResult,keyOrder):
    """ Write out the query result """
    keymap=dict(zip(keyOrder,range(1,len(keyOrder)+1)))

    # fix array output so that MATLAB can handle it easily
    for arrayCol in (k for k in keyOrder if k.count('array')>0): 
        for row in queryResult:
            temp = row[arrayCol]
            if type(temp)==list:
                temp = [str(t) for t in temp]
            else:
                temp = [str(temp)]
            row[arrayCol] = '['+"###".join(temp)+']'

    if 'Fellows' in keyOrder:
        for row in queryResult:
            if row['Fellows']:
                row['Fellows']=row['Fellows'].replace(',','&')

    for row in queryResult:
        ordered_values = [row[key] for key in keyOrder]
        csv_writer.writerow(ordered_values)
        #EDIT! try/catch UnicodeEncodeError
    return

def sessionTableQuery(fetch,filename,startdate,enddate):
    """" Run the session table query and write out results. """

    queryResult_session=fetch("/session{date title 'Date'+, array(individual.participation.protocol) title 'Protocol array',\
        iscan_type title 'Iscan Type', individual.id() title 'ID', individual.matlab_id title 'Matlab ID', \
        code title 'Session number', age_testing_months title 'Age (months)', quality title 'Quality', \
        experimenter title 'Fellows', count(run.clip) title 'Number of clips'} \
        ?date>=%s&date<=%s",startdate,enddate)
    
    #orderOfKeys must exactly match the queryResult keys! if query is changed, this line must also change to match it.
    #This is the order that will be used to print the results to a file 
    orderOfKeys_session=['Date','Protocol array','Iscan Type','ID','Matlab ID',
    'Session number','Age (months)','Quality','Fellows','Number of clips']
    
    with open(filename,'w') as f:
        f_csv = csv.writer(f)
        print_headers(f_csv,orderOfKeys_session)
        print_query(f_csv,queryResult_session,orderOfKeys_session)

    return

def runTableQuery(fetch,filename,startdate,enddate):
    """ Run the run table query and write out results. 
    Running this query in chunks, because the database will only output 
    a limited number of rows at a time. """

    orderOfKeys_run=['Date','Session ID','Protocol array','Age (months)','Quality','Clip','Status','Sample count','Fix count','Lost count']
    
    f = open(filename,'w')
    f_csv=csv.writer(f)
    
    (startyear, startmonth, startday) = datestr_conv(startdate)
    (endyear, endmonth, endday) = datestr_conv(enddate)

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
                array(session.individual.participation.protocol) title 'Protocol array',session.age_testing_months title 'Age (months)',\
                session.quality title 'Quality',clip title 'Clip',status title 'Status',run_data.sample_count title 'Sample count',\
                run_data.fixation title 'Fix count',run_data.lost title 'Lost count'} \
                ?session.date%s'%s'&session.date<='%s'" % (startDateChar,startdate_run,enddate_run)
            
            queryResult_run=fetch(runQuery)
            if firstLoop:
                print_headers(f_csv,orderOfKeys_run)
                firstLoop=0
            print_query(f_csv,queryResult_run,orderOfKeys_run)

    f.close()

    return

def phaseEditQuery(fetch,filename,startdate,enddate):
    """ Run the phase editor query and write out results.
    First run a prelim query, finding all participants who were paid in the 
    date range in question. Then run the real query, which looks for compensation 
    AND eye tracking sessions for those ID/phase/protocol combinations returned 
    from the prelim query. """

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
    
    with open(filename,'w') as f:
        f_csv=csv.writer(f)
        print_headers(f_csv,orderOfKeys_phase)
        print_query(f_csv,queryResult_phase,orderOfKeys_phase)

    return

def main(fetch=None,argsin=None):
    """ Ask user for start and end dates, run MRIC queries."""
    if not fetch:
        try:        
            fetch = _login()
        except Exception, err:
            print "Sorry, wrong username or password. \n more::", err
            sys.exit(-1)

    # Ask user for start/end dates
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
    
    #create/cd to dir for results
    DATE_QUERY_PATH = QUERY_PATH+startdate+'_'+enddate
    if not os.path.exists(DATE_QUERY_PATH):
        os.mkdir(DATE_QUERY_PATH)
    os.chdir(DATE_QUERY_PATH)

    ##QUERY 1 - session table 
    filename_session=''.join(('session_',startdate,'_',enddate,RESULTSFILE))
    sessionTableQuery(fetch,filename_session,startdate,enddate)

    ##QUERY 2 - phase editor. 
    filename_phase=''.join(('phase_',startdate,'_',enddate,RESULTSFILE))
    phaseEditQuery(fetch,filename_phase,startdate,enddate)

    os.chdir(ORIG_PATH)
    print " "
    print "Done. Query results saved: "
    print "    " + DATE_QUERY_PATH + filename_session
    print "    " + DATE_QUERY_PATH + filename_phase
    print " "

    
    return

if '__main__' == __name__:
    """ If 2 command line arguments are entered when the script is called, only
    one query will be run, with the args as start date & end date. With no 
    command line arguments: prompt the user to enter dates & provide option of 
    running multiple queries."""

    try:        
        fetch = _login()
    except Exception, err:
        print "Sorry, wrong username or password. \n more::", err
        sys.exit(-1)

    if len(sys.argv)==3:
        main(fetch,sys.argv[1:3])
    else:
        q = True
        while q:
            main(fetch)
            stdout.write("Do you want to run another query (y or n)? ")
            ans = stdin.readline().strip()
            q = (ans in ['y','Y'])

