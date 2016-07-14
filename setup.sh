#!/bin/bash
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
upgrade() {
        if (( $EUID != 0 )); then
            echo "Please run as root"
            exit
        fi

        apt-get update
        apt-get upgrade -y
        apt-get autoclean
        apt-get dist-upgrade
        apt-get check
        apt-get autoremove
        update-grub

}

installPackages() {
        add-apt-repository ppa:webupd8team/java
        apt-get install fail2ban openssh-server apache2 libapache2-mod-jk oracle-java8-installer postfix postgresql htop aspell
        update;
        ufw allow ssh
        ufw allow imap
        ufw allow http
        ufw allow https
        ufw disable
        ufw enable
        a2enmod ssl

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
#        env
        #if [ ! -f ~/.setup.pass ]; then
        if [ ! -s ~/.setup.pass ]; then
                strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 30 | tr -d '\n'>~/.setup.pass
        fi
        read pass < ~/.setup.pass
           echo "PW: $pass" 

        if [[ ! $pass = *[!\ ]* ]]; then
           echo "blank password"
           exit
        fi
        echo "psql -d postgres -U postgres<< EOF" > /tmp/pg.sh
        echo "alter user postgres with password '$pass';" >> /tmp/pg.sh
        echo "EOF">>/tmp/pg.sh
        chmod u+x /tmp/pg.sh
        su - postgres -c /tmp/pg.sh

        if [ -f ~/.pgpass ]; then
                cat ~/.pgpass |grep -v localhost > /tmp/zz
        else
                rm /tmp/zz
                touch /tmp/zz
        fi
        echo "localhost:*:*:postgres:$pass" >> /tmp/zz

        mv /tmp/zz ~/.pgpass
        chmod 0600 ~/.pgpass
        chown $SUDO_USER ~/.pgpass
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


        rsync -hlptvcz --progress --stats www1.stsoftware.com.au:/home/jenkins/release/${PREFIX}Installer.jar /tmp/
        chmod ugo+r /tmp/${PREFIX}Installer.jar
}

stepConfigure(){
        if (( $EUID == 0 )); then
            echo "do not run as root"
            exit
        fi

        read -e -p "Enter server: " -i "$PREFIX" PREFIX

        echo "PREFIX=$PREFIX" > ~/env.sh
        echo "export PREFIX" >> ~/env.sh
        chmod 700 ~/env.sh
}


installST(){
        if (( $EUID != 0 )); then
            echo "Please run as root"
            exit
        fi

        cat << EOF1 > /home/webapps/install.sh
#!/bin/bash
java -jar /tmp/${PREFIX}Installer.jar

tmp=\`ls -d ${PREFIX}Server20* |sort| head -1\`
today=\`expr "\$tmp" : '^[a-zA-Z]*\([0-9]*\)'\`
if [ -s ${PREFIX}Server ]; then
cd ${PREFIX}Server$today
java -jar launcher.jar configure
if [ $? != 0 ]; then
    echo 'configure failed' 1>&2
    exit 1
fi
fi
cd 
mkdir -p cache 
mkdir -p logs 

rm -fr ${PREFIX}Server\$today/logs
ln -s ~/logs ${PREFIX}Server\$today/logs 
rm ${PREFIX}Server
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

~/stop.sh

cd ~/${PREFIX}Server

rm -rf cache
rm -rf /tmp/${PREFIX}Server/cache
mkdir -p /tmp/${PREFIX}Server/cache
ln -s /tmp/${PREFIX}Server/cache cache
cp -an docs/* /tmp/${PREFIX}Server/cache


if [ ! -L ~/${PREFIX}Server/logs ]; then
  ln -s ~/logs ~/${PREFIX}Server/logs
fi

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
#!/bin/sh
# stSoftware init script
#. /lib/lsb/init-functions
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
}
allowHosts(){
cat /etc/hosts.allow | egrep -v "(192\.168\.7\.|\#ST)" >/tmp/hosts.allow
echo "sshd: 192.168.7.      #Local " >> /tmp/hosts.allow
echo "sshd: 60.241.239.222  #ST Office iinet" >> /tmp/hosts.allow
echo "sshd: 58.108.224.217  #ST Office optus" >> /tmp/hosts.allow
echo "sshd: 101.0.96.194    #ST www1"
echo "sshd: 101.0.106.2     #ST www2"
cp /tmp/hosts.allow /etc/hosts.allow

cat /etc/hosts.deny | egrep -v "sshd" >/tmp/hosts.deny
echo "sshd: ALL" >> /tmp/hosts.deny
cp /tmp/hosts.deny /etc/hosts.deny
}

menu() {

        title="Install"
        prompt="Pick an option:"
        options=( "Configure" "Create groups @sudo" "Create users @sudo" "Install packages @sudo" "Change Postgress PW @sudo" "SSH auto login" "Upgrade @sudo" "fetch Installer" "InstallST" "Allow Hosts @sudo")

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
                    7 ) upgrade;;
                    8 ) fetchInstaller;;
                    9 ) installST;;
                    10) allowHosts;;

                    *) echo "Invalid option. ";continue;;

            esac
            break

        done
}
defaults;

menu;

