#!/bin/bash
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
PASS=e4syTr1d3nt
echo "#####IBT Rpi 3CX SBC install script#####"
echo "Please, enter hostname to use for device monitoring - e.g gch.svg.sbc.3cx.co.uk"
read NAME
if [[ "no" == $(ask_yes_or_no "Install will continue using $NAME as the hostname for monitoring. Are you sure?") || \
      "no" == $(ask_yes_or_no "Are you *really* sure?") ]]
then
    echo "Please re-enter hostname."
    read NAME
    if [[ "no" == $(ask_yes_or_no "Install will continue using $NAME as the hostname for monitoring. Are you sure?") || \
      "no" == $(ask_yes_or_no "Are you *really* sure?") ]]
    then
      echo "Skipped - please re-run script to begin again"
      exit 0
      fi
fi
if [ "no" == $(ask_yes_or_no "Set password to IBT default?") ]
    then
        echo "Please enter password."
        read PASS
        if [[ "no" == $(ask_yes_or_no "Password will be set to $PASS, is that correct?") || \
          "no" == $(ask_yes_or_no "Are you *really* sure?") ]]
          then
            echo "Please re-run install script with correct details"
            exit 0
            fi
fi
           echo "Great, continuing to update packages and install monitoring..."
echo "Checking for updates..."
if ! /usr/bin/sudo /usr/bin/apt update 2>&1 | grep -q '^[WE]:'; then
    echo "Update check completed" 
else
    echo "Unable to check for updates - please verify internet connectivity"
    exit 1
fi
#OUTPUT=`apt-get update 2>&1`

#if [[ $? != 0 ]]; then
#  echo "$OUTPUT"
#fi
#/usr/bin/sudo /usr/bin/apt update
/usr/bin/sudo sh -c "'echo pi:$PASS | chpasswd'"
echo "Upgrading as needed..."
/usr/bin/sudo /usr/bin/apt -y upgrade
echo "Installing monitoring agent..."
/usr/bin/sudo /usr/bin/apt install zabbix-agent
echo "system updated and zabbix monitoring agent installed."
echo "Configuring monitoring agent..."
# edit zabbix_agentd.conf replace server=127.0.0.1 with server=213.218.197.155 set hostname to $NAME
sed -i s/^Server=127.0.0.1/Server=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^ServerActive=127.0.0.1/ServerActive=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^\#.Hostname=/Hostname=$NAME/ /etc/zabbix/zabbix_agentd.conf
/usr/bin/curl -o /etc/zabbix/zabbix_agentd.conf.d/userparameter_rpi.conf https://raw.githubusercontent.com/danjeman/rpi-zabbix/main/userparameter_rpi.conf
/usr/sbin/usermod -a -G video zabbix
/usr/bin/sudo /usr/sbin/service zabbix-agent restart
echo "Monitoring agent configured"
echo "Installing Teamviewer host"
sudo apt install teamviewer-host
teamviewer passwd easytr1dent
echo "Please run "teamviewer setup" to add Teamviewer to the IBT account - check IT Queue to authorise addition"
