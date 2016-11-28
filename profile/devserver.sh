#!/bin/bash
set -e

defaults() {
  cd "$(dirname "$0")"
  
}

addGroup( ) {
  ret=false
  sudo getent group $1 >/dev/null 2>&1 && ret=true

  if ! $ret; then
    sudo groupadd $1
  fi
}

installPackages() {
  ## do not ask if you want to install a package for apt-get command
  export DEBIAN_FRONTEND=noninteractive
  
  ## list of packages
  packagelist=(
#    "postfix"
#    "mailutils"
#    "logwatch"    
    "php-dev"
    "php"
    "libapache2-mod-php"
    "php-mcrypt"
    "php-postgres"
    "php-pgsql"
    "google-chrome-stable" 
    "fail2ban" 
    "openssh-server" 
    "apache2"
    "libapache2-mod-jk"
    "htop"
    "aspell"
    "git"
    "lynx"
    "unattended-upgrades"
    "landscape-client"
    "ntp"
    "postgresql"
    "oracle-java8-installer"
    "vim"
    "jenkins"
    "meld"
    "ffmpeg"
    "mailutils"
  )
 
  ## now loop through the above array
  for p in "${packagelist[@]}"
  do
    if  apt-cache policy $p|grep "Installed:" | grep "(none)"; then
      echo "Install: $p"
      if [ $p = 'oracle-java8-installer' ]; then
        echo "adding ppa:webupd8team/java..."
        sudo add-apt-repository ppa:webupd8team/java
        sudo apt-get update;
      fi
      if [ $p = "jenkins" ]; then
	wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
	sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
        sudo apt-get update;
      fi 

      sudo apt-get -y install $p
      
      if [ $p = 'php-dev' ]; then
          sudo pecl install xdebug
      fi
      if [ $p = 'ntp' ]; then
          sudo ../setupTimezone.sh
      fi
      
      if [ $p = 'vim' ]; then
         if [ ! -f ~/.vimrc ]; then
            echo "set modelines=1" > ~/.vimrc
            echo "set nocompatible" >> ~/.vimrc
         fi
      fi
    fi
  done

  if [ ! -f /etc/apache2/mods-enabled/ssl.conf ]; then
     sudo a2enmod ssl
  fi 
}

updateOS() {
	who=`whoami`
	sudo mkdir -p /xenv
	sudo chown -R $who:sts /xenv
	#mkdir -p $HOME/backup
	#rsync -rhlptvcz --progress --stats --delete --ignore-errors --force --backup --backup-dir=$HOME/backup devserver8:/xenv/ /xenv/

	../bin/create_user.sh support;
	../bin/create_user.sh nigel sudo nigel@stsoftware.com.au;
	../bin/create_user.sh lgao sudo lei@stsoftware.com.au;
	../bin/create_user.sh harry sudo harry@stsoftware.com.au;
	../bin/create_user.sh william sudo william@stsoftware.com.au;
	../bin/create_user.sh parminder sudo parminder@stsoftware.com.au;

	if [ ! -d /xenv/.git ]; then

	rm -fr /xenv/*
	git clone git@github.com:stSoftwareAU/xenv.git /xenv
	fi
	CWD="cd `pwd`"
	cd /xenv/
	git pull

	$CWD
	sudo ../bin/updateOS.sh
}

defaults;
installPackages;
updateOS;

# vim: set ts=4 sw=4 sts=4 et:

