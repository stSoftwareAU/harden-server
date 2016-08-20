#!/bin/bash
set -e
addUser( ) {
    ret=false
    user="idscan"
    getent passwd $user >/dev/null 2>&1 && ret=true

    if $ret; then
        echo "User '$user' exists"
    else
        useradd -g adm -m -s /bin/bash $user
    fi
}

setupCronROOT(){

  tmpfile=$(mktemp /tmp/id_cron.XXXXXX)
  
  cat >$tmpfile << EOF
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/var/log/id-scan.txt" /tmp/crontab.txt; then
  echo "22 * * * * nice ls -laR /bin /root /boot /etc /opt /usr > /var/log/id-scan.working 2>1;mv /var/log/id-scan.working /var/log/id-scan.txt" >> /tmp/crontab.txt
  crontab < /tmp/crontab.txt
fi
rm /tmp/crontab.txt
EOF
  chmod 777 $tmpfile
  
  sudo $tmpfile
  rm $tmpfile
}

addUser
setupCronROOT
