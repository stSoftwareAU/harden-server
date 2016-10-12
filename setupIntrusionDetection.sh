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
setupCronID(){

  tmpfile=$(mktemp /tmp/id_cron.XXXXXX)
  
  cat >$tmpfile << EOF
#!/bin/bash
set +e  
cronfile=\$(mktemp /tmp/tmp_cron.XXXXXX)
crontab -l > \$cronfile
set -e
if ! grep -q "detect.sh" \$cronfile; then
  echo "*/15 * * * * ~/detect.sh &> detect.log" >> \$cronfile
  crontab < \$cronfile
fi
rm \$cronfile
EOF
  chmod 777 $tmpfile
  
  sudo -u idscan $tmpfile
  rm $tmpfile
}
setupCronROOT(){

  tmpfile=$(mktemp /tmp/root_cron.XXXXXX)
  
  cat >$tmpfile << EOF
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/var/log/id-scan.txt" /tmp/crontab.txt; then
  echo "22 * * * * nice ls -laR /bin /root /boot /etc /opt /usr &> /var/log/id-scan.working;mv /var/log/id-scan.working /var/log/id-scan.txt" >> /tmp/crontab.txt
  crontab < /tmp/crontab.txt
fi
rm /tmp/crontab.txt
EOF
  chmod 777 $tmpfile
  
  sudo $tmpfile
  rm $tmpfile
}
fetchFiles(){

  tmpfile=$(mktemp /tmp/id_fetch.XXXXXX)
  
  cat >$tmpfile << EOF
#!/bin/bash
set +e  
wget -O - https://raw.githubusercontent.com/stSoftwareAU/harden-server/master/detect.sh > detect.sh
chmod u+x detect.sh
EOF
  chmod 777 $tmpfile
  
  sudo -u idscan $tmpfile
  rm $tmpfile
}
addUser
setupCronROOT
setupCronID
fetchFiles
