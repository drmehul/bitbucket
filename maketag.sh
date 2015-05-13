#!/bin/sh
# This script will make a copy of prod tag
# and merge site specific changes to trunk
# Please copy script to location outside your localrepo location
# but run script while pwd = your localroot
# Please check svn status first, to make sure you do not have any conflicting files first

SVNCHECK=`svn info 2>&1 | grep acquia`
#echo $?
if [ $? -ne '0' ]; then
echo "WARNING: Does not appear you are in local Acquia repo"
echo "WARNING: Please change into directory of local Acquia repo at braches,tags, trunk directory level"
exit 1
fi

#Check if at correct directory level
if [ ! -d tags ]; then
echo "WARNING: Can't find tags directory"
echo "WARNING: Please change into directory of local Acquia repo at braches,tags, trunk directory level"
exit 1
fi



#script on bamboo servers needs help finding drush and alias files
#Path and Aliaspath not for use on local laptops, please comment only for use on bamboo servers.
#PATH=${PATH}:/cell_root/software/drush/current/:/usr/local/bin/
#DRUSHOPTS="--alias-path=/root/.drush --include=/root/.drush --config=/root/.drush/umddrupal.acapi.drushrc.php"


#Check for sitename parameter
[ $# -eq 0 ] && { echo "Usage: $0 {sitename (with umd.edu)}" ; exit 1; }
#Make is easier to follow script where database is inserted
SITENAME=$1

#Verify that url exists
SITECHECK=`drush $DRUSHOPTS @umddrupal.prod ac-domain-info $SITENAME 2>&1 | grep name | cut -c 2-5`
if [ "$SITECHECK" != 'name' ]; then
echo "WARNING: Invalid sitename specified, please check sitename"
echo "WARNING: Please be sure to include '.umd.edu'"
echo "INFO: Usage: $0 {sitename (with umd.edu)}"
exit 1
fi

#FInd the current prod tag
TAGPROD=`drush @umddrupal.prod ac-environment-info | grep vcs_path | cut -d " " -f13`
#echo $TAGPROD
#Server needs a break
sleep 5

#Make a new tag from current production tag
TAGNEW="`date +%Y-%m-%d`_$SITENAME"
#echo $TAGNEW

echo "INFO: Initial checks passed. Proceeding with making tag $TAGNEW"

SVNCOPY=`svn copy https://svn-6098.prod.hosting.acquia.com/umddrupal/$TAGPROD https://svn-6098.prod.hosting.acquia.com/umddrupal/tags/$TAGNEW -m "Creating tag $TAGNEW for code deploy for $SITENAME" 2>&1`
#echo $SVNCOPY
if [ $? -ne '0' ]; then
echo "FATAL: Something went wrong with SVN copy"
echo "FATAL: Please check that tag does not exist already"
echo "FATAL: Don't know what to do, exiting for now"
exit 1
fi
#SVN server may need time for the commit of copy to process
echo "INFO: Script needs to sleep 3m to allow SVN server to commit new tag"
sleep 180


#Update our local working copy to perform merge
svn up --parents --set-depth infinity tags/$TAGNEW/docroot/sites/$SITENAME 2>&1
if [ $? -ne '0' ]; then
echo "FATAL: Something went wrong with updating working SVN copy"
echo "FATAL: Don't know what to do, exiting for now"
exit 1
fi

#Time for the merge
#Hope all goes well
svn merge https://svn-6098.prod.hosting.acquia.com/umddrupal/trunk/docroot/sites/$SITENAME tags/$TAGNEW/docroot/sites/$SITENAME
if [ $? -ne '0' ]; then
echo "FATAL: Something went wrong with SVN merge for $TAGNEW/docroot/sites/$SITENAME"
echo "FATAL: Don't know what to do, exiting for now"
exit 1
fi


#commit the merged stuff
svn commit -m "Commiting merged changes for $SITENAME from $TAGPROD to tags/$TAGNEW"
if [ $? -ne '0' ]; then
echo "FATAL: Something went wrong with SVN commit  for $TAGNEW/docroot/sites/$SITENAME"
echo "FATAL: Don't know what to do, exiting for now"
exit 1
fi

echo "INFO: Tag $TAGNEW has been created, changes for $SITENAME in trunk have been merged into $TAGNEW"
echo "INFO: Please confirm which tag is deployed to stage environment. If tag is same as Production you may deploy this new tag"
