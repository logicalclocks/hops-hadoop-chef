#!/bin/bash

rm -f Berksfile.lock

set -eo pipefail 

skip_converge=0


regex="test_src/services_spec.rb.(.+)"
boxes="test_src/box_(.+)"


for box in `ls test_src/box_* | grep -v *[#~]`
do
   cp .kitchen.yml.old .kitchen.yml
    if [[ $box =~ $boxes ]] ; then
       b="${BASH_REMATCH[1]}"
       echo "Testing box: ${b}"
       perl -pi -e "s/XXXX/${b}/" .kitchen.yml
       echo "test_src/box_${b}"
       v=$(head -1 test_src/box_${b} |  perl -pe 'chomp')
       # escape the url
       echo $v

       v=$(echo $v | sed 's/\./\\\./g')
       v=$(echo $v | sed 's/\_/\\\_/g')
       v=$(echo $v | sed 's/\:/\\\:/g')
       v=$(echo $v | sed 's/\//\\\//g')
       perl -pi -e "s/YYYY/${v}/" .kitchen.yml
       echo "replaced text..."
    fi

 if [ $# -gt 0 ] ; then
     if [ $1 == "-help" ] ; then
	 echo "usage: $0 [nodestroy [verify]]"
	 exit 0
     elif [ $1 != "nodestroy" ] ; then
	 kitchen destroy
     else 
	 if [ $2 == "verify" ] ; then 
             skip_converge=1
	 fi
     fi
 else 
     kitchen destroy
 fi


    if [ $skip_converge -eq 0 ] ; then
	for f in `ls test_src/services_spec.rb.* | grep -v *[#~]`
	do
           last_char="${f: -1}"
	    if [[ $f =~ $regex && "$last_char" != "~" && "$last_char" != "#" ]] ; then
		name="${BASH_REMATCH[1]}"
		echo "Converging default-${name}"
		kitchen converge default-${name}
	    fi
	done
    fi

    rm -f test/integration/default/serverspec/localhost/services_spec.rb

    for f in `ls test_src/services_spec.rb.* | grep -v *[#~]`
    do
        last_char="${f: -1}"
	if [[ $f =~ $regex  && "$last_char" != "~" && "$last_char" != "#" ]] ; then
            name="${BASH_REMATCH[1]}"
            cp -f test_src/services_spec.rb.${name} test/integration/default/serverspec/localhost/services_spec.rb
            echo "Verifying ${name}"
            kitchen verify default-${name}
	fi
    done

    rm test/integration/default/serverspec/localhost/services_spec.rb
    kitchen destroy

done

cp .kitchen.yml.old .kitchen.yml
echo "Success"
exit 0
