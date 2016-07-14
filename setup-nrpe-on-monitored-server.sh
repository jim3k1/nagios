#!/bin/bash
#--------------------------------------------------------------------------------------------------
# setup Nagios Remote Plugin Executor (NRPE) on a new server
# so that the server can be monitored

# dependencies
# - yum must be able to connect to external repositories on the server to be monitored
# - pwgen must be installed on the server to be monitored
# - for check_ntp_time to work ntp mut be configured on the server to be monitored

#--------------------------------------------------------------------------------------------------
# functions
#--------------------------------------------------------------------------------------------------

function create_account {
# Create nagios user account and set it's password
	echo "Creating Nagios account"
	useradd nagios	
	echo "done"; echo ""
}

function install_software {
# Install the necessary software
	echo "Installing Nagios components"
	yum install -y nagios-plugins-all
	yum install -y nrpe
	yum install -y nagios-plugins-nrpe
	echo "done"; echo ""
}

function setup_nrpe_service {
# ensure that nrpe runs as a service on reboot, etc
	echo "Setting up NRPE as a service"
	chkconfig nrpe on
	service nrpe start
	echo "done"; echo ""
}

function configure_firewall {
# setup iptables, assuming iptables is the firewall being used
	echo "Configuring iptables to allow communication with service01.tchpc.tcd.ie over TCP and UDP on port 5666"
	iptables -I INPUT -s 134.226.112.44 -p tcp --dport 5666 -j ACCEPT -m comment --comment "Nagios NPRE access from service01.tchpc.tcd.ie"
	iptables -I INPUT -s 134.226.112.44 -p udp --dport 5666 -j ACCEPT -m comment --comment "Nagios NPRE access from service01.tchpc.tcd.ie"
	service iptables save
	echo "done"; echo ""
}

function find_config {
# Figure out which nrpe.cfg we have
# the nrpe.cfg file will be either: /usr/local/nagios/etc/nrpe.cfg (Older setup) - OR - /etc/nagios/nrpe.cfg (newer)
	echo "Determine which is the NRPE Configuration file, (nrpe.cfg), now"; echo ""
	if [ -e /etc/nagios/nrpe.cfg ]; then
		conf="/etc/nagios/nrpe.cfg"
		echo "Using configuration file: $conf"
	elif [ -e /usr/local/nagios/etc/nrpe.cfg ]; then
		conf="/usr/local/nagios/etc/nrpe.cfg"
		echo "Using configuration file: $conf"
	else
		echo "Neither of the Possible Nagios Configuration files exist"
		echo "/usr/local/nagios/etc/nrpe.cfg (Older setup) - OR - /etc/nagios/nrpe.cfg"
		echo "Exiting..."
		exit 0
	fi
}

function find_plugins {
# the plugins can be located in one of 2 places
# /usr/lib64/nagios/plugins (for newer installs) - OR - /usr/local/nagios/libexec for the older
# this info is needed by the functions that add the additonal nrpe checks furhter down 
	if [ "$conf" == "/etc/nagios/nrpe.cfg" ]
	then
	# "newer" setup
		plugins="/usr/lib64/nagios/plugins"
	else
	# "older" setup
		plugins="/usr/local/nagios/libexec"
	fi
}

function backup_cfg {
# ensure that there is a copy of nrpe.cfg
	echo "Backing up the nrpe.cfg now"
	timestamp=`date '+%y-%m-%d-%H:%M:%S'`
	cp $conf $conf-FactoryDefaults-$timestamp
	echo "done"; echo ""
}

function remind_to_configure_server {
# it is necessary to configure the server with the hostname of the new server to be monitored
# remind whoever is running this script to do so
cat <<_EOF_

Remember, on the monitoring sever server, i.e. sevice01.tchpc.tcd.ie 

You have to create the 'object' for the server to be monitored in /usr/local/nagios/etc/objects/

To do so, run the following command from service01

	sh /usr/local/nagios/etc/addhost.sh $hostname

THEN

Verify the nagios setup on the server to make sure adding the host has gone as expected

	/usr/sbin/nagios -v /etc/nagios/nagios.cfg

-> should return something like: 

	"Things look okay - No serious problems were detected during the pre-flight check"

Restart the nagios service, ensure that the verify check above returns as okay

	service nagios restart

The new server being monitored should then appear in the list of hosts in nagios on service01

_EOF_

	read -p "Got that??? If so press the [Enter] key to continue..."
	echo ""
}

function update_allowed_hosts {
# change allowed_hosts=127.0.0.1 To: allowed_hosts=134.226.112.4 in the nrpe.cfg
	echo "Updating the allowed_hosts setting in the nrpe.cfg file"
	local="127.0.0.1"
	server_ip="134.226.112.44"
	sed -i 's/'$local'/'$server_ip'/g' $conf
	echo "done"; echo ""
}

# adding additional items to check to the configuration file

function add_check_swap { 
	echo "command[check_swap]=/usr/lib64/nagios/plugins/check_swap -w 20% -c 10%" >> $conf
	echo "Added check_swap to $conf "; echo "" 
}

function add_check_ntp { 
	hostname=`hostname -s`
	echo "command[check_ntp]=/usr/lib64/nagios/plugins/check_ntp_time -H $hostname" >> $conf
	echo "Added check_ntp to $conf "; echo "" 
}

function add_check_all_disks { 
	echo "command[check_all_disks]=/usr/lib64/nagios/plugins/check_disk -w 20 -c 10 -x /" >> $conf
	echo "Added check_all_disks to $conf"
	echo "Note - this is only doing the boot volume"
	echo "i.e. / "
	echo "not other disks or volumes are added here"
	echo "" 
}

#--------------------------------------------------------------------------------------------------
# begin workflow
#--------------------------------------------------------------------------------------------------

echo "Setting up Nagios Remote Plugin Executor (NRPE) so this server can be monitored"
echo ""

create_account

install_software

configure_firewall

find_config

backup_cfg

update_allowed_hosts

setup_nrpe_service

echo "Adding additional items to check to the configuration file"; echo ""
add_check_swap
add_check_ntp
add_check_all_disks

remind_to_configure_server

echo ""; echo "Script complete"

exit 0
