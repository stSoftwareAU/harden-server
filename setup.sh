#!/bin/bash
set -e

addGroup( ) {
  ret=false
  getent group $1 >/dev/null 2>&1 && ret=true

  if $ret; then
    echo "group '$1' exists"
  else
    groupadd $1
  fi
}

addUser( ) {
    ret=false
    getent passwd $1 >/dev/null 2>&1 && ret=true

    if $ret; then
      echo "User '$1' exists"
    else
      useradd -g www-data -m -s /bin/bash $1
    fi
}
updateOS() {
  cd 
  
  wget -O - https://raw.githubusercontent.com/stSoftwareAU/harden-server/master/setup.sh > setup.sh

  chmod u+x setup.sh
  
  tmpfile=$(mktemp /tmp/pg_pass.XXXXXX)
  
  cat >$tmpfile << EOF
apt-get update
apt-get upgrade -y
apt-get autoclean
apt-get dist-upgrade
apt-get check
apt-get autoremove
update-grub
EOF
  chmod 777 $tmpfile
  sudo  $tmpfile
  rm $tmpfile
}

installPackages() {
  tmpfile=$(mktemp /tmp/install.XXXXXX)
  
  cat >$tmpfile << EOF
add-apt-repository ppa:webupd8team/java
apt-get update;
apt-get install fail2ban openssh-server apache2 libapache2-mod-jk oracle-java8-installer postfix postgresql htop aspell git
apt-get install lynx unattended-upgrades
a2enmod ssl
EOF
  chmod 777 $tmpfile
  sudo $tmpfile
  rm $tmpfile
}

formatDisk(){
  disk=$1
  fdisk /dev/${disk}
  mkfs -t ext4 /dev/${disk}1
}

mountData(){
  mkdir -p /data
  cat /etc/fstab |grep -v sdb1 > /tmp/fstab
  echo "/dev/sdb1    /data   ext4    defaults     0        2" >> /tmp/fstab
  cp /tmp/fstab /etc/fstab

  mount /dev/sdb1 /data
}

changePostgres(){
  if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
  fi

  if [[ ! $PG_PASS = *[!\ ]* ]]; then
    echo "blank password"
    exit
  fi
  tmpfile=$(mktemp /tmp/pg_pass.XXXXXX)
  
  cat >$tmpfile << EOF
echo "alter user postgres with password '$PG_PASS';"|psql -d postgres -U postgres
EOF
  chmod 777 $tmpfile
  su - postgres -c $tmpfile
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
  chown $SUDO_USER:$SUDO_USER ~/.pgpass
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

PG_PASS=$PG_PASS
export PG_PASS

PROD_USER=$PROD_USER
export PROD_USER

UAT_USER=$UAT_USER
export UAT_USER
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
#! /bin/sh
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
  if [ -f  ~/env.sh ]; then
    . ~/env.sh
  fi

  if [[ ! $PREFIX = *[!\ ]* ]]; then
    PREFIX="jt"
  fi
  
  if [[ ! $PROD_USER = *[!\ ]* ]]; then
    PROD_USER="webapps"
  fi
}

allowHosts(){
    tmpfile=$(mktemp /tmp/allow-script.XXXXXX)
    
    cat >$tmpfile << EOF
cat /etc/hosts.allow | egrep -v "(192\.168\.|\#ST|\#Local)" >/tmp/hosts.allow
echo "sshd: 192.168.7.      #Local " >> /tmp/hosts.allow
echo "sshd: 60.241.239.222  #ST Office iinet" >> /tmp/hosts.allow
echo "sshd: 58.108.224.217  #ST Office optus" >> /tmp/hosts.allow
echo "sshd: 101.0.96.194    #ST www1"
echo "sshd: 101.0.106.2     #ST www2"
cp /tmp/hosts.allow /etc/hosts.allow
rm /tmp/hosts.allow
cat /etc/hosts.deny | egrep -v "sshd" >/tmp/hosts.deny
echo "sshd: ALL" >> /tmp/hosts.deny
cp /tmp/hosts.deny /etc/hosts.deny
rm /tmp/hosts.deny
EOF
        
  chmod 777 $tmpfile
  sudo $tmpfile
  rm $tmpfile
}

setupFirewall() {
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
    # JMS
    sudo ufw allow from $WWW1_IP to any port 61616
  fi
  if [[ $WWW2_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW2_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW2_IP to any port 8009
    # JMS
    sudo ufw allow from $WWW2_IP to any port 61616
  fi
  if [[ $WWW3_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW3_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW3_IP to any port 8009
    # JMS
    sudo ufw allow from $WWW3_IP to any port 61616
  fi
  if [[ $WWW4_IP = *[!\ ]* ]]; then
    # Postgres
    sudo ufw allow from $WWW4_IP to any port 5432
    # Tomcat ajp13
    sudo ufw allow from $WWW4_IP to any port 8009
    # JMS
    sudo ufw allow from $WWW4_IP to any port 61616
  fi
  sudo ufw enable
}

setupApache() {
  cd /tmp
  rm setupApache.sh
  wget https://github.com/stSoftwareAU/harden-server/raw/master/setupApache.sh
  chmod 777 setupApache.sh
  sudo ./setupApache.sh
}

setupLetsEncrypt() {
  cd /tmp
  rm setupLetsEncrypt.sh
  wget https://github.com/stSoftwareAU/harden-server/raw/master/setupLetsEncrypt.sh
  chmod 777 setupLetsEncrypt.sh
  sudo ./setupLetsEncrypt.sh
}

setupIntrusionDetection(){
  cd /tmp
  rm -f setupIntrusionDetection.sh
  wget https://github.com/stSoftwareAU/harden-server/raw/master/setupIntrusionDetection.sh
  chmod 777 setupIntrusionDetection.sh
  sudo ./setupIntrusionDetection.sh
}

menu() {

  title="Server Hardene"
  prompt="Pick an option:"
  options=( "Configure" "Create groups @sudo" "Create users @sudo" "Install packages" "Change Postgress PW @sudo" "SSH auto login" "Update OS/Scripts" "fetch Installer" "InstallST @sudo" "Allow Hosts" "Firewall" "Apache" "Lets Encrypt" "Intrusion Detection")

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
      7 ) updateOS;;
      8 ) fetchInstaller;;
      9 ) installST;;
      10) allowHosts;;
      11) setupFirewall;;
      12) setupApache;;
      13) setupLetsEncrypt;;
      14) setupIntrusionDetection;;

      *) echo "Invalid option. ";continue;;
    esac
    break

  done
}

defaults;

menu;
