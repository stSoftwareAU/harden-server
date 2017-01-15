#!/bin/bash
set -e

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoclean
sudo apt-get dist-upgrade
sudo apt-get check
sudo apt-get autoremove -y
sudo update-grub

if [ -f /etc/init.d/php7.0-fpm ]; then

  sudo /etc/init.d/php7.0-fpm restart
fi
