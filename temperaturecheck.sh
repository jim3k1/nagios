#!/bin/bash
# very naive way to check the temperature of a CPU using lm-sensors
# to be used with nagios for monitoring
# Developed on Ubuntu 14.04 with sensors version 3.3.4 with libsensors version 3.3.4
# smcgrat@tchpc.tcd.ie, July 2016

################
# nagios setup #
################

source /etc/os-release
UTILS=/usr/local/nagios/libexec/utils.sh

if [ "$VERSION_ID" = "16.04" ]; then
    UTILS=/usr/lib/nagios/plugins/utils.sh
fi

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

function debug { # function to enable debug
    if [ "$debugon" == "yes" ]; then
        $@
    fi
}

#############
# Variables #
#############

debugon=no
me=$(basename "$0")
hardware_identifier=$(/usr/bin/sensors | head -1)

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

# different hardware types give different outputs to /usr/bin/sensors
# need a way to figure out which we are working with here
# intel seems a uniform output, AMD can have 2 possible examples on tested equipment.

if [ "$hardware_identifier" == "acpitz-virtual-0" ]; then
    processor=INTEL
elif [ "$hardware_identifier" == "coretemp-isa-0000" ]; then
    processor=INTEL
elif [ "$hardware_identifier" == "i5k_amb-isa-0000" ]; then
    processor=INTEL
elif [ "$hardware_identifier" == "fam15h_power-pci-00c4" ]; then
    processor=AMD
elif [ "$hardware_identifier" == "k10temp-pci-00c3" ]; then
    processor=AMD
elif [ "$hardware_identifier" == "k10temp-pci-00d3" ]; then
    processor=AMD
elif [ "$hardware_identifier" == "w83793-i2c-1-2f" ]; then
    processor=AMD
elif [ "$hardware_identifier" == "i5k_amb-isa-0000" ]; then
    processor=AMD
elif [ "$hardware_identifier" == "w83627dhg-isa-0290" ]; then
    processor=AMD
else
    echo "Error: cannot determine hardware sensor and what to search the /usr/bin/sensors output for to find the temperature"
    exit $STATE_UNKNOWN
fi

############################
# Detect Core temperatures #
############################

declare -a temperatures

if [ "$processor" == "INTEL" ]; then
    temperatures=($(/usr/bin/sensors | grep 'Core' | awk '{print $3}' | sed -n 's/+/&\n/;s/.*\n//p' | sed 's/\..*//'))
elif [ "$processor" == "AMD" ]; then
    temperatures=($(/usr/bin/sensors | grep 'temp1' | awk '{print $2}' | sed -n 's/+/&\n/;s/.*\n//p' | sed 's/\..*//'))
fi

if [ -z "$temperatures" ]; then
    echo "Error: temperature readings are null"
    exit $STATE_UNKNOWN
fi

highest=${temperatures[0]}

if [ ${#temperatures[@]} -gt 1 ]; then
    for tp in "${temperatures[@]}"; do
        if [ $((tp)) -gt $((highest)) ]; then
            highest=$tp
        fi
    done
fi

# sensors temperature outputs are different across the differing hardware types too
# assumes sensors command outputs 'Core' (INTEL) or 'temp1' (AMD)
# takes the 3rd charset of it for INTEL and 2nd charset for AMD and mangles through sed
# to turn it into a whole number instead of something like +38.0°C
# by removing the first char which is a + on systems I've tested, then
# removing any chars ater a '.'

#############################################################
# Check temperatures against thresholds and act accordingly #
#############################################################

if [ $((highest)) -gt $((crittemp)) ]; then
    critical $highest
elif [ $((highest)) -gt $((warningtemp)) ]; then
    warn $highest
fi

echo "OK - Temperatures: $highest"
exit $STATE_OK
