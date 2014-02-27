#!/bin/sh
#Determine servers to connect to
ENV=dev
TARENV=test

FILESOURCE=`drush @umddrupal.$ENV ac-environment-info | grep ssh_host | cut -c 22-57 | tr -d ' '`
FILEDEST=`drush @umddrupal.$TARENV ac-environment-info | grep ssh_host | cut -c 22-57 | tr -d ' '`
 
echo $FILESOURCE
echo $FILEDEST
ssh -o ForwardAgent=yes umddrupal@$FILESOURCE scp -r /mnt/www/html/umddrupal.$ENV/docroot/sites/bamboo.umd.edu/files umddrupal@$FILEDEST:/var/www/html/umddrupal.$TARENV/docroot/sites/bamboo.umd.edu/
