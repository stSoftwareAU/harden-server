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
        echo "#rsync -rtpqu certs www2:" >> sync.sh
        echo "#rsync -rtpqu challenges www2:" >> sync.sh
        echo "#rsync -rtpqu csr www2:" >> sync.sh
        echo "#rsync -rtpqu keys www2:" >> sync.sh
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
acme_tiny (){

    rm -f /tmp/acme.crt
    set +e
    python acme_tiny.py --account-key keys/account.key --csr \$CSR --acme-dir challenges > /tmp/acme.crt

    set -e
    if [ -s /tmp/acme.crt ]; then
       mv /tmp/acme.crt \$CRT
    else
       echo "could not create cert for \${domain}"
    fi
}

cd
domains=`cat domains.txt`
rm -f challenges/*

for domain in \$domains
do
    CSR=csr/\${domain}.csr
    if [ ! -f \$CSR ]; then
       echo "create a certificate signing request (CSR) for: \${domain}"
       openssl req -new -sha256 -key keys/domain.key -subj "/CN=\${domain}" > \$CSR

    fi

    CRT=certs/\${domain}.crt
    if [ ! -f \$CRT ]; then
       echo "create cert for: \${domain}"
       acme_tiny
    else
        if test `find "\$CRT" -mtime 30`
        then
            echo "renew cert for: \${domain}"
            acme_tiny
        fi
    fi
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
   sed 's/JkMount \/\* \(.*\)/&\n\    JkUnMount \/.well-known\/acme-challenge\/\* \1/' /tmp/000-default.conf >/tmp/000-default.conf2
   cp /tmp/000-default.conf2 /etc/apache2/sites-enabled/000-default.conf 
  fi

  /etc/init.d/apache2 restart        
}

setupCron(){
        
        rm -f /tmp/crontab.txt
        
        tmpfile=$(mktemp /tmp/letsencrypt_cron.XXXXXX)
        
        cat >$tmpfile << EOF
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/home/letsencrypt/run.sh" /tmp/crontab.txt; then
     echo "0 2 * * 7 sleep \\\${RANDOM:0:2}m ; /home/letsencrypt/run.sh > /home/letsencrypt/run.log" >> /tmp/crontab.txt
     crontab < /tmp/crontab.txt
fi
EOF
        chmod 777 $tmpfile
        
        sudo -u letsencrypt $tmpfile
        rm $tmpfile
        
        rm -f /tmp/crontab.txt
        tmpfile=$(mktemp /tmp/apache_cron.XXXXXX)
        
        cat >$tmpfile << EOF2
#!/bin/bash
set +e        
crontab -l > /tmp/crontab.txt
set -e
if ! grep -q "/etc/init.d/apache2" /tmp/crontab.txt; then
     echo "0 5 * * 7 /etc/init.d/apache2 reload >/dev/null" >> /tmp/crontab.txt
     crontab < /tmp/crontab.txt
fi
EOF2
   chmod 777 $tmpfile
        
   $tmpfile    
   rm $tmpfile
   rm -f /tmp/crontab.txt
}
addUser;
fetchFiles;
generateKeys;
setupApache;
setupCron;
