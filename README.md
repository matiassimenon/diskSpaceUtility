# diskSpaceUtility
diskSpace.sh checks filesystem diskspace use % from apps_services_dir, 
oracle_dir, oradata_dir and takes action when diskspace use % is above 
tolerance level.  

This script should be set as a cronjob to be run daily

It will only delete application logs, resize tables and/or purge adrci logs if 
diskspace use % is higher than the set diskspace tolerance. Diskspace tolerance 
is by default set to 80% under 'diskSpaceTolerance' variable.

The script can also be run with a different tolerance value as input, e.g.: 
$ sh diskSpace.sh <otherValue>

This script runs commands as scopeadm or wmsadmin, oracle and as root users, 
hence it needs to be owned by root and it needs to be executed as root user.

To fully work, script needs:

(1) /.../diskSpace.x.x.sh owned by root:root
(2) APPS in .bash_profile or .zprofile, e.g. export APPS=/app_services/
(3) EMAIL in .bash_profile/.zprofile, e.g. export EMAIL=email@gatech.edu
(4) /.../resize.sql owned by root:sales

################################################################################
############################## Monitor Diskspace ###############################
################################################################################

Script monitors diskspace and compares Use% against the set diskSpaceTolerance:
user ~ $ df -h
Filesystem                           Size  Used Avail Use% Mounted on
/dev/mapper/demo_vg-scpp_lv      50G   11G   37G  22% /.../apps_services/
/dev/mapper/demo_vg-oradata_lv   50G  6.4G   41G  14% /.../oracle/oradata/
/dev/mapper/demo_vg-oracle_lv   9.8G  6.2G  3.1G  67% /.../oracle/

################################################################################
############################ Delete Application Logs ###########################
################################################################################

If /.../apps_services/ use% >= $diskSpaceTolerance

(1) Find log/logs folders and append to logPathsDATESTAMP.txt file.
(2) For every path in the file, search all log files included in the 'logFiles' 
    array. Every new product release new logfiles should be added to this array.
(3) Delete all log files of each type except for the last 10 created.
(4) Email user the diskpace use % before and after deletion of logs and where 
    the logs were found.

################################################################################
################################ Resize Tables #################################
################################################################################

If /.../oracle/oradata/ Use% >= $diskSpaceTolerance

(1) Use sqlplus utility as oracle user.
(2) Resize tables by executing sql script 'resize.sql' located in /.../oracle/
(3) Email user the diskspace use % before and after resize of tables execution. 

################################################################################
################################# ADRCI Purge ##################################
################################################################################

If /.../oracle/ Use% >= $diskSpaceTolerance

(1) Use ADRCI utility as oracle user
(2) Execute purges, by default defined as -age 1440 (older than 1 day).
    The purging age can me modified and different purges can be added in this
    section if user needs to.
(3) If this does not work, delete files directly from 
	/.../oracle/diag/rdbms/orcl/orcl/trace/
(3) Email user the diskspace use % before and after ADRCI purge.
