#!/bin/bash
set -e


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
      if [ $p = 'java8' ]; then
        sudo add-apt-repository ppa:webupd8team/java
        sudo apt-get update;
      fi
      sudo apt-get install $p
      
#      if [ $p = 'logwatch' ]; then
#          sudo ./setupLogwatch.sh
#      fi
    fi
  done

  if [ ! -f /etc/apache2/mods-enabled/ssl.conf ]; then
     sudo a2enmod ssl
  fi 
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
#      13) sudo ./setupTimezone.sh;;
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
