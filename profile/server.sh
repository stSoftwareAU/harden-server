#!/bin/bash
set -e

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
  user=$1
  if [[ $user = *[!\ ]* ]]; then
    ret=false
    sudo getent passwd $1 >/dev/null 2>&1 && ret=true

    if $ret; then
      echo "User '$1' exists"
    else
      sudo useradd -g www-data -m -s /bin/bash $1
    fi
  fi
}


installPackages() {

  ## list of packages
  packagelist=(
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
  addUser 'docmgr';
  addUser 'webapps';
  addUser $PROD_USER;
  addUser $UAT_USER;
}

fetchInstaller(){
  if (( $EUID == 0 )); then
    echo "do not run as root"
    exit
  fi
  set -e

  rsync -hlptvcz --progress --stats www1.stsoftware.com.au:/home/jenkins/release/${PREFIX}Installer.jar /tmp/
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

installST(){
  if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
  fi

  sed --in-place='.bak' -r 's/^[\t #]*workers.tomcat_home=.*$/workers.tomcat_home=\/home\/webapps\/${PREFIX}Server\/server\//g' /etc/libapache2-mod-jk/workers.properties

  cat << EOF1 > /home/webapps/install.sh
#!/bin/bash
set -e
cd 
java -jar /tmp/${PREFIX}Installer.jar

tmp=\`ls -d ${PREFIX}Server20* |sort -r| head -1\`
today=\`expr "\$tmp" : '^[a-zA-Z]*\([0-9]*\)'\`

mkdir -p cache 
mkdir -p logs 

if [ -f ${PREFIX}Server\$today/logs ]; then
  rm -fr ${PREFIX}Server\$today/logs
fi

ln -s ~/logs ${PREFIX}Server\$today/logs 
cd ${PREFIX}Server\$today
java -jar launcher.jar download
cd

if [ -s ${PREFIX}Server ]; then
  cd ${PREFIX}Server\$today
  java -jar launcher.jar configure
  cd
  rm ${PREFIX}Server
fi

ln -s ${PREFIX}Server\$today ${PREFIX}Server
EOF1

  chmod 700 /home/webapps/install.sh
  chown webapps:www-data /home/webapps/install.sh
  su -c "/home/webapps/install.sh" -l webapps

  if [ ! -f /home/webapps/stop.sh ]; then
    cat << EOF2 > /home/webapps/stop.sh
#!/bin/bash

kill -9 `ps -ef |grep java|grep -v grep |grep ${PREFIX}Server| cut -c 10-15,16-20` > /dev/null 2>&1

EOF2

    chmod 700 /home/webapps/stop.sh
    chown webapps:www-data /home/webapps/stop.sh
  fi

  if [ ! -f /home/webapps/start.sh ]; then
    cat << EOF > /home/webapps/start.sh
#!/bin/bash
cd 
mkdir -p logs
~/stop.sh

cd ~/${PREFIX}Server

rm -rf cache
rm -rf /tmp/${PREFIX}Server/cache
mkdir -p /tmp/${PREFIX}Server/cache
ln -s /tmp/${PREFIX}Server/cache cache
cp -an docs/* /tmp/${PREFIX}Server/cache

rm -rf ~/${PREFIX}Server/logs
ln -s ~/logs ~/${PREFIX}Server/logs

ulimit -n 4000

~/stop.sh

java -jar launcher.jar build
cd bin
nohup ./jms.sh &
sleep 5;
nohup ./worker.sh &
sleep 5;
nohup ./emailscan.sh &
sleep 5;
nohup ./eventmgr.sh &
sleep 5;
nohup ./server.sh &

EOF

    chmod 700 /home/webapps/start.sh
    chown webapps:www-data /home/webapps/start.sh
  fi

  if [ ! -f /etc/init.d/stSoftware ]; then
    cat << EOF > /etc/init.d/stSoftware
#! /bin/bash
### BEGIN INIT INFO
# Provides:          stSoftware init script
# Required-Start:    apache2
# Required-Stop:     
# Should-Start:      networking
# Should-stop:
# Default-Start:     
# Default-Stop:
# X-Interactive:     
# Short-Description: start the stSoftware servers.
### END INIT INFO

start() {
  (sleep 60 && sudo -u webapps -i /home/webapps/start.sh ) > /var/log/stSoftware.log 2>&1 &
}

stop() {
  sudo -u webapps -i /home/webapps/stop.sh
}

case "\$1" in 
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  status)
    echo "status was called"
    ;;
  *)
    echo "Usage: \$0 {start|stop|status|restart}"
esac
exit 0 

EOF

    chmod u+x /etc/init.d/stSoftware
  fi

  if [ ! -L /etc/rc3.d/S99stSoftware ]; then
    ln -s /etc/init.d/stSoftware /etc/rc3.d/S99stSoftware
  fi

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
  options=( "Configure" "Create groups" "Create users" "Install packages" "Change Postgres PW" "SSH auto login" "Update OS/Scripts" "fetch Installer" "InstallST @sudo" "Firewall" "Apache" "Lets Encrypt" "Timezone" "Intrusion Detection")

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
      9 ) installST;;
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