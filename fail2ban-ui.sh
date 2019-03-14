#!/bin/bash

# fail2ban cnfg
# author: JGilson
# updated February 27, 2019
# ------------------------------------------------------------------------------------------------

menu() {
	clear

    CHOICE=$(whiptail --title "Fail2ban" --menu "Choose one option:" 25 100 15 \
        	"1" "Service" \
			"2" "Configuration" \
        	"3" "Blacklist" \
			"4" "Whitelist" 3>&1 1>&2 2>&3)
    
	case $CHOICE in
	    1)	menu_service;;
        2)	menu_configuration;;
		3)	menu_blacklist;;
		4)	menu_whitelist;;
    esac
}


menu_service () {
	clear

	yum clean metadata

	cmd=(whiptail --title "Service" --separate-output --radiolist "Choose the command:" 25 100 15)
	options=(
			1 "Install" off
			2 "Start" off
			3 "Stop" off
			4 "Restart" off)

	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices
	do
		case $choice in
			1)
				if ! rpm -q fail2ban; then
					echo "Installing fail2ban..."
					sudo yum install -y fail2ban
					sleep 3
					systemctl enable fail2ban
					configure_environment
				fi
				;;
			2)
				service fail2ban start
				;;
			3)
				service fail2ban stop
				;;
			4)
				service fail2ban restart
				;;			
		esac
	done

	menu
}


configure_environment() {
cat > /etc/fail2ban/jail.local <<EOF
#destemail=root@localhost
#ignoreip=127.0.0.1

[DEFAULT]
ignoreip = 127.0.0.1
bantime = 1700
findtime = 600
maxretry = 8
backend = auto

[asterisk-iptables]
enabled = true
filter = asterisk
action = iptables-allports[name=SIP, protocol=all]
         sendmail[name=SIP, dest="%(destemail)s", sender=asterisk@fail2ban.local]
logpath = /var/log/asterisk/full
EOF
}


menu_configuration() {
	clear
	
	bantime=$(fail2ban-client get asterisk-iptables bantime)
	maxretry=$(fail2ban-client get asterisk-iptables maxretry)
	findtime=$(fail2ban-client get asterisk-iptables findtime)
	destemail=`cat /etc/fail2ban/jail.local | grep "#destemail" | cut -d'=' -f2`
	ignoreip=`cat /etc/fail2ban/jail.local | grep "#ignoreip" | cut -d'=' -f2`

	record=$(dialog 								\
		--separate-widget $'\n'                     \
		--title "Configuration"                     \
		--form ""                                   \
		25 100 15                                   \
		"Ban time:  "  1 1  "$bantime"   1 12 10 0  \
		"Max retry: "  2 1  "$maxretry"  2 12 10 0  \
		"Find time: "  3 1  "$findtime"  3 12 10 0  \
		"E-mail:    "  4 1  "$destemail" 4 12 100 0 \
		"Whitelist: "  5 1  "$ignoreip"  5 12 100 0 \
	  3>&1 1>&2 2>&3)
	  
	bantime=$(echo "$record" | sed -n 1p)
	maxretry=$(echo "$record" | sed -n 2p)
	findtime=$(echo "$record" | sed -n 3p)
	destemail=$(echo "$record" | sed -n 4p)
	ignoreip=$(echo "$record" | sed -n 5p)
	
	clear

	# default values
	if [ -z "$bantime" ]; then
		bantime="1700"
	fi

	if [ -z "$maxretry" ]; then
		maxretry="8"
	fi

	if [ -z "$findtime" ]; then
		findtime="600"
	fi

	if [ -z "$destemail" ]; then
		destemail="root@localhost"
	fi

	if [ -z "$ignoreip" ]; then
		ignoreip="127.0.0.1"
	fi

if (whiptail --title "Configuration" --yesno "Save configuration and restart the server?" 8 78); then

cat > /etc/fail2ban/jail.local <<EOF
#destemail=$destemail
#ignoreip=$ignoreip

[DEFAULT]
ignoreip = $ignoreip
bantime = $bantime
findtime = $findtime
maxretry = $maxretry
backend = auto

[asterisk-iptables]
enabled = true
filter = asterisk
action = iptables-allports[name=SIP, protocol=all]
         sendmail[name=SIP, dest=$destemail, sender=asterisk@fail2ban.local]
logpath = /var/log/asterisk/full
EOF

service fail2ban restart

fi

	menu
}


menu_blacklist() {
	clear

	CMD=$(iptables -L -n | awk '$1=="REJECT" && $4!="0.0.0.0/0" {print $4}')
	
	whiptail --title "Blacklist" --msgbox "$CMD" --scrolltext 25 100 15
	
	menu
}

menu_whitelist() {
	clear

	CMD=$(fail2ban-client get asterisk-iptables ignoreip)

	whiptail --title "Whitelist" --msgbox "$CMD" --scrolltext 25 100 15
	
	menu
}

install_dependencies() {
	if ! rpm -q dialog; then
    	echo "Installing dependencies..."
		yum install -y dialog
	fi
}

# ------------------------------------------------------------------------------------------------
install_dependencies
menu

