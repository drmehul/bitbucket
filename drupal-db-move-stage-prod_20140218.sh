#!/bin/sh
#Purpose of this script is to facilitate promoting content in Drupal Database to anouther environment on Acquia.

#script on bamboo servers needs help finding drush and alias files
#Path and Aliaspath not for use on local laptops, please comment only for use on bamboo servers.
#PATH=${PATH}:/cell_root/software/drush/current/:/usr/local/bin/
#DRUSHOPTS="--alias-path=/root/.drush --include=/root/.drush --config=/root/.drush/umddrupal.acapi.drushrc.php"



#Set base environment
ENV=test
#set traget environment for db copies
#At Acquia test=stage environment
TARENV=prod

#Check for database parameter
[ $# -eq 0 ] && { echo "Usage: $0 {database_name}" ; exit 1; }
#Make is easier to follow script where database is inserted
DATABASE=$1

echo "Please be patient will take up to 5 minutes to run, or time out"
echo "You will be prompted to enter ssh password if one is set(ssh key must be uploaded to Acquia first)"
#make sure valid database provided
DBCHECK=`drush $DRUSHOPTS @umddrupal.$TARENV ac-database-instance-info $DATABASE 2>&1 | grep host | cut -c 2-5`
#echo $DBCHECK
if [ "$DBCHECK" != 'host' ]; then
echo "WARNING: Invalid database name specified please check database name"
echo "Usage: $0 {database_name}"
exit 1
fi

#contact Acquia to issue command for a backup.
BKTASK=`drush $DRUSHOPTS @umddrupal.$TARENV ac-database-instance-backup $DATABASE 2>&1 | cut -d ' ' -f2`
#echo $BKTASK
#check in a loop if the backup task is completed or not.
BKWAITCOUNT=0
while [ "$BKTASKSTATUS" != 'done' ]
do
BKTASKSTATUS=`drush $DRUSHOPTS @umddrupal.$TARENV ac-task-info $BKTASK | grep state | cut -c 19-22 ` 
#echo \"$BKTASKSTATUS\"
BKWAITCOUNT=`expr $BKWAITCOUNT + 1`
[ $BKWAITCOUNT -gt 30 ] && { echo "FATAL: Backup task taking too long. Please contact admins" ; exit 1; }
#echo "backup wait count: $BKWAITCOUNT"
sleep 5s
done

#Now that backup is done we can proceed to issue command to Acquia to copy database from source environment to taget environment
MOVETASK=`drush $DRUSHOPTS @umddrupal.$ENV ac-database-copy $DATABASE $TARENV 2>&1 | cut -d ' ' -f2`
#loop until move task says it is done.
MOVEWAITCOUNT=0
while [ "$MOVETASKSTATUS" != 'done' ]
do
MOVETASKSTATUS=`drush $DRUSHOPTS @umddrupal.$ENV ac-task-info $MOVETASK | grep state | cut -c 19-22 `
#echo \"$MOVETASKSTATUS\"
MOVEWAITCOUNT=`expr $MOVEWAITCOUNT + 1`
[ $MOVEWAITCOUNT -gt 30 ] && { echo "FATAL: Database move task taking too long. Please contact admins" ; exit 1; }
#echo "Move wait count: $MOVEWAITCOUNT"
sleep 5s
done

#We need to check for helpdesk manual as it is slighly different
#Will make the file copy and varnish clear command work without much recoding
if [ $DATABASE = 'manual' ]; then
DATABASE="manual.helpdesk"
fi

#Need to determine which servers to connect to first
if [ $TARENV = 'prod' ]; then
FILESOURCE=`drush $DRUSHOPTS @umddrupal.$ENV ac-environment-info | grep ssh_host | cut -c 22-57 | tr -d ' '`
#Give server a break
sleep 5s
FILEDEST=`drush $DRUSHOPTS @umddrupal.$TARENV ac-environment-info | grep ssh_host | cut -c 22-53 | tr -d ' '`
#Give server a break
sleep 5s
#echo $FILESOURCE
#echo $FILEDEST
else
FILESOURCE=`drush $DRUSHOPTS @umddrupal.$ENV ac-environment-info | grep ssh_host | cut -c 22-57 | tr -d ' '`
#Give server a break
sleep 5s
FILEDEST=`drush $DRUSHOPTS @umddrupal.$TARENV ac-environment-info | grep ssh_host | cut -c 22-57 | tr -d ' '`
#Give server a break
sleep 5s
#echo $FILESOURCE
#echo $FILEDEST
fi

#a little extra time to make sure db move is complete and cooled off
sleep 60s
#Clear Drupal database caches on target server
ssh -o StrictHostKeyChecking=no umddrupal@$FILEDEST "cd /var/www/html/umddrupal.$TARENV && drush5 --uri=http://$DATABASE.umd.edu cc all > /dev/null && sleep 3s"

#connect to source server, then copy files limited to database(site) in question to target server
echo "INFO: Can ignore errors below related to permissions issues on htaccess files. If any."
ssh -o StrictHostKeyChecking=no -o ForwardAgent=yes umddrupal@$FILESOURCE scp -r /mnt/www/html/umddrupal.$ENV/docroot/sites/$DATABASE.umd.edu/files umddrupal@$FILEDEST:/var/www/html/umddrupal.$TARENV/docroot/sites/$DATABASE.umd.edu > /dev/null


#Selectively clear varnish caches based on environment
if [ $TARENV = 'test' ]; then
drush $DRUSHOPTS @umddrupal.$TARENV ac-domain-purge stage.$DATABASE.umd.edu > /dev/null
fi 
if [ $TARENV = 'prod' ]; then
drush $DRUSHOPTS @umddrupal.$TARENV ac-domain-purge $DATABASE.umd.edu > /dev/null
#Give server a break
sleep 5s
#Some prod domains do not have www, but try to flush anyhow and ignore error
echo "INFO: Can ignore API status code 404 error below if 'www' domain is not configured on Acquia"
drush $DRUSHOPTS @umddrupal.$TARENV ac-domain-purge www.$DATABASE.umd.edu > /dev/null
fi

echo "INFO: Operations completed"
