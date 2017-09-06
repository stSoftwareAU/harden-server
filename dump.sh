#!/bin/bash
set -e

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>log.out 2>&1

confFile=$1
toInclude=()
toExclude=()
tmpConfFile=$(mktemp /tmp/s3-conf-script.XXXXXX)
s3=false
emailHost=""
emailMagic=""
emailTo=""

errors=()
logs=()

if [ ! -z "$confFile" ]; then
    json=`cat $confFile`
    tmp=$( jq -r '.' <<< "${json}")
    echo $tmp > $tmpConfFile
    email=$( jq -r '.email' <<< "${json}") 

#    echo "${email}"| jq "." 
#    is3PutScript=`jq -r ".s3PutScript" $confFile`
#    s3Bucket=`jq -r ".s3Bucket" $confFile`
    toInclude=(`jq -r ".include[]?" $confFile`)
    toExclude=(`jq -r ".exclude[]?" $confFile`)

    s3=$( jq -r '.s3' <<< "${json}" )
    if [[ "${s3}" == null ]]; then
        s3=false
    fi

    emailHost=$( jq -r '.host' <<< "${email}") 
    emailMagic=$( jq -r '.magic' <<< "${email}") 
    emailTo=$( jq -r '.to' <<< "${email}") 
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

    echo "--> UPLOADING TO BUCKET..."

    S3TOOLS="./s3-tools"
    S3PutScript="${S3TOOLS}/putS3.sh"

    echo $'\n'"--> GET S3-TOOLS"
    if [ ! -d "${S3TOOLS}" ]; then
        git clone git@github.com:stSoftwareAU/s3-tools.git
    else
        cd "${S3TOOLS}"
        git fetch origin
        git reset --hard origin/master
        cd 
    fi

    if [ ! -f "${S3PutScript}" ]; then
        echo "FILE ${S3PutScript}  DOES NOT EXIST"
        exit 1
    fi

    if [ ! -z ${S3PutScript} ]; then
        thisList=("$@")
        for d in ${thisList[@]}
        do
            echo $'\n'"--> UPLOADING FILE:${DAILY}/$d.gz TO AWS BUCKET."
            eval "${S3PutScript} -f ${DAILY}/$d.gz --conf=${tmpConfFile}"
        done
    else
        echo "PUT SCRIPT:${S3PutScript} IS NOT DEFINED."
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
    if [ "${s3}" != false ]; then
        saveToBucket "${toInclude[@]}"
    fi
else
    dumpDbs "${LIST[@]}"
    if [ "${s3}" != false ] ; then
        saveToBucket "${LIST[@]}"
    fi
fi

end_date=$(date +%Y%m%d-%T)
echo $end_date "END pg_dump database(s) !"

cp -a $DAILY/* $MONTHLY



if [[ "${emailHost}" != null ]];then
    echo "EMAIL HOST: ${emailHost}"

    subject="Testing POST"
    body="<h3>Logs</h3>"
    #ebody=$(echo "$body" | sed 's/ /%20/g;s/</%3c/g;s/>/%3d/g');
    ebody=$(echo "$body" | sed 's/</\&lt;/g;s/>/\&gt;/g');


    echo "body: ${ebody}"
    emailSent=$(curl -i -X POST -F "subject=${subject}" -F "body=${ebody}" -F "_magic=${emailMagic}" -F "to=${emailTo}" "${emailHost}/ReST/v1/email")
    #echo "${emailSent}"

else
    echo "EMAIL HOST IS NOT DEFINED."
fi



rm -rf "${tmpConfFile}"

