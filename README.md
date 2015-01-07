Set of tools for running MRIC queries.

## Main scripts
**weeklyCheck:** Runs ETL weekly audits on the MRIC database for a
specified date range and saves a csv summary. Also creates a 
series of graphs using ETLAuditGraphs.

**ETLAuditGraphs:** Audit eye-tracking data in MRIC and visualize the
results.

## Notes
+ Remember to update the list of protocols in ETLAuditGraphs.m to ensure
that it matches MRIC. 

**Set up on a new computer:**
+ Create folders for base queries and results
+ Change directories: 
    - Defaults in ETLAuditGraphs.m 
    - pythonDir and defaults in AuditQuery.m 
    - pythonDir and baseResultsDir in weeklyCheck.m
+ (Optional) Use testQueryTools.m to validate scripts in QueryTools/

**To make this script compatible with MATLAB2012:**
+ Replace strsplit with strsplit\_CR in ReadInQuery.m and AuditQuery.m 
+ Replace strjoin with strjoin\_CR in weeklyCheck.m