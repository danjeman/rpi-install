#!/bin/bash
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
tred=$(tput setaf 1)
tgreen=$(tput setaf 2)
tyellow=$(tput setaf 3)
tdef=$(tput sgr0)
MAC=$(cat /sys/class/net/eth0/address)
PASS=e4syTr1d3nt
model=$(cat /proc/device-tree/model)
version=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' /etc/os-release |tr -d \")
frver=$(awk -F= '$1=="VERSION" { print $2 ;}' /etc/os-release |tr -d \")
platform=$(uname -m)
if [[ "$platform" == "arm64" ]]
    then
    tvpi=https://download.teamviewer.com/download/linux/teamviewer-host_arm64.deb
    tvi=teamviewer-host_arm64.deb
    boot=/boot/firmware/config.txt
    sbci="wget -qO- http://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip"
    else
    tvpi=https://download.teamviewer.com/download/linux/teamviewer-host_armhf.deb
    tvi=teamviewer-host_armhf.deb
    boot=/boot/config/txt
    sbci="wget -qO- https://downloads-global.3cx.com/downloads/misc/d10pi.zip"
    fi

# if not a pi running arm image error and exit - check for armxxx architecture in uname -m - deault pi os64 is aarch64 not arm64
if ! [[ "$platform" =~ "arm" ]]
then
    echo "This install script is for Raspberry Pi's only, please use the correct script for your hardware"
    exit 1
fi
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
# Detect if buster or bookworm and set options depending on $model
# $version == 10 then buster == 11 then bullseye ==12 bookworm ==13 trixie
# upgrade from Buster using following 3 lines wget https://downloads-global.3cx.com/downloads/sbcosupgrade/sbcosupgrade.sh
# chmod +x sbcosupgrade.sh
# sudo bash sbcosupgrade.sh
# install new v20 on pi sudo bash -c "$(wget -qO- http://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip)"
# if buster suite changed to oldstable then will error (E) advising of that on first run of update check - run it twice just in case
/usr/bin/sudo /usr/bin/apt -y update 2>&1
if ! /usr/bin/sudo /usr/bin/apt -y update 2>&1 | grep -q '^[WE]:'; then
    echo "${tgreen}Update check completed.${tdef}" 
else
    echo "${tred}Unable to check for updates - please verify internet connectivity.${tdef}"
    exit 1
fi
echo "setting user pi password..."
echo "pi:$PASS" | /usr/bin/sudo chpasswd
echo "Upgrading as needed..."
/usr/bin/sudo /usr/bin/apt -y upgrade
echo "Installing monitoring agent..."
/usr/bin/sudo /usr/bin/apt -y install zabbix-agent nmap tcpdump
echo "system updated and zabbix monitoring agent and network tools installed."
echo "Configuring monitoring agent..."
# edit zabbix_agentd.conf set zabbix server IP to 213.218.197.155 set hostname to $NAME
sed -i s/^Server=127.0.0.1/Server=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^ServerActive=127.0.0.1/ServerActive=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^\#.Hostname=/Hostname=$NAME/ /etc/zabbix/zabbix_agentd.conf
/usr/bin/curl -o /etc/zabbix/zabbix_agentd.conf.d/userparameter_rpi.conf https://raw.githubusercontent.com/danjeman/rpi-zabbix/main/userparameter_rpi.conf
/usr/sbin/usermod -a -G video zabbix
/usr/bin/sudo /usr/sbin/service zabbix-agent restart
echo "${tgreen}Monitoring agent configured.${tdef}"
# Set display resolution to permit TV host to work otherwise nothing to display - either edit /boot/config.txt or just use raspi-config enable uart if not already
echo "Setting display resolution to 1023x768 for remote Teamviewer access"
# sed -i s/^\#hdmi_force_hotplug=1/hdmi_force_hotplug=1/ /boot/config.txt
# sed -i s/^\#hdmi_group=1/hdmi_group=2/ /boot/config.txt
# sed -i s/^\#hdmi_mode=1/hdmi_mode=16/ /boot/config.txt
# grep -qxF 'enable_uart=1' /boot/config.txt || echo "enable_uart=1" >> /boot/config.txt
sed -i s/^\#hdmi_force_hotplug=1/hdmi_force_hotplug=1/ $boot
sed -i s/^\#hdmi_group=1/hdmi_group=2/ $boot
sed -i s/^\#hdmi_mode=1/hdmi_mode=16/ $boot
grep -qxF 'enable_uart=1' $boot || echo "enable_uart=1" >> $boot
echo $NAME > /etc/hostname
sed -i s/^127.0.1.1.*raspberrypi/127.0.1.1\t$NAME/g /etc/hosts
echo "Installing Teamviewer host"
# wget https://download.teamviewer.com/download/linux/teamviewer-host_armhf.deb ## Current 15.38.3 breaks teamviewer on pi so old version required
# dpkg -i teamviewer-host_armhf.deb >/dev/null 2>&1
# wget https://dl.teamviewer.com/download/linux/version_15x/teamviewer-host_15.35.7_armhf.deb
# dpkg -i teamviewer-host_15.35.7_armhf.deb >/dev/null 2>&1
wget $tvpi
dpkg -i $tvi >/dev/null 2>&1
apt -y --fix-broken install
teamviewer passwd easytr1dent25 >/dev/null 2>&1
TVID=$(/usr/bin/sudo teamviewer info | grep "TeamViewer ID:" | sed 's/^.*: \s*//')
# ask if using controllable fan and then set parameters in /boot/config.txt or /boot/firmware/config.txt depending on version if yes - dtoverlay=gpio-fan,gpiopin=18,temp=55000
if [ "no" == $(ask_yes_or_no "Install temperature based speed control for Argon mini Fan?") ]
    then
        echo "${tyellow}Please ensure Fan is manually enabled if required or install appropriate controls for Fan accessory in use.${tdef}"
    else
        # echo "# Fan speed control start at 55C" >> /boot/config.txt
        # echo "dtoverlay=gpio-fan,gpiopin=18,temp=55000" >> /boot/config.txt
        echo "# Fan speed control start at 55C" >> $boot
        echo "dtoverlay=gpio-fan,gpiopin=18,temp=55000" >> $boot
fi
if [ "no" == $(ask_yes_or_no "Install 3cx SBC/PBX for Raspberry Pi 4 (wget https://downloads-global.3cx.com/downloads/misc/d10pi.zip; sudo bash d10pi.zip) or Pi 5 (wget http://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip -O- |sudo bash;), if instructions have changed then say no?") ]
    then
        echo "${tred}Please go to 3cx website for latest instructions to install SBC/PBX and continue manually.${tdef}"
        echo "${tyellow}Don't forget to reboot and complete Teamviewer setup process - \"teamviewer setup\" to add this device to the IBT account.${tdef}"
        echo "Below is a list of the info used for this setup - ${tred}take note for job sheet/asset info.${tdef}"
        echo "${tyellow}Monitoring hostname =${tdef} $NAME"
        echo "${tyellow}Password for pi =${tdef} $PASS"
        echo "${tyellow}Teamviewer ID =${tdef} $TVID"
        echo "${tyellow}MAC address =${tdef} $MAC."
        echo "${tyellow}Model =${tdef} $model."
        echo "${tyellow}Debian ver =${tdef} $frver."
        echo "${tgreen}Please update helpdesk asset and ticket/job progress sheet.${tdef}"
        echo "Goodbye"
    exit 0
fi
# /usr/bin/sudo wget https://downloads-global.3cx.com/downloads/misc/d10pi.zip; sudo bash d10pi.zip
/usr/bin/sudu -c "$("$sbci")"
echo "${tyellow}Don't forget to reboot and then complete Teamviewer setup process - \"teamviewer setup\" to add this device to the IBT account.${tdef}"
echo "Below is a list of the info used for this setup - ${tred}take note for job sheet/asset info.${tdef}"
echo "${tyellow}Monitoring hostname =${tdef} $NAME"
echo "${tyellow}Password for pi =${tdef} $PASS"
echo "${tyellow}Teamviewer ID =${tdef} $TVID"
echo "${tyellow}MAC address =${tdef} $MAC."
echo "${tyellow}Model =${tdef} $model."
echo "${tyellow}Debian ver =${tdef} $frver."
echo "${tgreen}Please update helpdesk asset and ticket/job progress sheet.${tdef}"
echo "Goodbye"
