#!/bin/bash
set -e

  if [ ! -f /etc/logwatch/conf/logwatch.conf ]; then
    echo "logwatch config... "
    sudo cp /usr/share/logwatch/default.conf/logwatch.conf /tmp/logwatch.conf

    sudo sed --in-place -r 's/^[\t #]*MailTo *=.*$/MailTo = support@stsoftware.com.au/g' /tmp/logwatch.conf
    sudo sed --in-place -r 's/^[\t #]*MailFrom *=.*$/MailFrom = logwatch@$HOSTNAME/g' /tmp/logwatch.conf
    sudo sed --in-place -r 's/^[\t ]*Range *=.*$/Range = between -7 days and Today/g' /tmp/logwatch.conf
    sudo sed --in-place -r 's/^[\t #]*Format *=.*$/Format = html/g' /tmp/logwatch.conf
    
    sudo chown root:root /tmp/logwatch.conf
    sudo chmod 644 /tmp/logwatch.conf
    
    sudo mv /tmp/logwatch.conf /etc/logwatch/conf/logwatch.conf
  fi
  sudo mkdir -p /var/cache/logwatch
  if [ -f /etc/cron.daily/00logwatch ]; then
     echo "re-scheduling logwatch from daily -> weekly"
     sudo mv /etc/cron.daily/00logwatch /etc/cron.weekly/
  fi
