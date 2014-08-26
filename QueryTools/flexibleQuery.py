#!/usr/bin/python

""" 
Copied dataquery.py v5.1

Goal for this script: pass in a query, output the JSON formatted file 
Will use with flexible matlab graphs


    NOTES FROM MATLAB SCRIPT:
    Pass in text file with query AND name for results file
    If an array is being returned, write out with ### as delimiter, and ****put array in the title****
    Should save the results in the resultsName file (assume standard file structure)

"""
#edit these:
import os, sys
from sys import stdin, stdout
from time import sleep
from htsql_client import login, HTSQL_Error
import getpass
import csv


def _login(u=None, p=None, perspective='full_access'):
    """Log into the HTSQL server"""
    if not u or not p:
        print "**Log in to MRIC**"
        stdout.write("Username: ")
        u = stdin.readline().strip()
        p = getpass.getpass("Password: ").strip()
    #
    return login("https://marcus-ric.rexdb.net", u, p, perspective=perspective)

#test
def readInQuery(textFile):
    """Read in a textfile with an HTSQL query"""
    #read in file
    query=''
    for line in open(textFile):
        query+=line
    query=query.strip()
    #
    return query

#test
def runQuery(HTSQLquery,fetch=None):
    """Query MRIC database, return query result"""
    if not fetch:
        fetch=_login()
    #
    print "Querying..."
    return fetch(HTSQLquery)


#test
def writeOutQuery(csv_writer,queryResult):
    """Write out query (columns are returned in random order)"""
    
    #exclude the 3 odd htsql: things that are output 
    keyOrder=[k for k in queryResult[0].keys() if k.count('htsql:')==0]
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

    #Edit - delete this?
    if 'Fellows' in keyOrder:
        for row in queryResult:
            if row['Fellows']:
                row['Fellows']=row['Fellows'].replace(',','&')

    #write to file
    csv_writer.writerow(keyOrder) #headers
    for row in queryResult:
        ordered_values = [row[key] for key in keyOrder]
        csv_writer.writerow(ordered_values)

    return


def main(queryFile=None,resultDir=None):
    try:        
        fetch = _login()
    except Exception, err:
        print "Sorry, wrong username or password. \n more::", err
        sys.exit(-1)

    # EDIT add checks, make sure that prompted input works
    if not queryFile:
        stdout.write("Enter name of the textfile with the query to run (w/ full path): ")
        fullQueryFile = stdin.readline().strip()
        (queryFilePath,queryFile) = os.path.split(queryFile)
    else:
        fullQueryFile = queryFile
        (queryFilePath,queryFile) = os.path.split(queryFile)

    # Read in textfile with query
    HTSQLquery = readInQuery(fullQueryFile)

    print "Querying MRIC: " + HTSQLquery

    #run query
    queryResult = runQuery(HTSQLquery,fetch)

    # If no resultDir is entered, save the results where the query came from
    if not resultDir:
        resultDir = queryFilePath
    # Add trailing / if it's missing
    if not resultDir[-1] == '/':
        resultDir = resultDir+'/'

    # Write out result
    queryFileName = queryFile.split('.')
    resultFile = resultDir+'Results_'+queryFileName[0]+'.csv'
    with open(resultFile,'w') as f:
        f_csv = csv.writer(f)
        writeOutQuery(f_csv,queryResult)
    
    print "Done. Query results saved:",resultFile
    
    return


if '__main__' == __name__:
    if len(sys.argv)==1:
        main()
    elif len(sys.argv)==2: #1 argument = queryFile
        main(sys.argv[1])
    elif len(sys.argv)==3: #2 arguments = queryFile, resultDir 
        main(sys.argv[1],sys.argv[2])
    else:
        print 'Too many arguments.'