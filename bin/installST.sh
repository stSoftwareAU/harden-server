#!/bin/bash
set -e

PREFIX=$1
if [[ ! $PREFIX = *[!\ ]* ]]; then
    echo "blank PREFIX"
    exit
fi

USER=$2
if [[ ! $USER = *[!\ ]* ]]; then
    echo "blank USER"
    exit
fi

  if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
  fi

  sed --in-place='.bak' -r 's/^[\t #]*workers.tomcat_home=.*$/workers.tomcat_home=\/home\/${USER}\/${PREFIX}Server\/server\//g' /etc/libapache2-mod-jk/workers.properties

  cat << EOF1 > /home/${USER}/install.sh
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

  chmod 700 /home/${USER}/install.sh
  chown ${USER}:www-data /home/${USER}/install.sh
  su -c "/home/${USER}/install.sh" -l ${USER}

  if [ ! -f /home/${USER}/stop.sh ]; then
    cat << EOF2 > /home/${USER}/stop.sh
#!/bin/bash

kill -9 `ps -ef |grep java|grep -v grep |grep ${PREFIX}Server| cut -c 10-15,16-20` > /dev/null 2>&1

EOF2

    chmod 700 /home/${USER}/stop.sh
    chown ${USER}:www-data /home/${USER}/stop.sh
  fi

  if [ ! -f /home/${USER}/start.sh ]; then
    cat << EOF > /home/${USER}/start.sh
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

    chmod 700 /home/${USER}/start.sh
    chown ${USER}:www-data /home/${USER}/start.sh
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
  (sleep 60 && sudo -u ${USER} -i /home/${USER}/start.sh ) > /var/log/stSoftware.log 2>&1 &
}

stop() {
  sudo -u ${USER} -i /home/${USER}/stop.sh
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


