#!/bin/bash
set -e

defaults() {
  cd "$(dirname "$0")"
  

  profile='/etc/profile'
  if ! grep -q -e "/xenv/linux/x64/bashrc" "$profile"; then
    cp $profile /tmp/profile
    echo "if [ -f /xenv/linux/x64/bashrc ]; then" >> /tmp/profile
    echo ". /xenv/linux/x64/bashrc" >> /tmp/profile
    echo "fi" >> /tmp/profile

    sudo cp /tmp/profile $profile
  fi

  hosts="/etc/hosts"
  if ! grep -q -e "devserver8" "$hosts"; then
      cp $hosts /tmp/hosts
      echo "192.168.7.48	devserver7" >> /tmp/hosts
      echo "192.168.7.58	devserver8" >> /tmp/hosts
      echo "#60.241.239.222	devserver8" >> /tmp/hosts
      echo "#58.108.224.217	devserver8" >> /tmp/hosts
      sudo cp /tmp/hosts $hosts
  fi
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
#    "php-postgres"
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
    "maven"
  )
 
  #dpkg --get-selections > /tmp/packages.txt
  ## now loop through the above array
  for p in "${packagelist[@]}"
  do

#set +e
#    echo "$p"
#    grep "$p	*install" /tmp/packages.txt
#    grep -q "$p	*install" /tmp/packages.txt
   var=0
   set +e
   apt-cache policy $p|grep "Installed:" >/tmp/pstatus
   set -e
   if [ -s /tmp/pstatus ] 
   then
    if grep -q "(none)" /tmp/pstatus; then
       var=1
    fi
   else 
      var=2
   fi
#    echo "$p = $var"
#exit
#set -e
    if [ $var -ne 0 ] ; then
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

      if [ $p = "google-chrome-stable" ]; then
        sudo sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list'
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
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

  if [ ! -f /etc/apache2/mods-enabled/php7.0.conf ]; then
     sudo a2enmod php7.0
  fi 
  if [ -f /etc/apache2/mods-enabled/mpm_event.conf ]; then
     sudo a2dismod mpm_event
  fi
  if [ ! -f /etc/apache2/mods-enabled/mpm_prefork.conf ]; then
     sudo a2enmod mpm_prefork
  fi 
  sudo /etc/init.d/apache2 reload
}

updateOS() {
	who=`whoami`
	sudo mkdir -p /xenv
        addGroup sts;
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

jenkins(){

    conf='/etc/default/jenkins'
    if grep -q -e "HTTP_PORT=8080" "$conf"; then
        sudo sed --in-place -r 's/^[\t #]*HTTP_PORT=8080.*$/HTTP_PORT=9090/g' $conf

        sudo /etc/init.d/jenkins restart
    fi
}

jenkins;
defaults;
installPackages;
updateOS;

# vim: set ts=4 sw=4 sts=4 et:

