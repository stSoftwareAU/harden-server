cp /etc/apache2/mods-enabled/ssl.conf /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t ]+SSLCipherSuite.*$/\tSSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS"/m' ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLHonorCipherOrder .*$/     SSLHonorCipherOrder on/g' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLProtocol .*$/     SSLProtocol all -SSLv3 -SSLv2/g' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLStrictSNIVHostCheck .*$/     SSLStrictSNIVHostCheck On/g' /tmp/ssl.conf

rm /etc/apache2/mods-enabled/ssl.conf
cp /tmp/ssl.conf /etc/apache2/mods-enabled/ssl.conf
mkdir -p /home/webapps/apache

if [ ! -f /home/webapps/apache/000-default.conf ]; then
  cp /etc/apache2/sites-enabled/000-default.conf /home/webapps/apache/
  rm /etc/apache2/sites-enabled/000-default.conf
  
  ln -s /home/webapps/apache/000-default.conf /etc/apache2/sites-enabled/000-default.conf
fi

if [ ! -f /home/webapps/apache/httpd-jk.conf ]; then
  cp /etc/libapache2-mod-jk/httpd-jk.conf /home/webapps/apache/
  rm /etc/libapache2-mod-jk/httpd-jk.conf
  ln -s /home/webapps/apache/httpd-jk.conf /etc/libapache2-mod-jk/
fi

if [ ! -f /home/webapps/apache/workers.properties ]; then
  cp /etc/libapache2-mod-jk/workers.properties /home/webapps/apache/
  rm /etc/libapache2-mod-jk/workers.properties
  ln -s /home/webapps/apache/workers.properties /etc/libapache2-mod-jk/
fi
chown -R webapps /home/webapps/apache
chmod -R go-wrx /home/webapps/apache
