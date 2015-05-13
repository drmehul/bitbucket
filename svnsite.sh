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
echo "WARNING: Please change into directory of local Acquia repo at braches,tags, trunk director
y level"
exit 1
fi

#Check if at correct directory level
if [ ! -d tags ]; then
echo "WARNING: Can't find tags directory"
echo "WARNING: Please change into directory of local Acquia repo at braches,tags, trunk director
y level"
exit 1
fi

#Check for sitename parameter
[ $# -eq 0 ] && { echo "Usage: $0 {sitename (with umd.edu)}" ; exit 1; }
#Make is easier to follow script where database is inserted
SITENAME=$1

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
mkdir trunk/docroot/sites/$SITENAME
mkdir trunk/docroot/sites/$SITENAME/modules
mkdir trunk/docroot/sites/$SITENAME/themes
#Copy the default settings.php
#cp trunk/docroot/sites/default/freshinstall.settings.php trunk/docroot/sites/$SITENAME/settings.php
#Breath for 5 seconds
#Edite the settings files
cat ./trunk/docroot/sites/default/freshinstall.settings.php | sed "s/EDITME/$SITENAME/" > ./trunk/docroot/sites/$SITENAME/settings.php
echo "Operations complete"
