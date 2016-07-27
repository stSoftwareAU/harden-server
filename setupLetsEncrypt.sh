#!/bin/bash
set -e
addUser( ) {
        ret=false
        user="letsencrypt"
        getent passwd $user >/dev/null 2>&1 && ret=true

        if $ret; then
            echo "User '$user' exists"
        else
            useradd -g www-data -m -s /bin/bash $user
        fi
}

fetchFiles() {
        cd /tmp
        rm acme_tiny.py
        wget https://raw.githubusercontent.com/stSoftwareAU/acme-cluster/master/acme_tiny.py
        
        cp acme_tiny.py /home/lersencrypt/
        chown letsencrypt:letsencrypt /home/lersencrypt/acme_tiny.py
}

addUser;
fetchFiles;
