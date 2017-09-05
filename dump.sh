#!/bin/bash

set -e

confFile=$1
toInclude=()
toExclude=()
s3Bucket=false
s3PutScript=""

restUrl=""
errors=()

if [ ! -z "$1" ]; then
    s3PutScript=`jq -r ".s3PutScript" $confFile`
    s3Bucket=`jq -r ".s3Bucket" $confFile`
    toInclude=(`jq -r ".include[]?" $confFile`)
    toExclude=(`jq -r ".exclude[]?" $confFile`)

    if [[ "$s3Bucket" == null ]] || [ -z "${s3Bucket}" ]; then
        #echo "s3Bucket is: $s3Bucket"
        s3Bucket=false
    fi
    if [[ "$s3PutScript" == null ]]; then
        #echo "s3PutScript is: $s3PutScript"
        s3PutScript=""
    fi
    echo "Bucket it = ${s3Bucket}"

    restUrl=`jq -r ".email.restUrl" $confFile`
    echo "EMAIL URL: ${restUrl}"
fi


cd
DAILY=dumps/`date +%a`
mkdir -p $DAILY
MONTHLY=dumps/`date +%b`
mkdir -p $MONTHLY

LIST=$(psql -h localhost -U postgres -tqc 'SELECT datname FROM pg_database where datistemplate = false;')

start_date=$(date +%Y%m%d-%T)
echo $start_date "START pg_dump database(s) !" 

# exclude from LIST if defined in .json config
for del in ${toExclude[@]}
do
    echo "EXCLUDING: ${del}"
    LIST=("${LIST[@]/$del}")
done

function dumpDbs() {
    thisList=("$@")
    for d in ${thisList[@]}
    do
        temp_date_s=$(date +%Y%m%d-%T)
        size=$(psql -h localhost -U postgres -tqc "SELECT pg_size_pretty(pg_database_size('$d'));")
        echo "$temp_date_s Database: $d size: ${size//[[:space:]]}"
        pg_dump -h localhost -U postgres $d |gzip -c > $DAILY/$d.gz
    done
}

function saveToBucket() {

    if [ ! -z ${s3PutScript} ]; then
        thisList=("$@")
        for d in ${thisList[@]}
        do
            echo $'\n'"--> UPLOADING FILE:${DAILY}/$d.gz TO AWS BUCKET."
            eval "${s3PutScript} ${DAILY}/$d.gz"
        done
    else
        echo "S3PUT SCRIPT IS NOT DEFINED."
        exit 1
    fi
}

if [ ! -z "${toInclude}" ]; then

    # exclude non existing databases from toInclude()
    for d in ${toInclude[@]}
    do    
        dbExists=$(psql -h localhost -U postgres -tqc "SELECT datname FROM pg_catalog.pg_database WHERE lower(datname) = lower('${d}');")
        if [ -z "${dbExists}" ]; then
            echo "DB -> $d DOES NOT EXISTS." 
            toInclude=("${toInclude[@]/$d}")
        fi  
    done

    dumpDbs "${toInclude[@]}"
    if [ "${s3Bucket}" = true ]; then
        saveToBucket "${toInclude[@]}"
    fi
else
    dumpDbs "${LIST[@]}"
    if [ "${s3Bucket}" = true ] ; then
        saveToBucket "${LIST[@]}"
    fi
fi

end_date=$(date +%Y%m%d-%T)
echo $end_date "END pg_dump database(s) !"

cp -a $DAILY/* $MONTHLY



subject="Testing POST"
body="<h3>Logs</>"

echo $'\n'"REST: ${restUrl}"
emailSent=$(curl -i -X POST -d "subject=${subject}?body=${body}" "${restUrl}")
echo "${emailSent}"









