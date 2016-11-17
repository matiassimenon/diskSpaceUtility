#!/bin/bash

################################################################################
##################################diskSpace.sh##################################
################################################################################
##################################franciscogd###################################
################################################################################

# source bash or z profiles depending on the case
if [ -d /home/<user_name>/ ]; then
	source /home/<user_name>/.bash_profile
else
	source /home/<user_name_2>/.zprofile
fi

# if Disk Space Tolerance Percent sent by user or not
if [ $# -eq 0 ]; then
	diskSpaceTolerance=80
else
	diskSpaceTolerance=$1
fi

temp_scpp="$( df -h /.../scpp | awk '{ print $5 }' | tail -1  )"
temp_oradata="$( df -h /.../oracle/oradata | awk '{ print $5 }' | tail -1  )"
temp_oracle="$( df -h /.../oracle | awk '{ print $5 }' | tail -1  )"

# Remove percent sign '%' from variables to convert to integer
scpp=$(echo $temp_scpp | sed 's/%//')
oradata=$(echo $temp_oradata | sed 's/%//')
oracle=$(echo $temp_oracle | sed 's/%//')

# Delete logs from Apps' logs folders if scpp disk space greater or equal than $diskSpaceTolerance
if [ $scpp -ge $diskSpaceTolerance ]; then
	# Finding  paths of log/logs directories
	find $APPS -path "*/log/*" -type d | sed 's_/log.*_/log_' | sed -n '/src/!p' | uniq > logPaths.$(date '+%m.%d.%y-%H.%M').txt
	find $APPS -path "*/logs/*" -type d | sed 's_/logs.*_/logs_' | sed -n '/src/!p' | uniq >> logPaths.$(date '+%m.%d.%y-%H.%M').txt

	while read line
	do
        # Log files to be deleted from log directories
		# If more or different log files, user should add them to array
        	logFiles="server.log localhost.log localhost_access_log catalina.log server-startup.log"
		for logFile in $logFiles
        	do
                	if [ -f "$line/$logFile" ]; then
                        	ls -rt $line/$logFile.* | head -n -10 | xargs rm -f
                	fi
        	done
	done <logPaths.$(date '+%m.%d.%y-%H.%M').txt

	temp_scpp="$( df -h /.../scpp | awk '{ print $5 }' | tail -1  )"
    new_scpp=$(echo $temp_scpp | sed 's/%//')

	message="Application logs were deleted. Disk space capacity after log deletion: $new_scpp%."
	if [ -f "logPaths.$(date '+%m.%d.%y-%H.%M').txt" ]; then
		sed -i "1i$message" logPaths.$(date '+%m.%d.%y-%H.%M').txt
        mail -s " Disk space at $scpp% capacity on `hostname`:/.../scpp " $EMAIL < logPaths.$(date '+%m.%d.%y-%H.%M').txt
	else
        	echo $message | mail -s " Disk space at $scpp% capacity on `hostname`:/.../scpp " $EMAIL
	fi

	rm -rf logPaths.*
fi

# resize.sql if oradata disk space greater or equal than $diskSpaceTolerance
if [ $oradata -ge $diskSpaceTolerance ]; then
	if [ -f /.../sql/util/resize.sql ]; then
		cd /.../sql/util
		su -c "echo '@resize.sql commit; exit;' | sqlplus / as sysdba" oracle

		temp_oradata="$( df -h /.../oracle/oradata | awk '{ print $5 }' | tail -1  )"
        new_oradata=$(echo $temp_oradata | sed 's/%//')

		message="Tables resize was performed. Disk space capacity after tables resize: $new_oradata%."
		echo "$message" | mail -s " Disk space at $oradata% capacity on `hostname`:/.../oracle/oradata " $EMAIL
	else
            message="resize.sql was not found under /home/oracle/"
            echo "$message" | mail -s " Disk space at $oradata% capacity on `hostname`:/.../oracle/oradata " $EMAIL
	fi
fi

# purge ADRCI if oracle disk space greater or equal than $diskSpaceTolerance
if [ $oracle -ge $diskSpaceTolerance ]; then

	# Get list of ADRCI homes
	homes=$(su -c " echo 'show home; exit;' | adrci | awk '/diag*/{print \$1}'" oracle)

	# Purges that will be performed
	purge1="purge -age 1440"
	purge2="purge -age 1440 -type CDUMP"
	purge3="purge -age 1440 -type UTSCDMP"

	homes=( $homes ) # convert homes to array
	for adrciHome in "${homes[@]}";
        	do
		su -c "echo 'set home $adrciHome; $purge1; $purge2; $purge3; commit; exit;' | adrci" oracle
	done

	temp_oracle="$( df -h /.../oracle | awk '{ print $5 }' | tail -1  )"
    new_oracle=$(echo $temp_oracle | sed 's/%//')

    # if ADRCI purge is not enough, delete directories from /.../oracle/diag/rdbms/orcl/orcl/trace/
    if [ $new_oracle -ge $diskSpaceTolerance ]; then
    	su -c "rm -rf /.../oracle/diag/rdbms/orcl/orcl/trace/*.*" oracle

    	temp_oracle="$( df -h /.../oracle | awk '{ print $5 }' | tail -1  )"
		new_oracle=$(echo $temp_oracle | sed 's/%//')

        message="Automatic Trace File Cleanup using ADRCI did not clear enough Space. Deletion of files in /.../oracle/diag/rdbms/orcl/orcl/trace/ performed. Disk space capacity after purge and file deletion: $new_oracle%."
        echo "$message" | mail -s "Disk space at $oracle% capacity on `hostname`:/.../oracle " $EMAIL

    else
        message="Automatic Trace File Cleanup using ADRCI. Disk space capacity after purge: $new_oracle%."
        echo "$message" | mail -s "Disk space at $oracle% capacity on `hostname`:/.../oracle " $EMAIL
    fi
fi
