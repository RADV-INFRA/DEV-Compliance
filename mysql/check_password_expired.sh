#Backup RADV Database priror to deployment from Jenkins build jobs
#Author: Seema Gupta
#Project: RADV
#Create Date - 10/11/2018

#Define Variables
MAIL_TO=radv_infra@newwave.io
ENV=`echo $(dnsdomainname)`

SHELL=/bin/sh
OUTPUT_DIR=/tmp/
FILENAME=password_expired_$(date +%Y%m%d).sql
OUTPUT_FILE=$OUTPUT_DIR/$FILENAME
USER=ansible
PASSWORD=Ansiqaa5623%%kll
SQL_QUERY="select user,
	concat(cast(IFNULL(password_lifetime, @@default_password_lifetime) as signed) + 
	cast(datediff(password_last_changed, now()) as signed)) as password_expires_in_days from mysql.user
	where 
	cast(
 	IFNULL(password_lifetime, @@default_password_lifetime) as signed)
 	+ cast(datediff(password_last_changed, now()) as signed) <= 7 
 	and account_locked='N';"


send_mail () {
mailx -v -s "DB Accounts Password Expiring - ${ENV}" \
 -S smtp-auth=login \
 -S smtp-use-starttls \
 -S nss-config-dir=/home/nwt/.certs \
 -S smtp=smtp.office365.com:587 \
 -S from="Alert@radvcdat.com" \
 -S smtp-auth-user=Alert@radvcdat.com \
 -S smtp-auth-password="70!VirqaBXA1" \
 -S ssl-verify=ignore \
"${MAIL_TO}" < ${OUTPUT_FILE}
}


mysql -u $USER -p$PASSWORD -t -e "${SQL_QUERY}" > $OUTPUT_FILE || exit 1

RESULT=`wc -l $OUTPUT_FILE | cut -d' ' -f1`

if [ ${RESULT} -gt 3 ];
then
   send_mail
fi
