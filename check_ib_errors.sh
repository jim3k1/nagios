#!/bin/bash
# Sean McGrath, May 2016
# Ensure that ibdiagnet contains certain strings that say there are no errors in the fabric
# and count the apparent errors in a verbose ibdiagnet and error if there are more than
# an arbitary number that will need some tweaking in future probably

################
# nagios setup #
################

UTILS=/usr/lib64/nagios/plugins/utils.sh

# load states and strings
if [ -x "${UTILS}" ]; then
        . "${UTILS}"
else   
        echo "ERROR: Cannot find ${UTILS}"
        exit 3
fi

if [ ! -e /etc/nrpe.d/generate_ibdiagnet_report.sh ]; then
	echo "ERROR: cannot find script to generate errors to be red"
	exit 3
fi

#############################################################################
# debug flag check, -d flag with this script provides a more verbose output #
#############################################################################

if [ "$1" == "-d" ]; then # check for debug flag
	debugon="yes"
else
	debugon=no
fi

#########################
# variables & functions #
#########################

report=/tmp/ibdiagnet
errors=0
problems=''
verbosereport=/tmp/ibdiagnet-v-r
timestamp=$(date '+%Y%m%d-%H.%M.%S')
statuserrorcount=0
statuserrorcountmax=200
	# this limit is arbritary, testing this the first time got 66 errors, so doubled it for now
	# for the situation that this is designed to alert for, I expect the total error count to be very high
	# errors seem to increment in 6 btw, so 66 = 11 errors?

function debug { # function to enable debug 
	if [ "$debugon" == "yes" ]; then
		#echo "debug on"
		$@
	fi
}

function ibcheck {
	local pattern="$@"
	local check=$(grep -i "$pattern" $report)
	if [ -n "$check" ]; then # var is not null, ergo that error condition should not exist in the ibdiagnet report
		debug echo "OK: $i"
	else
		debug echo "PROBLEM: $i"
		let errors=errors+1
		problems="$problems String - "$i", is NOT PRESENT in ibdiagnet output, "
	fi
}

function logerrors {
	cp $report $report.$timestamp
	cp $verbosereport $verbosereport.$timestamp
	debug echo "$timestamp: copied ibdiagnet outputs to /tmp"
}

#######################################################################
# Check ibdiagnet contains certain strings that suggest things are OK #
#######################################################################

# to test alerting use the following loop to create a loop that contains a false positive
#for i in "No bad Guids were found" "No bad Links (with logical state = INIT) were found" "False Positive Test"; do

for i in "No bad Guids were found" "No bad Links (with logical state = INIT) were found"; do
	ibcheck "$i"
done

debug echo "Error Count so far: $errors"

if [ "$errors" -ne "0" ]; then
	echo "WARNING: IB issue(s) - $problems. Run /usr/bin/ibdiagnet for details"
	logerrors
	exit $STATE_WARNING
fi

################################################
# now count some errors in a verbose ibdiagnet #
################################################

statuserrors=( $(grep '...status' $verbosereport | sed -n 's/status = /&\n/;s/.*\n//p' | awk '{print $1}') )

for i in "${statuserrors[@]}"; do
        statuserrorcount=$((statuserrorcount+$i))
done

if [ "$statuserrorcount" -gt "$statuserrorcountmax" ]; then
	echo "WARNING: IB Status Errors maximum, ($statuserrorcountmax), exceeded. $statuserrorcount errors detected. Run /usr/bin/ibdiagnet -v -r for details"
	logerrors
	exit $STATE_WARNING
else
	debug echo "IB Status Errors count $statuserrorcount less than threshold: $statuserrorcountmax"
fi

# otherwise print a nice re-assuring message and exit normally
echo "OK"
exit 0
