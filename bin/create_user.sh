#!/bin/bash
set -e

addGroup( ) {
  ret=false
  sudo getent group $1 >/dev/null 2>&1 && ret=true

  if ! $ret; then
    sudo groupadd $1
  fi
}

user=$1
group=$2
email=$3

if [[ $user = *[!\ ]* ]]; then
	ret=false
	sudo getent passwd $user >/dev/null 2>&1 && ret=true

	if $ret; then
		echo "User '$user' exists"
	else
        extG="";
        if [[ $group = *[!\ ]* ]]; then
            addGroup '$group';
            extG="--groups '$group'"
        fi

        extPW=''
        if [[ $email = *[!\ ]* ]]; then 
           pass=`openssl rand -base64 12`
           extPW="--password '$pass'"
        fi

        cmd="sudo useradd $extPW $extG --create-home -s /bin/bash $user"
#        echo "$cmd"
        $cmd

        if [[ $pass = *[!\ ]* ]]; then
           
            host=`uname -n`
            tmpfile=$(mktemp /tmp/email.XXXXXX)
            echo "User:     $user" >  $tmpfile
            echo "Password: $pass" >> $tmpfile

            mail -s "connection details for $host" -r support@stsoftware.com.au $email < $tmpfile

            rm $tmpfile
        fi
    fi
fi

# vim: set ts=4 sw=4 sts=4 et:
