#! /bin/bash
cd "$(dirname "$0")"


#kill `ps -ef |grep nigel |grep "tail " |grep "/home/www"| cut -c 9-15`

#LOG="logs/access/`date +%Y/%b/access_%d.log`"
LOG="/var/log/apache2/access.log"

STATUS="(200|201|204|206|207|301|304|302|401) [0-9\-]+"
USERS="[a-z_0-9]+@(astonacquisitions|st|aspc_office|dns|smegateway|access_air|moelis|toastees|115solutions|dns|tutor|networxs|littleboommusic|myym|morningstar)"
IGNORE_USERS="([0-9]|\.)+ - $USERS \[[0-9/a-z: \+]+\] \\\"(GET|POST|HEAD) ([,|a-z0-9/\*\+\.\?=@~&_:\(\)\+\\\"]|-|\[|\]|%[0-9a-f]+)+ HTTP/1\.[0-1]\\\" $STATUS "

IGNORE_REF=" $STATUS \\\".*(CMS_MODE=).*\\\""
IGNORE_SITES=" $STATUS \\\".*\\\" .* (www\.|)(ajb|astonacquisitions|toasteeswetsuits|access-air|smegateway|shawreynolds|aspc.jobtrack|sydneyshardrockstory|buxtonmarine|smeg.jobtrack|dns.stsoftware|srbg.com.au|ASPCONVERTERS.COM|lcjru.jobtrack|toastees.stsoftware|moelis.jobtrack|dns.jobtrack|hsp.stsoftware.com.au|www.stsoftware.com.au)"

IGNORE_RESOURCES="([0-9]|\.)+ - [0-9a-z@]+ \[[0-9/a-z: \+]+\] \\\"(GET|POST|HEAD) (/soap/action/commander|/javadocs|/ical|/ReST/json/globals|/ReST/json/DBNotification).* HTTP/1\.[0-1]\\\" $STATUS "
IGNORE_PROPFIND=" \\\"PROPFIND .* 404 "
IGNORE_BOTS="([0-9]|\.)+ - [0-9a-z@]+ \[[0-9/a-z: \+]+\] \\\"(GET|HEAD) .* HTTP/1\.[0-1]\\\" $STATUS \\\".*\\\" \\\".*(UptimeRobot|OpenLinkProfiler|crawler\.php|20100101 Firefox/6\.0\.2|webwombat| Vagabondo|Facebot/| 360Spider| Yahoo! Slurp| Exabot| DotBot| AhrefsBot|bingbot|Googlebot|YandexBot|Baiduspider| AhrefsBot| MJ12bot|msnbot/| Mail\.RU_Bot|Wotbox/|Twitterbot/|panscient.com| SeznamBot|msnbot-media/|nagios-plugins|aiHitBot|pandora.nla.gov.au|BLEXBot|WBSearchBot).*\\\""
IGNORE_IPS="(58\.108\.224\.217|60\.241\.239\.222|58\.106\.70\.111|203\.206\.176\.223|175\.39\.10\.218) - [0-9a-z@]+ \[[0-9/a-z: \+]+\] \\\"GET .* HTTP/1\.[0-1]\\\" $STATUS \\\".*\\\" \\\".*\\\""

#tail --lines=1000  /home/edge/$LOG /home/agile/www1$LOG /home/agile/www2$LOG|grep "188.173.177.134"
#tail --lines=10000  /home/edge/$LOG /home/agile/www1$LOG /home/agile/www2$LOG| egrep -iv "$IGNORE_BOTS"|grep "robot" |more
#tail --lines=10000 -f /home/edge/$LOG /home/agile/www1$LOG /home/agile/www2$LOG|grep -i "blog" | egrep -i "Googlebot"|  awk -F\" -f /home/nigel/bin/scan.awk

#tail --lines=10000 -f /home/edge/$LOG /home/agile/www1$LOG /home/agile/www2$LOG|awk -F\" -f /home/nigel/bin/scan.awk
#tail --lines=10000 -f /home/edge/$LOG | grep " .php"|  awk -F\" -f /home/nigel/bin/scan.awk
#tail --lines=10000 -f /home/edge/$LOG /home/agile/www1$LOG /home/agile/www2$LOG|grep "benloane.stsoftware.com.a"|grep -iv linux

tail --lines=10000 -f $LOG |egrep -iv "$IGNORE_USERS"|egrep -iv "$IGNORE_IPS"|egrep -iv "$IGNORE_REF" |egrep -iv "$IGNORE_SITES"|egrep -iv "$IGNORE_RESOURCES"| egrep -iv "$IGNORE_BOTS"|egrep -iv "$IGNORE_PROPFIND"|  awk -F\" -f scan.awk

