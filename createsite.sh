#!/bin/sh
#Purpose of this script is to create a Database, and Domains at Acquia for use.

#script on bamboo servers needs help finding drush and alias files
#Path and Aliaspath not for use on local laptops, please comment only for use on bamboo servers.
#PATH=${PATH}:/cell_root/software/drush/current/:/usr/local/bin/
#DRUSHOPTS="--alias-path=/root/.drush --include=/root/.drush --config=/root/.drush/umddrupal.acapi.drushrc.php"



#Set base environment
ENV=dev
#set traget environment for db copies
#At Acquia test=stage environment
TARENV=test

#Check for database parameter
[ $# -eq 0 ] && { echo "Usage: $0 {database_name}" ; exit 1; }
#Make is easier to follow script where database is inserted
DATABASE=$1

#Check if Database with that name already exists
echo "Please be patient will take up to 5 minutes to run, or time out"
echo "You will be prompted to enter ssh password if one is set(ssh key must be uploaded to Acquia first)"
DBCHECK=`drush $DRUSHOPTS @umddrupal.$ENV ac-database-instance-info $DATABASE 2>&1 | grep host | cut -c 2-5`
#echo $DBCHECK
if [ "$DBCHECK" = 'host' ]; then
echo "WARNING: Looks like that database name is already in use. Please choose anouther"
echo "Usage: $0 {database_name}"
exit 1
fi

#Let's check domain name is not in use.
DNSCHECK=`drush $DRUSHOPTS @umddrupal.$ENV ac-domain-info $ENV.$DATABASE.umd.edu 2>&1 | grep name | cut -c 2-5`
#echo $DNSCHECK
if [ "$DNSCHECK" = 'name' ]; then
echo "WARNING: Looks like that DNS name is already in use. Please choose anouther"
echo "Usage: $0 {database_name}"
exit 1
fi


#contact Acquia to issue command to create a database
DBTASK=`drush $DRUSHOPTS @umddrupal.$ENV ac-database-add $DATABASE 2>&1 | cut -d ' ' -f2`
echo $DBTASK
#check in a loop if the backup task is completed or not.
DBWAITCOUNT=0
while [ "$DBTASKSTATUS" != 'done' ]
do
DBTASKSTATUS=`drush $DRUSHOPTS @umddrupal.$ENV ac-task-info $DBTASK | grep state | cut -c 19-22 ` 
echo \"$DBTASKSTATUS\"
DBWAITCOUNT=`expr $DBWAITCOUNT + 1`
[ $DBWAITCOUNT -gt 30 ] && { echo "FATAL: Database Creation task taking too long. Please contact admins" ; exit 1; }
echo "Database Crreation wait count: $DBWAITCOUNT"
sleep 5s
done

#contact Acquia to issue command to create domain in dev environment
DEVDNSTASK=`drush $DRUSHOPTS @umddrupal.$ENV ac-domain-add $ENV.$DATABASE.umd.edu 2>&1 | cut -d ' ' -f2`
echo $DEVDNSTASK
#check in a loop if the backup task is completed or not.
DEVDNSWAITCOUNT=0
while [ "$DEVDNSTASKSTATUS" != 'done' ]
do
DEVDNSTASKSTATUS=`drush $DRUSHOPTS @umddrupal.$ENV ac-task-info $DEVDNSTASK | grep state | cut -c 19-22 `
echo \"$DEVDNSTASKSTATUS\"
DEVDNSWAITCOUNT=`expr $DEVDNSWAITCOUNT + 1`
[ $DEVDNSWAITCOUNT -gt 30 ] && { echo "FATAL: Varnish Domain Creation task taking too long. Please contact admins" ; exit 1; }
echo "Varnish Domain Creation wait count: $DEVDNSWAITCOUNT"
sleep 5s
done


echo "Operations completed"
