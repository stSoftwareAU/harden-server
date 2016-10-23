#!/bin/bash
set -e

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoclean
sudo apt-get dist-upgrade
sudo apt-get check
sudo apt-get autoremove
sudo update-grub
