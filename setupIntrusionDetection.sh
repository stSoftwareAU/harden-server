#!/bin/bash
set -e

setupCronROOT(){

  tmpfile=$(mktemp /tmp/id_cron.XXXXXX)
  
  cat >$tmpfile << EOF
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/var/log/id-scan.txt" /tmp/crontab.txt; then
  echo "22 * * * nice ls -laRL /bin /root /boot /etc /opt /usr > /var/log/id-scan.working;mv /var/log/id-scan.working /var/log/id-scan.txt" >> /tmp/crontab.txt
  crontab < /tmp/crontab.txt
fi
rm /tmp/crontab.txt
EOF
  chmod 777 $tmpfile
  
  sudo $tmpfile
  rm $tmpfile
}
  
setupCronROOT
