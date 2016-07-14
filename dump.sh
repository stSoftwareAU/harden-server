#!/bin/bash
cd
DAILY=dumps/`date +%a`
mkdir -p $DAILY
MONTHLY=/home/postgres/backups/`date +%b`
mkdir -p $MONTHLY
LIST=$(psql -tqc 'SELECT datname FROM pg_database where datistemplate = false;')
start_date=$(date +%Y%m%d-%T)
echo $start_date "START pg_dump database(s) !" 
for d in $LIST
do
  temp_date_s=$(date +%Y%m%d-%T)
  echo $temp_date_s + "Database: " $d 
  pg_dump $d |gzip -c > $DAILY/$d.gz
done
end_date=$(date +%Y%m%d-%T)
echo $end_date "END pg_dump database(s) !"
cp -a $DAILY/* $MONTHLY
