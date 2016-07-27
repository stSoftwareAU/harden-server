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
        rm -f acme_tiny.py
        wget https://raw.githubusercontent.com/stSoftwareAU/acme-cluster/master/acme_tiny.py

        cp acme_tiny.py /home/letsencrypt/
        chown letsencrypt:www-data /home/letsencrypt/acme_tiny.py
}

generateKeys(){
   cd /home/letsencrypt
   mkdir -p keys
   mkdir -p csr
   if [ ! -f keys/account.key ]; then
       openssl genrsa 4096 > keys/account.key
   fi
   if [ ! -f keys/domain.key ]; then
        #generate a domain private key (if you haven't already)
        openssl genrsa 4096 > keys/domain.key
   fi

   if [ ! -d challenges ]; then
        #make some challenge folder
        mkdir -p challenges
   fi

   if [ ! -f keys/lets-encrypt-x3-cross-signed.pem ]; then
        cd keys
        wget -N https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem
        cd ..
   fi
   chown -R letsencrypt:www-data /home/letsencrypt/
   chmod 600 /home/letsencrypt/*key
   chmod -R go-xrw /home/letsencrypt/
}

addUser;
fetchFiles;
generateKeys;
