#!/bin/bash

set -e
if (( $EUID != 0 )); then
    echo "Please run as root"
    exit 1
fi

timedatectl set-timezone "Australia/Sydney"
timedatectl set-ntp true
timedatectl status
