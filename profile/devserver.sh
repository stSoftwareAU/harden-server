#!/bin/bash
set -e

defaults() {
  cd "$(dirname "$0")"

  addGroup sts
  addUser nigel
  addUser lgao
}

addGroup( ) {
  ret=false
  sudo getent group $1 >/dev/null 2>&1 && ret=true

  if $ret; then
    echo "group '$1' exists"
  else
    sudo groupadd $1
  fi
}

addUser( ) {
    ret=false
    sudo getent passwd $1 >/dev/null 2>&1 && ret=true

    if $ret; then
      echo "User '$1' exists"
    else
      sudo useradd -g sts -m -s /bin/bash $1
    fi
}

installPackages() {

  ## list of packages
  packagelist=(
#    "postfix"
#    "mailutils"
#    "logwatch"    
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
      
#      if [ $p = 'logwatch' ]; then
#          sudo ./setupLogwatch.sh
#      fi
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
mkdir -p $HOME/backup
rsync -rhlptvcz --progress --stats --delete --ignore-errors --force --backup --backup-dir=$HOME/backup devserver8:/xenv/ /xenv/

sudo ../bin/updateOS.sh
}

menu() {

  title="Server Hardene"
  prompt="Pick an option:"
  options=( 
#    "Configure" 
#    "Create groups" 
#    "Create users" 
    "Install packages" 
#    "Change Postgres PW" 
#    "SSH auto login" 
    "Update OS/Scripts" 
#    "fetch Installer" 
#    "InstallST @sudo" 
#    "Firewall" 
#    "Apache" 
#    "Lets Encrypt" 
    "Timezone" 
#    "Intrusion Detection"
    )

  echo "$title"
  PS3="$prompt "
  select opt in "${options[@]}" ; do

    case "$REPLY" in

#      1 ) stepConfigure;;
#      2 ) stepGroups;;
#      3 ) stepUsers;;
      1 ) installPackages;;
#      5 ) changePostgres;;
#      6 ) autoSSH;;
      2 ) updateOS;;
#      8 ) fetchInstaller;;
#      9 ) installST;;
#      10) setupFirewall;;
#      11) sudo ./setupApache.sh;;
#      12) sudo ./setupLetsEncrypt.sh;;
      3) sudo ../setupTimezone.sh;;
#      14) sudo ./setupIntrusionDetection.sh;;
      *) 
        echo "Invalid option. ";
        continue;;
    esac
    break
  done
}

defaults;

menu;
