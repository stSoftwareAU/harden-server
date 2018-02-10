#!/bin/bash
set -e

#clean up /boot directory first: remove all linux kernels that are not currently running
dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e `uname -r | cut -f1,2 -d"-"` | grep -e [0-9] | grep -E "(image|headers)" | xargs sudo apt-get -y purge

sudo apt-get update
sudo apt-get upgrade --allow-unauthenticated -y
sudo apt-get autoclean
sudo apt-get dist-upgrade
sudo apt-get check
sudo apt-get -y purge
sudo apt-get autoremove -y
sudo update-grub

if [ -f /etc/init.d/php7.0-fpm ]; then

  sudo /etc/init.d/php7.0-fpm restart
fi
