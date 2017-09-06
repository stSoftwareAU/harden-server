#!/bin/bash
set -e

installPackages() {

  ## list of packages
  packagelist=(
    #"ssmtp"  email alerts
    "ffmpeg" # audio conversion
    "jq" # Handles JSON
    "fail2ban" 
    "openssh-server" 
    "apache2"
    "libapache2-mod-jk"
    "oracle-java8-installer"
    "postfix"
    "mailutils"
    "postgresql"
    "htop"
    "aspell"
    "git"
    "lynx"
    "unattended-upgrades"
    "logwatch"
    "ntp"
    "ca-certificates-java"
  )

  ## now loop through the above array
  for p in "${packagelist[@]}"
  do
    if  apt-cache policy $p|grep "Installed:" | grep "(none)"; then
      echo "Install: $p"
      if [ $p = 'oracle-java8-installer' ]; then
        sudo add-apt-repository ppa:webupd8team/java
        sudo apt-get update;
      fi
      sudo apt-get install $p
      
      if [ $p = 'logwatch' ]; then
          sudo ./setupLogwatch.sh
      fi
    fi
  done

  if [ ! -f /etc/apache2/mods-enabled/ssl.conf ]; then
     sudo a2enmod ssl
  fi 
}

#formatDisk(){
#  disk=$1
#  fdisk /dev/${disk}
#  mkfs -t ext4 /dev/${disk}1
#}

#mountData(){
#  mkdir -p /data
#  cat /etc/fstab |grep -v sdb1 > /tmp/fstab
#  echo "/dev/sdb1    /data   ext4    defaults     0        2" >> /tmp/fstab
#  cp /tmp/fstab /etc/fstab

#  mount /dev/sdb1 /data
#}

changePostgres(){
  set -e
  if [[ ! $PG_PASS = *[!\ ]* ]]; then
    echo "blank password"
    exit
  fi
  tmpfile=$(mktemp /tmp/pg_pass.XXXXXX)
  
  cat >$tmpfile << EOF
echo "alter user postgres with password '$PG_PASS';"|psql -d postgres -U postgres
  echo "update aspc_server set new_passwd='$PG_PASS'"|psql -U postgres aspc_master
EOF
  chmod 777 $tmpfile
  sudo su - postgres -c $tmpfile
  rm $tmpfile
  
  if [ -f ~/.pgpass ]; then
      cat ~/.pgpass |grep -v localhost > /tmp/zz
  else
    rm -f /tmp/zz
    touch /tmp/zz
  fi
  echo "localhost:*:*:postgres:$PG_PASS" >> /tmp/zz

  mv /tmp/zz ~/.pgpass
  chmod 0600 ~/.pgpass
  #chown $SUDO_USER:$SUDO_USER ~/.pgpass
}

autoSSH(){
  if [ "$(id -u)" != "0" ]; then
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
      ssh-keygen -b 4096
    fi
    #ssh-add

    echo "Enter user@host to copy the SSH public key:"
  
    read remote
    ssh-copy-id -i .ssh/id_rsa.pub $remote
  else
    echo "Must NOT be run as root" 
  fi
}
stepGroups() {
  addGroup 'sts';
  addGroup 'www-data';
}

stepUsers() {
  ../bin/create_user.sh docmgr www-data;
  ../bin/create_user.sh webapps www-data;
  ../bin/create_user.sh jenkins www-data;
  ../bin/create_user.sh support;
  ../bin/create_user.sh $PROD_USER www-data;
  ../bin/create_user.sh $UAT_USER www-data;
  ../bin/create_user.sh nigel sudo nigel@stsoftware.com.au;
  ../bin/create_user.sh lgao sudo lei@stsoftware.com.au;
  ../bin/create_user.sh jwiggins sudo jonathan@whizz-bang.com.au;
}

fetchInstaller(){
  if (( $EUID == 0 )); then
    echo "do not run as root"
    exit
  fi
  set -e

  rsync -hlptvcz --progress --stats www3.stsoftware.com.au:/home/jenkins/release/${PREFIX}Installer.jar /tmp/
  chmod ugo+r /tmp/${PREFIX}Installer.jar
}

stepConfigure(){
  if (( $EUID == 0 )); then
    echo "do not run as root"
    exit
  fi
  read -e -p "Enter server: " -i "$PREFIX" PREFIX
  read -e -p "Postgress Password: " -i "$PG_PASS" PG_PASS
  read -e -p "www1 IP: " -i "$WWW1_IP" WWW1_IP
  read -e -p "www2 IP: " -i "$WWW2_IP" WWW2_IP
  read -e -p "www3 IP: " -i "$WWW3_IP" WWW3_IP
  read -e -p "www4 IP: " -i "$WWW4_IP" WWW4_IP

  read -e -p "Enter production user: " -i "$PROD_USER" PROD_USER
  read -e -p "Enter UAT user: " -i "$UAT_USER" UAT_USER
  read -e -p "Enter local subnet: " -i "$LOCAL_SUBNET" LOCAL_SUBNET
  
  cat > ~/env.sh << EOF
PREFIX=$PREFIX
export PREFIX

WWW1_IP=$WWW1_IP
export WWW1_IP

WWW2_IP=$WWW2_IP
export WWW2_IP

WWW3_IP=$WWW3_IP
export WWW3_IP

WWW4_IP=$WWW4_IP
export WWW4_IP

PG_PASS="$PG_PASS"
export PG_PASS

PROD_USER=$PROD_USER
export PROD_USER

UAT_USER=$UAT_USER
export UAT_USER

LOCAL_SUBNET=$LOCAL_SUBNET
export LOCAL_SUBNET
EOF
  chmod 700 ~/env.sh
}


