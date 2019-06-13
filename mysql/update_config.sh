#Backup RADV Database priror to deployment from Jenkins build jobs
#Author: Seema Gupta
#Project: RADV
#Create Date - 12/03/2018

#Define Variables

#!/bin/bash
SERVICE=mysql
PORT=3306
DATA_DIRECTORY=/data
STATE_FILE=$DATA_DIRECTORY/grastate.dat
COMMAND="systemctl start mysql@bootstrap"
FILE=


if (( $(netstat -ntaupe | grep LISTEN | grep $PORT | wc -l) > 0 ))
then
	echo "Service is running"
else
	BOOTSTRAP_STATUS=`grep safe_to_bootstrap $STATE_FILE | cut -d: -f2`
	if [ $BOOTSTRAP_STATUS == 1 ]
	then
		$COMMAND
	else
		echo "MySQL Service need to be started manually"
	fi
fi

