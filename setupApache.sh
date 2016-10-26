#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p /home/webapps/apache

openssl version > /tmp/openssl.version
 
cp /etc/apache2/mods-enabled/ssl.conf /tmp/ssl.conf
#sed --in-place='.bak' -r 's/^[\t ]+SSLCipherSuite.*$/\tSSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS"/m' ssl.conf
sed --in-place='.bak' -r 's/^[\t ]+SSLCipherSuite.*$/\tSSLCipherSuite "HIGH:!aNULL:!MD5:!3DES:!CAMELLIA"/m' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLHonorCipherOrder .*$/     SSLHonorCipherOrder on/g' /tmp/ssl.conf
#sed --in-place='.bak' -r 's/^[\t #]+SSLProtocol .*$/     SSLProtocol all -SSLv3 -SSLv2/g' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLProtocol .*$/     SSLProtocol TLSv1.2/g' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLStrictSNIVHostCheck .*$/     SSLStrictSNIVHostCheck On/g' /tmp/ssl.conf

if ! grep -qE "1\.0\.[01]" /tmp/openssl.version; then

  # **REQUIRES** Apache 2.4.8+ AND OpenSSL 1.0.2+ - 
  # Override the default prime256v1 (NIST P-256) and use secp384r1 (NIST P-384)
  cat /tmp/ssl.conf |grep -v "</IfModule>" > /tmp/ssl.conf2
  cat /tmp/ssl.conf2 |grep -v "SSLOpenSSLConfCmd" > /tmp/ssl.conf3
  echo "SSLOpenSSLConfCmd Curves secp384r1" >> /tmp/ssl.conf3
  echo "</IfModule>" >> /tmp/ssl.conf3
  cp /tmp/ssl.conf3 /tmp/ssl.conf
fi  

rm /etc/apache2/mods-enabled/ssl.conf
cp /tmp/ssl.conf /etc/apache2/mods-available/ssl.conf
ln -s /etc/apache2/mods-available/ssl.conf /etc/apache2/mods-enabled/

if [ ! -f /home/webapps/apache/000-default.conf ]; then
  cp /etc/apache2/sites-enabled/000-default.conf /home/webapps/apache/
  rm /etc/apache2/sites-enabled/000-default.conf
  
  ln -s /home/webapps/apache/000-default.conf /etc/apache2/sites-enabled/000-default.conf
fi

if ! grep -q "Header .* Strict-Transport-Security" /etc/apache2/sites-enabled/000-default.conf; then
    echo "@TODO sudo vi /etc/apache2/sites-enabled/000-default.conf"
    echo ""
    echo "Header always set Strict-Transport-Security \"max-age=31536000\""
    echo ""
fi 

#if [ ! -f /home/webapps/apache/httpd-jk.conf ]; then
#  cp /etc/libapache2-mod-jk/httpd-jk.conf /home/webapps/apache/
#  rm /etc/libapache2-mod-jk/httpd-jk.conf
#  ln -s /home/webapps/apache/httpd-jk.conf /etc/libapache2-mod-jk/
#fi

sudo rm /etc/apache2/mods-enabled/jk.conf
sudo cp apache2/mods-enabled/jk.conf /etc/apache2/mods-enabled/jk.conf

if [ ! -f /home/webapps/apache/workers.properties ]; then
  cp /etc/libapache2-mod-jk/workers.properties /home/webapps/apache/
  rm /etc/libapache2-mod-jk/workers.properties
  ln -s /home/webapps/apache/workers.properties /etc/libapache2-mod-jk/
fi
chgrp -R www-data /home/webapps/apache
chmod -R go-wrx /home/webapps/apache
a2enmod headers
a2enmod ssl
/etc/init.d/apache2 restart
