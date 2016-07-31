#!/bin/bash
set -e
addUser( ) {
    ret=false
    user="letsencrypt"
    getent passwd $user >/dev/null 2>&1 && ret=true

    if $ret; then
        echo "User '$user' exists"
    else
        useradd -g www-data -m -s /bin/bash $user
    fi
}

fetchFiles() {
    cd /home/letsencrypt/
    wget -O - https://raw.githubusercontent.com/stSoftwareAU/acme-cluster/master/acme_tiny.py > acme_tiny.py

    if [ ! -f sync.sh ]; then
        wget -O - https://raw.githubusercontent.com/stSoftwareAU/acme-cluster/master/sync.sh > sync.sh

        chmod 700 sync.sh
    fi

    if [ ! -f domains.txt ]; then
        touch domains.txt
        chmod 600 domains.txt
    fi

    wget -O - https://raw.githubusercontent.com/stSoftwareAU/acme-cluster/master/run.sh > run.sh
    chmod 700 run.sh

    chown letsencrypt:www-data *
}

generateKeys(){
   cd /home/letsencrypt
   mkdir -p keys
   mkdir -p csr
   mkdir -p certs
   if [ ! -f keys/account.key ]; then
       openssl genrsa 4096 > keys/account.key
   fi
   if [ ! -f keys/domain.key ]; then
        #generate a domain private key (if you haven't already)
        openssl genrsa 4096 > keys/domain.key
   fi

   if [ ! -d challenges ]; then
        #make some challenge folder
        mkdir -p challenges
   fi

   if [ ! -f keys/lets-encrypt-x3-cross-signed.pem ]; then
        cd keys
        wget -N https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem
        cd ..
   fi
   chown -R letsencrypt:www-data /home/letsencrypt/
   chmod 600 /home/letsencrypt/keys/*
   chmod -R o-xrw /home/letsencrypt/*
   chmod -R ugo+rx /home/letsencrypt/challenges
   chmod ugo+rx /home/letsencrypt
}

setupApache(){

 if ! grep -q "well-known/acme-challenge" /etc/apache2/sites-enabled/000-default.conf; then

  cat > /tmp/000-default.conf << EOF
Alias /.well-known/acme-challenge/ /home/letsencrypt/challenges/
<Directory /home/letsencrypt/challenges>
   AllowOverride None
   Require all granted
   Satisfy Any
</Directory>
EOF
   cat /etc/apache2/sites-enabled/000-default.conf >> /tmp/000-default.conf
   sed 's/JkMount \/\* \(.*\)/&\n\    JkUnMount \/.well-known\/acme-challenge\/\* \1/' /tmp/000-default.conf >/tmp/000-default.conf2
   cp /tmp/000-default.conf2 /etc/apache2/sites-enabled/000-default.conf
  fi

  /etc/init.d/apache2 restart
}

setupCron(){

    rm -f /tmp/crontab.txt

    tmpfile=$(mktemp /tmp/letsencrypt_cron.XXXXXX)

    cat >$tmpfile << EOF
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/home/letsencrypt/run.sh" /tmp/crontab.txt; then
     echo "0 2 * * 7 sleep \\\${RANDOM:0:2}m ; /home/letsencrypt/run.sh > /home/letsencrypt/run.log" >> /tmp/crontab.txt
     crontab < /tmp/crontab.txt
fi
EOF
    chmod 777 $tmpfile

    sudo -u letsencrypt $tmpfile
    rm $tmpfile

    rm -f /tmp/crontab.txt
    tmpfile=$(mktemp /tmp/apache_cron.XXXXXX)

    cat >$tmpfile << EOF2
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/etc/init.d/apache2" /tmp/crontab.txt; then
    echo "0 5 * * 7 /etc/init.d/apache2 reload >/dev/null" >> /tmp/crontab.txt
    crontab < /tmp/crontab.txt
fi
EOF2
   chmod 777 $tmpfile

   $tmpfile
   rm $tmpfile
   rm -f /tmp/crontab.txt
}

monitorSites(){
   if ! which inotifywait > /dev/null; then
        apt-get install inotify-tools
   fi
   cat > /etc/init.d/stMonitorSites << EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:          stSoftware monitor
# Required-Start:    apache2
# Required-Stop:     
# Should-Start:      networking
# Should-stop:
# Default-Start:     
# Default-Stop:
# X-Interactive:     
# Short-Description: start the stSoftware servers.
### END INIT INFO
set -e
PRG=$0

relink() {
    rm -f /etc/apache2/sites-enabled/100-*
    for f in /home/letsencrypt/sites/100-*; 
    do 
       ln -s \$f /etc/apache2/sites-enabled/ 
    done
    
    /etc/init.d/apache2 reload
}

start() {
    /etc/init.d/stMonitorSites monitor > /var/log/stMonitorSites.log 2>&1 &
}

stop() {
    
    ps -ef |grep \$PRG|grep -v grep |grep monitor| cut -c 10-15 > /tmp/kill_list.txt
    
    while read pid
    do
        kill \$pid
    done < /tmp/kill_list.txt
}

monitor() {
    if [ ! -f /home/letsencrypt/sites ]; then
        mkdir -p /home/letsencrypt/sites
        chown letsencrypt:www-data /home/letsencrypt/sites
    fi
    inotifywait -m -e modify -e create -e delete -q /home/letsencrypt/sites/ | while read site

    do
       echo "Changed: \$site"
       relink
    done
}
case "\$1" in 
    monitor)
       monitor
       ;;
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
    chmod u+x /etc/init.d/stMonitorSites
    rm -f /etc/rc3.d/*stMonitorSites
    ln -s /etc/init.d/stMonitorSites /etc/rc3.d/S99-stMonitorSites
    
    /etc/init.d/stMonitorSites restart
}

monitorSites;
addUser;
fetchFiles;
generateKeys;
setupApache;
setupCron;
