#!/bin/bash

# Bash script to backup WP sites set up on centminmod servers on offsite 
# servers using SSH & rsync

PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

d="`date +%Y-%m-%d`"

cd /home/nginx/domains/

backupPath=""
serverIP=""

# Retention on remote server
dailyBackupstoRetain=7
weeklyBackupstoRetain=3
monthlyBackupstoRetain=3

#####################################
## DONT CHANGE ANYTHING BELOW THIS ##
#####################################

# Manipulate weekly/monthly retention in terms of days
weeklyBackupstoRetain=$(( $weeklyBackupstoRetain*7 ))
monthlyBackupstoRetain=$(( $monthlyBackupstoRetain*30 ))

# weekly if sunday, monthly if 1st else daily
if [[ `date '+%d'` == 01 ]]; then
    backupPath="/home/backup/monthly/$d/"
elif [[ $(date +%u) -eq 7 ]] ; then
    backupPath="/home/backup/weekly/$d/"
else
    backupPath="/home/backup/daily/$d/"
fi

ssh backup@$serverIP mkdir -p $backupPath

for i in `ls`; do 
    mkdir -p /tmp/backup/$i/
    # Skip demodomain.com directory added by centminmod
    if [[ "$i" != "demodomain.com" ]]; then
        if [[ -e /home/nginx/domains/$i/public/wp-config.php  ]]; then
            db_name=`cat /home/nginx/domains/$i/public/wp-config.php | grep DB_NAME | cut -d \' -f 4`
            mysqldump $db_name > /tmp/backup/$i/$db_name.sql
        fi
        cd /tmp/backup/
        cp -rf /home/nginx/domains/$i/public/* /tmp/backup/$i/
        tar -zcf $i-$d.tar.gz -C /tmp/backup/$i/ .
        rsync -az /tmp/backup/$i-$d.tar.gz backup@$serverIP:$backupPath
        rm -rf /tmp/backup/$i/
        rm -f /tmp/backup/$i-$d.tar.gz
   fi
done

# Remove old backups from the remote server
ssh backup@$serverIP "find /home/backup/daily/* -type d -mtime +$dailyBackupstoRetain -exec rm -r {} \;"
ssh backup@$serverIP "find /home/backup/weekly/* -type d -mtime +$weeklyBackupstoRetain -exec rm -r {} \;"
ssh backup@$serverIP "find /home/backup/monthly/* -type d -mtime +$monthlyBackupstoRetain -exec rm -r {} \;"
