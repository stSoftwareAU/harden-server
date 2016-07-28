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
        cd /home/letsencrypt/
        wget -O - https://raw.githubusercontent.com/stSoftwareAU/acme-cluster/master/acme_tiny.py > acme_tiny.py

        chown letsencrypt:www-data acme_tiny.py

   if [ ! -f sync.sh ]; then
        #make some challenge folder
        echo "#!/bin/bash" > sync.sh
        echo "" >> sync.sh
        echo "#rsync -rtpqu keys www2:" >> sync.sh
        echo "#rsync -rtpqu challenges www2:" >> sync.sh
        chmod 700 sync.sh
   fi

   if [ ! -f domains.txt ]; then
        touch domains.txt
        chmod 600 domains.txt
   fi

   if [ ! -f run.sh ]; then
        cat > run.sh << EOF
#!/bin/bash
set -e 
domains=`cat domains.txt`
for domain in $domains
do
    echo "\${domain}"
done
./sync.sh
EOF
   fi

   chmod 700 run.sh
   chown letsencrypt:www-data run.sh
}

generateKeys(){
   cd /home/letsencrypt
   mkdir -p keys
   mkdir -p csr
   mkdir -p certs
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
   chmod 600 /home/letsencrypt/keys/*
   chmod -R o-xrw /home/letsencrypt/
}

setupApache(){

 if ! grep -q "well-known/acme-challenge" /etc/apache2/sites-enabled/000-default.conf; then
 
  cat > /tmp/000-default.conf << EOF
Alias /.well-known/acme-challenge/ /home/letsencrypt/challenges/
<Directory /home/letsencrypt/challenges>
   AllowOverride None
   Require all granted
   Satisfy Any
</Directory>
EOF
   cat /etc/apache2/sites-enabled/000-default.conf >> /tmp/000-default.conf
   cp /tmp/000-default.conf /etc/apache2/sites-enabled/000-default.conf 
  fi

  /etc/init.d/apache2 restart        
}

addUser;
fetchFiles;
generateKeys;
setupApache;
