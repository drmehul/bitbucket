#!/bin/sh
#Purpose of this script is to create a Database, and Domains at Acquia for use.

#script on bamboo servers needs help finding drush and alias files
#Path and Aliaspath not for use on local laptops, please comment only for use on bamboo servers.
#PATH=${PATH}:/cell_root/software/drush/current/:/usr/local/bin/
#DRUSHOPTS="--alias-path=/root/.drush --include=/root/.drush --config=/root/.drush/umddrupal.acapi.drushrc.php"



#Set base environment
ENV=dev

#Check for database parameter
[ $# -eq 0 ] && { echo "Usage: $0 {database_name}" ; exit 1; }
#Make is easier to follow script where database is inserted
DATABASE=$1

SVNCHECK=`svn info 2>&1 | grep acquia`
#echo $?
if [ $? -ne '0' ]; then
echo "WARNING: Does not appear you are in local Acquia repo"
echo "WARNING: Please change into directory of local Acquia repo at braches,tags, trunk directory level"
exit 1
fi

#Check if at correct directory level
if [ ! -d trunk ]; then
echo "WARNING: Can't find trunk directory"
echo "WARNING: Please change into directory of local Acquia repo at braches,tags, trunk directory level"
exit 1
fi


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
#echo $DBTASK
#check in a loop if the backup task is completed or not.
DBWAITCOUNT=0
while [ "$DBTASKSTATUS" != 'done' ]
do
DBTASKSTATUS=`drush $DRUSHOPTS @umddrupal.$ENV ac-task-info $DBTASK | grep state | cut -c 19-22 ` 
#echo \"$DBTASKSTATUS\"
DBWAITCOUNT=`expr $DBWAITCOUNT + 1`
[ $DBWAITCOUNT -gt 30 ] && { echo "FATAL: Database Creation task taking too long. Please contact admins" ; exit 1; }
#echo "Database Crreation wait count: $DBWAITCOUNT"
sleep 5s
done

#contact Acquia to issue command to create domain in dev environment
DEVDNSTASK=`drush $DRUSHOPTS @umddrupal.$ENV ac-domain-add $ENV.$DATABASE.umd.edu 2>&1 | cut -d ' ' -f2`
#echo $DEVDNSTASK
#check in a loop if the backup task is completed or not.
DEVDNSWAITCOUNT=0
while [ "$DEVDNSTASKSTATUS" != 'done' ]
do
DEVDNSTASKSTATUS=`drush $DRUSHOPTS @umddrupal.$ENV ac-task-info $DEVDNSTASK | grep state | cut -c 19-22 `
#echo \"$DEVDNSTASKSTATUS\"
DEVDNSWAITCOUNT=`expr $DEVDNSWAITCOUNT + 1`
[ $DEVDNSWAITCOUNT -gt 30 ] && { echo "FATAL: Varnish Domain Creation task taking too long. Please contact admins" ; exit 1; }
#echo "Varnish Domain Creation wait count: $DEVDNSWAITCOUNT"
sleep 5s
done

#Update our local working copy to perform merge
echo "Going to update our local repo"
echo "This could take a while"
svn up trunk/docroot/sites 2>&1
if [ $? -ne '0' ]; then
echo "FATAL: Something went wrong with updating working SVN copy"
echo "FATAL: Don't know what to do, exiting for now"
exit 1
fi

#Make needed directories
mkdir trunk/docroot/sites/$DATABASE.umd.edu
mkdir trunk/docroot/sites/$DATABASE.umd.edu/modules
mkdir trunk/docroot/sites/$DATABASE.umd.edu/themes
#Copy and Edit the settings file with database name
cat ./trunk/docroot/sites/default/freshinstall.settings.php | sed "s/EDITME/$DATABASE/" > ./trunk/docroot/sites/$DATABASE.umd.edu/settings.php
svn add ./trunk/docroot/sites/$DATABASE.umd.edu
svn commit -m "New site $DATABASE.umd.edu created"

echo "Script will sleep for a minute while commit is deployed."
sleep 60
echo "Running install.php on site now"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu site-install standard --account-mail=sysarc@umd.edu --account-name=sysarc --account-pass=middleware --site-mail=sysarc@umd.edu --site-name=$DATABASE.umd.edu install_configure_form.update_status_module='array(FALSE,FALSE)' -y 2>&1
#Quick break
sleep 10

echo "Configuring CAS login module"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu en cas -y
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_access "0"
#drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_cert ""
#drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_changePasswordURL ""
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_check_first 0
#drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_debugfile ""
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_domain "umd.edu"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_exclude "services/*"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_first_login_destination ""
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_hide_email 1
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_hide_password 1
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_library_dir "sites/all/libraries/CAS"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_login_drupal_invite "Cancel CAS login"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_login_form "2"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_login_invite "Log in using CAS"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_login_message "Logged in via CAS as %cas_username."
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_login_redir_message "You will be redirected to the secure CAS login page."
#drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_logout_destination ""
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_pgtformat "plain"
#drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_pgtpath ""
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_port "443"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_proxy 0
#drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_registerURL ""
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_server "login.umd.edu"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_uri "cas"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_user_register 1
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_version "2.0"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu vset --always-set cas_pages "admin admin/* user user/* node/add/*"

echo "Adding middleware admin users"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu cas-user-create raughenb
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu cas-user-create mshah12
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu cas-user-create edaviage
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu cas-user-create dbeckham
echo "Assigning administrator role for middlware admins"
drush @umddrupal.dev --uri=http://$DATABASE.umd.edu user-add-role "administrator" raughenb,mshah12,edaviage,dbeckham
echo "**********************************************************************************************************************"
echo "Operations completed"
echo "If DNS request has been completed you can login to site http://dev.$DATABASE.umd.edu"
echo "If DNS request has not been complete yet, you may edit your hosts file adding line 107.21.105.193	dev.$DATABASE.umd.edu"
echo "Be sure to remove from your hosts file after testing"
