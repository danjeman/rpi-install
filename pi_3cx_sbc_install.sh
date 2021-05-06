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
if [ "no" == $(ask_yes_or_no "Set pi user password to IBT default?") ]
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
echo "setting user pi password..."
echo "pi:$PASS" | /usr/bin/sudo chpasswd
echo "Upgrading as needed..."
/usr/bin/sudo /usr/bin/apt -y upgrade
echo "Installing monitoring agent..."
/usr/bin/sudo /usr/bin/apt install zabbix-agent
echo "system updated and zabbix monitoring agent installed."
echo "Configuring monitoring agent..."
# edit zabbix_agentd.conf set zabbix server IP to 213.218.197.155 set hostname to $NAME
sed -i s/^Server=127.0.0.1/Server=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^ServerActive=127.0.0.1/ServerActive=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^\#.Hostname=/Hostname=$NAME/ /etc/zabbix/zabbix_agentd.conf
/usr/bin/curl -o /etc/zabbix/zabbix_agentd.conf.d/userparameter_rpi.conf https://raw.githubusercontent.com/danjeman/rpi-zabbix/main/userparameter_rpi.conf
/usr/sbin/usermod -a -G video zabbix
/usr/bin/sudo /usr/sbin/service zabbix-agent restart
echo "Monitoring agent configured"
# Set display resolution to permit TV host to work otherwise nothing to display - either edit /boot/config.txt or just use raspi-config enable uart if not already
echo "Setting display resolution to 1023x768 for remote Teamviewer access"
sed -i s/^\#hdmi_force_hotplug=1/hdmi_force_hotplug=1/ /boot/config.txt
sed -i s/^\#hdmi_group=1/hdmi_group=2/ /boot/config.txt
sed -i s/^\#hdmi_mode=1/hdmi_mode=16/ /boot/config.txt
grep -qxF 'enable_uart=1' /boot/config.txt || echo "enable_uart=1" >> /boot/config.txt
echo $NAME > /etc/hostname
sed -i s/^127.0.1.1.*raspberrypi/127.0.1.1\t$NAME/g /etc/hosts
echo "Installing Teamviewer host"
wget https://download.teamviewer.com/download/linux/teamviewer-host_armhf.deb
dpkg -i teamviewer-host_armhf.deb >/dev/null 2>&1
apt -y --fix-broken install
teamviewer passwd easytr1dent >/dev/null 2>&1
# ask if using controllable fan and then set parameters in /boot/config.txt if yes - dtoverlay=gpio-fan,gpiopin=18,temp=55000
if [ "no" == $(ask_yes_or_no "Install temperature based speed control for Argon mini Fan?") ]
    then
        echo "Please ensure Fan is manually enabled if required or install appropriate controls for Fan accessory in use"
    else
        echo "# Fan speed control start at 55C" >> /boot/config.txt
        echo "dtoverlay=gpio-fan,gpiopin=18,temp=55000" >> /boot/config.txt
fi
if [ "no" == $(ask_yes_or_no "Install 3cx SBC/PBX for Raspberry Pi \(wget https://downloads-global.3cx.com/downloads/misc/d10pi.zip; sudo bash d10pi.zip\), if instructions have changed then say no?") ]
    then
        echo "Please go to 3cx website for latest instructions to install SBC/PBX and continue manually"
        echo "Don't forget to reboot and complete Teamviewer setup process - "teamviewer setup" to add this device to the IBT account"
        echo "Below is a list of the info used for this setup"
        echo "Monitoring hostname = $NAME"
        echo "Password for pi = $PASS"
        /usr/bin/sudo teamviewer info | grep "TeamViewer ID:"
    exit 0
fi
/usr/bin/sudo wget https://downloads-global.3cx.com/downloads/misc/d10pi.zip; sudo bash d10pi.zip
echo "Don't forget to reboot and then complete Teamviewer setup process - "teamviewer setup" to add this device to the IBT account"
echo "Below is a list of the info used for this setup"
echo "Monitoring hostname = $NAME"
echo "Password for pi = $PASS"
/usr/bin/sudo teamviewer info | grep "TeamViewer ID:"
echo "Please update helpdesk asset and ticket/job progress sheet"
echo "Goodbye"
