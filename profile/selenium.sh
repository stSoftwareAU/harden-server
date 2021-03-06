#!/bin/bash
set -e

if (( $EUID == 0 )); then
    echo "Please do not run as root."
    exit 1
fi

cd "$(dirname "$0")"

./devserver.sh

if ! sudo grep -q -e "jenkins" "/etc/sudoers"; then
    sudo cp /etc/sudoers /tmp/sudoers
    sudo chmod go+rw /tmp/sudoers

    echo "jenkins ALL = (selenium) NOPASSWD: /home/selenium/config-selenium/tp_web.sh" >> /tmp/sudoers
    sudo chmod go-rw /tmp/sudoers
    sudo cp /tmp/sudoers /etc/sudoers
fi

if ! sudo grep -q -e "/etc/init.d/postgresql" "/etc/sudoers"; then
    sudo cp /etc/sudoers /tmp/sudoers
    sudo chmod go+rw /tmp/sudoers

    echo "jenkins ALL =  NOPASSWD: /etc/init.d/postgresql" >> /tmp/sudoers
    sudo chmod go-rw /tmp/sudoers
    sudo cp /tmp/sudoers /etc/sudoers
fi

if ! sudo grep -q -e "/etc/init.d/php7.0-fpm" "/etc/sudoers"; then
    sudo cp /etc/sudoers /tmp/sudoers
    sudo chmod go+rw /tmp/sudoers

    echo "jenkins ALL =  NOPASSWD: /etc/init.d/php7.0-fpm" >> /tmp/sudoers
    sudo chmod go-rw /tmp/sudoers
    sudo cp /tmp/sudoers /etc/sudoers
fi


