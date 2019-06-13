# Author: Seema Gupta
# Script: Backup Database
# Version: 1.1

#!/bin/bash
########################################################
#                                                      #
# Database Full and Incremental Backup                 #
#                                                      #
########################################################

# Define Variables
days_of_backups_to_keep=30  
days_of_backup_to_archive=7
archive_parent_dir="/backup/database_backup/archived_backup"
backup_owner="backup"
parent_dir="/backup/database_backup"
full_backup_dir="${parent_dir}/full_backup"
incremental_backup_dir="${parent_dir}/incremental_backup"
defaults_file="/etc/mysql/backup.cnf"
todays_day="$(date +%A)"

if [ ${todays_day} = "Wednesday" ]; then
   todays_dir="${full_backup_dir}/$(date +%a_%m%d%y)"
   backup_type="full_backup"
else
   todays_dir="${incremental_backup_dir}/$(date +%a_%m%d%y)"
   backup_type="inc_backup"
fi

basedir="${full_backup_dir}/$(date -dlast-Wednesday +%a_%m%d%y)"
log_file="${todays_dir}/backup-progress.log"
now="$(date +%m%d%Y_%H%M%S)"
processors="$(nproc --all)"
ENV="$(dnsdomainname)"

EMAIL_TO="seema.gupta@newwave.io"


# Use this to echo to standard error
error () {
    printf "%s: %s\n" "$(basename "${BASH_SOURCE}")" "${1}" >&2
    exit 1
}

trap 'error "An unexpected error occurred."' ERR


set_options () {
    # List the xtrabackup arguments
    xtrabackup_args=(
        "--defaults-file=${defaults_file}"
        "--backup"
        "--extra-lsndir=${todays_dir}"
        "--compress"
        "--stream=xbstream"
        "--parallel=${processors}"

        "--compress-threads=${processors}"
    )
}

archive_old () {
    # Move the Old backup to archive directory to keep it for 30 days
    find "${full_backup_dir}" -type d -ctime +"${days_of_backup_to_archive}" -exec mv {} "${archive_parent_dir}"/full_backup_archive/ \;
    find "${incremental_backup_dir}" -type d -ctime +"${days_of_backup_to_archive}" -exec mv {} "${archive_parent_dir}"/incremental_backup_archive/ \;
}

rotate_old () {
    # Remove the oldest backup in archive
    find "${archive_parent_dir}" -type d -ctime +"${days_of_backups_to_keep}" -exec rm -rf {} \;
}

take_backup () {
    # Make sure today's backup directory is available and take the actual backup
    mkdir -p "${todays_dir}"
    find "${todays_dir}" -type f -name "*.incomplete" -delete
    if [ ${backup_type} = "full_backup" ]; then
       xtrabackup "${xtrabackup_args[@]}" --target-dir="${todays_dir}" > "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" 2> "${log_file}"
    else 
       xtrabackup "${xtrabackup_args[@]}" --target-dir="${todays_dir}" --incremental-basedir "${basedir}" > "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" 2> "${log_file}"
    fi

    mv "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" "${todays_dir}/${backup_type}-${now}.xbstream"
}

send_mail () {
echo -e "${backup_info}" | mailx -v -s "Database Backup Job Completed" \
 -S smtp-auth=login \
 -S smtp-use-starttls \
 -S nss-config-dir=~/.certs \
 -S smtp=smtp.office365.com:587 \
 -S from="Alert@radvcdat.com" \
 -S smtp-auth-user=Alert@radvcdat.com \
 -S smtp-auth-password="Lamu3134" \
 -S ssl-verify=ignore \
  "${EMAIL_TO}"
}

archive_old

set_options && take_backup

# Check success and print message
if tail -1 "${log_file}" | grep -q "completed OK"; then
    backup_info="Status: Database Backup successful on ${ENV}.\n Backup Location: Backup created at ${todays_dir}/${backup_type}-${now}.xbstream"
    send_mail
else
    backup_info=error "Backup failure on ${ENV}! Check ${log_file} for more information"
    send_mail
fi

