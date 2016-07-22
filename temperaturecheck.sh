#!/bin/bash
# very naive way to check the temperature of a CPU using lm-sensors
# to be used with nagios for monitoring
# Developed on Ubuntu 14.04 with sensors version 3.3.4 with libsensors version 3.3.4
# smcgrat@tchpc.tcd.ie, July 2016

################
# nagios setup #
################

UTILS=/usr/local/nagios/libexec/utils.sh

# load states and strings
if [ -x "${UTILS}" ]; then
        . "${UTILS}"
else   
        echo "ERROR: Cannot find ${UTILS}"
        exit $STATE_UNKNOWN
fi

#############
# Functions #
#############

function warn {
	local temperature=$1
	echo "WARNING - temperature: $temperature is greater than threshold $warningtemp"
	exit $STATE_WARNING
}

function critical {
        local temperature=$1
        echo "CRITICAL - temperature: $temperature is greater than threshold $crittemp"
	exit $STATE_CRITICAL
}

function usage {
	echo "$me - nagios monitoring of temperature using lm-utils"
	echo "$me -w warning temperature -c critical temperature [both flags are mandatory]"
	exit $STATE_UNKNOWN
}

#############
# Variables #
#############

me=$(basename "$0")

while getopts “c:w:h:” OPTION
do
	 case $OPTION in
		 c)
			 crittemp=$OPTARG
			 ;;
		 w)
			 warningtemp=$OPTARG
			 ;;
		 h)
			 usage
			 ;;
		 ?)
			 usage
			 ;;
	 esac
done

#################
# Sanity checks #
#################

if [ ! -e /usr/bin/sensors ]; then
	echo "lm-sensors does not appear to be installed"
	exit 3
fi

if [ -z "$warningtemp" ]; then
	usage
fi

if [ -z "$crittemp" ]; then
	usage
fi

if (( "$warningtemp" >= "$crittemp" )); then
       echo "The warning temperature threshold: $warningtemp is greater than or equal to the critical temperature: $crittemp threshold. That makes no sense"
       exit $STATE_UNKNOWN
fi

############################
# Detect Core temperatures #
############################

temperatures=($(/usr/bin/sensors | grep 'Core' | awk '{print $3}' | sed -n 's/+/&\n/;s/.*\n//p' | sed 's/\..*//'))
# assumes sensors command outputs 'Core'
# takes the 3rd charset of it and mangles it through sed 
# to turn it into a whole number instead of something like +38.0°C
# by removing the first char which is a + on systems I've tested, then
# removing any chars ater a '.'

for coretemp in "${temperatures[@]}"; do
	if [ $((coretemp)) -gt $((crittemp)) ]; then
		critical $coretemp
	elif [ $((coretemp)) -gt $((warningtemp)) ]; then
		warn $coretemp
	fi
done

echo "OK - Temperatures: ${temperatures[@]}"
exit $STATE_OK
