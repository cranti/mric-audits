#!/usr/bin/python

""" 
flexibleQuery.py

    Reads in a text file with an HTSQL query for MRIC, runs that query, and writes
    out the results in a csv file. Originally written for use with the audit 
    visualization scripts.

    If MRIC is returning an array, include the word "array" in the title of that
    column. This script will write out the column with ### as a delimiter between
    items (which allows MATLAB to parse the csv properly)


    Usage: 
        python flexibleQuery.py queryFile resultsDir --> queryFile is a full path
            to a text file with an HTSQL query to run. The results are saved in 
            resultsDir, in a csv named for the query file (with prefix "Results_")

        python flexibleQuery.py queryFile --> same as above, but result csv is saved
            in the same directory as the query file.

    ***************
    
    Carolyn Ranti, 8.25.2014. Adapted from dataquery.py (V5.1)
"""

import os, sys
from sys import stdin, stdout
from time import sleep
from htsql_client import login
import getpass
import csv

def _login(u=None, p=None, perspective='full_access'):
    """Log into the HTSQL server"""
    if not u or not p:
        print "**Log in to MRIC**"
        stdout.write("Username: ")
        u = stdin.readline().strip()
        p = getpass.getpass("Password: ").strip()
    
    return login("https://marcus-ric.rexdb.net", u, p, perspective=perspective)

def readInQuery(textFile):
    """Read in a textfile with an HTSQL query"""
    #read in text file
    query=''
    for line in open(textFile):
        query+=line
    query=query.strip()
    
    return query

def runQuery(HTSQLquery,fetch=None):
    """Query MRIC database, return query result"""
    if not fetch:
        fetch=_login()
    
    return fetch(HTSQLquery)

def writeOutQuery(csv_writer,queryResult):
    """Write out query (columns are printed in random order)"""
    
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

    # Catches a specific error (separating initials with a comma)
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


def main(fullQueryFile=None,resultDir=None):
    """ Run MRIC query and write out results to a csv. """

    try:        
        fetch = _login()
    except Exception, err:
        print "Sorry, wrong username or password. \n more::", err
        sys.exit(-1)

    # EDIT add checks, make sure that prompted input works
    (queryFilePath,queryFileName) = os.path.split(fullQueryFile)
    queryFileName = queryFileName.split('.')[0]

    # Read in textfile with query
    HTSQLquery = readInQuery(fullQueryFile)

    #run query
    print " "
    print "Querying MRIC:"
    print "    " + HTSQLquery
    print " "
    queryResult = runQuery(HTSQLquery,fetch)

    # If no resultDir passed in, save the results where the query came from
    if not resultDir:
        resultDir = queryFilePath

    if not resultDir[-1] == '/':
        resultDir = resultDir+'/'

    # Write out result to csv
    resultFile = resultDir+'Results_'+queryFileName+'.csv'
    with open(resultFile,'w') as f:
        f_csv = csv.writer(f)
        writeOutQuery(f_csv,queryResult)

    print " "
    print "Done. Query results saved: "
    print "    " + resultFile
    print " "
    
    return

if '__main__' == __name__:
    if len(sys.argv)==1:
        sys.exit("Not enough arguments. Usage:\n\tpython flexibleQuery.py queryFile *resultsDir")
    elif len(sys.argv)==2: #1 argument = queryFile
        main(sys.argv[1])
    elif len(sys.argv)==3: #2 arguments = queryFile, resultDir 
        main(sys.argv[1],sys.argv[2])
    else:
        sys.exit("Too many arguments. Usage:\n\tpython flexibleQuery.py queryFile *resultsDir")