#!/bin/bash
# Sean McGrath, May 2016

# generate ibdiagnet report for error checking
# intention is a seperate nagios check will query the report
# this file should be called by cron

timestampe=$(date '+%y-%m-%d_%H.%M.%S')
tempshort=/tmp/ibdiagnet_$date
short=/tmp/ibdiagnet
tempverbose=/tmp/ibdiagnet-v-r_$date
verbose=/tmp/ibdiagnet-v-r

ibdiagnet > $tempshort

ibdiagnet -v -r > $tempverbose

mv $tempshort $short
mv $tempverbose $verbose
# renaming the files because it can take 30+ seconds to generate it

exit 0
