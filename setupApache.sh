cp /etc/apache2/mods-enabled/ssl.conf /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t ]+SSLCipherSuite.*$/\tSSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS"/m' ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLHonorCipherOrder .*$/     SSLHonorCipherOrder on/g' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLProtocol .*$/     SSLProtocol all -SSLv3 -SSLv2/g' /tmp/ssl.conf
sed --in-place='.bak' -r 's/^[\t #]+SSLStrictSNIVHostCheck .*$/     SSLStrictSNIVHostCheck On/g' /tmp/ssl.conf

rm /etc/apache2/mods-enabled/ssl.conf
cp /tmp/ssl.conf /etc/apache2/mods-enabled/ssl.conf