defaults() {
  cd "$(dirname "$0")"
   
  if [ -f  ~/env.sh ]; then
    . ~/env.sh
  fi

  if [[ ! $PREFIX = *[!\ ]* ]]; then
    PREFIX="jt"
  fi
  
  if [[ ! $PROD_USER = *[!\ ]* ]]; then
    PROD_USER="webapps"
  fi
  
  if [[ ! $LOCAL_SUBNET = *[!\ ]* ]]; then
    LOCAL_SUBNET="192.168.7."
  fi
}

setupFirewall() {
  
  hostsAllowTemp=$(mktemp /tmp/hosts.allow.XXXXXX)
  cat /etc/hosts.allow | egrep -v "(\#ST|\#Local)" > $hostsAllowTemp
  echo "sshd: $LOCAL_SUBNET      #Local "  >> $hostsAllowTemp
  echo "sshd: 60.241.239.222  #ST Office iinet" >> $hostsAllowTemp
  echo "sshd: 58.108.224.217  #ST Office optus" >> $hostsAllowTemp

  echo "sshd: 101.0.96.194    #ST www1" >> $hostsAllowTemp
  echo "sshd: 101.0.106.2     #ST www2" >> $hostsAllowTemp
  echo "sshd: 101.0.80.130    #ST www3" >> $hostsAllowTemp
  echo "sshd: 101.0.92.206    #ST www4" >> $hostsAllowTemp  

  echo "sshd: 172.16.23.234   #ST www1 (internal)" >> $hostsAllowTemp  
  echo "sshd: 172.16.8.186    #ST www2 (internal)" >> $hostsAllowTemp  
  echo "sshd: 172.16.41.26    #ST www3 (internal)" >> $hostsAllowTemp  
  echo "sshd: 101.0.92.206    #ST www4 (internal)" >> $hostsAllowTemp  
  echo "sshd: 58.106.         #ST Nigel home Optus" >> $hostsAllowTemp  
  echo "sshd: 101.0.100.18    #ST DP support" >> $hostsAllowTemp  
  echo "sshd: 101.0.101.203   #ST DP support" >> $hostsAllowTemp  

  hostsDenyTemp=$(mktemp /tmp/hosts.deny.XXXXXX)
  cat /etc/hosts.deny | egrep -v "sshd" > $hostsDenyTemp
  echo "sshd: ALL" >> $hostsDenyTemp
  
  sudo ufw disable
  sudo ufw allow ssh
  #sudo ufw allow imap
  sudo ufw allow http
  sudo ufw allow https
  sudo ufw allow 8080
  if [[ $WWW1_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW1_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW1_IP to any port 8009
    # Tomcat ajp13 uat
    sudo ufw allow from $WWW1_IP to any port 7009
    # JMS
    sudo ufw allow from $WWW1_IP to any port 61616
    echo "sshd: $WWW1_IP    #ST www1 (internal)" >> $hostsAllowTemp
  fi
  if [[ $WWW2_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW2_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW2_IP to any port 8009
    # Tomcat ajp13 uat
    sudo ufw allow from $WWW2_IP to any port 7009
    # JMS
    sudo ufw allow from $WWW2_IP to any port 61616
    echo "sshd: $WWW2_IP    #ST www2 (internal)" >> $hostsAllowTemp
  fi
  if [[ $WWW3_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW3_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW3_IP to any port 8009
    # Tomcat ajp13
    sudo ufw allow from $WWW3_IP to any port 7009
    # JMS
    sudo ufw allow from $WWW3_IP to any port 61616
    echo "sshd: $WWW3_IP    #ST www3 (internal)" >> $hostsAllowTemp
  fi
  if [[ $WWW4_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW4_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW4_IP to any port 8009
    # Tomcat ajp13
    sudo ufw allow from $WWW4_IP to any port 7009
    # JMS
    sudo ufw allow from $WWW4_IP to any port 61616
    echo "sshd: $WWW4_IP    #ST www4 (internal)" >> $hostsAllowTemp
  fi
  sudo ufw enable
  
  sudo sed --in-place -r 's/^[\t #]*PermitRootLogin .*$/PermitRootLogin no/g' /etc/ssh/sshd_config

  sudo cp $hostsAllowTemp /etc/hosts.allow
  sudo cp $hostsDenyTemp  /etc/hosts.deny
}

menu() {

  title="Server Hardene"
  prompt="Pick an option:"
  options=(
      "Configure"
      "Create groups"
      "Create users"
      "Install packages"
      "Change Postgres PW"
      "SSH auto login"
      "Update OS/Scripts"
      "fetch Installer"
      "Install ST"
      "Firewall"
      "Apache"
      "Lets Encrypt"
      "Timezone"
      "Intrusion Detection"
)

  echo "$title"
  PS3="$prompt "
  select opt in "${options[@]}" ; do

    case "$REPLY" in

      1 ) stepConfigure;;
      2 ) stepGroups;;
      3 ) stepUsers;;
      4 ) installPackages;;
      5 ) changePostgres;;
      6 ) autoSSH;;
      7 ) sudo ../bin/updateOS.sh;;
      8 ) fetchInstaller;;
      9 ) sudo ../bin/installST.sh $PREFIX $PROD_USER;;
      10) setupFirewall;;
      11) sudo ../setupApache.sh;;
      12) sudo ../setupLetsEncrypt.sh;;
      13) sudo ../setupTimezone.sh;;
      14) sudo ../setupIntrusionDetection.sh;;
      *) 
        echo "Invalid option. ";
        continue;;
    esac
    break
  done
}

defaults;

menu;
