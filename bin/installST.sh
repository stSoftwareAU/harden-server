#!/bin/bash
set -e

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
