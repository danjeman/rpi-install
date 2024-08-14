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
model=$(tr -d '\0' < /proc/device-tree/model)
version=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' /etc/os-release |tr -d \")
frver=$(awk -F= '$1=="VERSION" { print $2 ;}' /etc/os-release |tr -d \")
platform=$(uname -m)
# debug option 0 no debug 1 basic 2 full
debug=0

# if not a pi running arm image error and exit - check for armxxx architecture in uname -m - deault pi os64 is aarch64 not arm64
if ! [[ "$platform" =~ "arm" || "$platform" =~ "aarch64" ]]
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
echo "${tyellow}Checking and updating bootloader if available - ensure to reboot at the end to complete!${tdef}"
sudo rpi-eeprom-update -a
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
# platform specific variables and settings
if [[ "$platform" == "arm64" || "$platform" =~ "aarch64" ]]
    then
    # Add desktop and browser to OS lite image
    /usr/bin/sudo /usr/bin/apt -y install raspberrypi-ui-mods
    /usr/bin/sudo /usr/bin/apt -y install chromium
    tvpi=https://download.teamviewer.com/download/linux/teamviewer-host_arm64.deb
    tvi=teamviewer-host_arm64.deb
    boot=/boot/firmware/config.txt
    sbci="wget -qO- http://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip"
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
    cat > /etc/xdg/autostart/vnc_xrandr.desktop << EOF
[Desktop Entry]
Type=Application
Name=vnc_xrandr
Comment=Set resolution for VNC
NoDisplay=true
Exec=sh -c "if ! (xrandr | grep -q -w connected) ; then /usr/bin/xrandr --fb 1024x768 ; fi"
EOF
    /usr/bin/systemctl --quiet set-default graphical.target
    sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?user-session.*/user-session=LXDE-pi-x/"
    sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=pi/"
    sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?autologin-session.*/autologin-session=LXDE-pi-x/"
    sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?greeter-session.*/greeter-session=pi-greeter/"
    sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-test.*/#fallback-test=/"
    sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-session.*/#fallback-session=/"
    sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-greeter.*/#fallback-greeter=/"
        if [ -e "/var/lib/AccountsService/users/pi" ] ; then
          sed "/var/lib/AccountsService/users/pi" -i -e "s/XSession=.*/XSession=LXDE-pi-x/"
        fi
        if ! [[ "$debug" == "0" ]]
        then
            echo "This is running as platform $platform"
            echo "and will use $sbci"
        fi
    else
    tvpi=https://download.teamviewer.com/download/linux/teamviewer-host_armhf.deb
    tvi=teamviewer-host_armhf.deb
    boot=/boot/config.txt
    sbci="wget -qO- http://downloads-global.3cx.com/downloads/misc/d10pi.zip"
    if ! [[ "$debug" == "0" ]]
        then
        echo "This is running as platform $platform"
        echo "and will use $sbci"
        fi
    fi

echo "setting user pi password..."
echo "pi:$PASS" | /usr/bin/sudo chpasswd
echo "Upgrading as needed..."
/usr/bin/sudo /usr/bin/apt -y upgrade
echo "Installing monitoring agent..."
/usr/bin/sudo /usr/bin/apt -y install zabbix-agent nmap tcpdump
echo "${tgreen}System updated and zabbix monitoring agent and network tools installed.${tdef}"
echo "Configuring monitoring agent..."
# edit zabbix_agentd.conf set zabbix server IP to 213.218.197.155 set hostname to $NAME
sed -i s/^Server=127.0.0.1/Server=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^ServerActive=127.0.0.1/ServerActive=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^\#.Hostname=/Hostname=$NAME/ /etc/zabbix/zabbix_agentd.conf
/usr/bin/curl -o /etc/zabbix/zabbix_agentd.conf.d/userparameter_rpi.conf https://raw.githubusercontent.com/danjeman/rpi-zabbix/main/userparameter_rpi.conf
/usr/sbin/usermod -a -G video zabbix
/usr/bin/sudo /usr/sbin/service zabbix-agent restart
echo "${tgreen}Monitoring agent configured.${tdef}"
# Set display resolution to permit TV host to work otherwise nothing to display - either edit /boot/config.txt or just use raspi-config enable uart if not already - pi 5 handled differently but not in config.txt so can leave for now
echo "Setting display resolution to 1024x768 for remote Teamviewer access"
sed -i s/^\#hdmi_force_hotplug=1/hdmi_force_hotplug=1/ $boot
sed -i s/^\#hdmi_group=1/hdmi_group=2/ $boot
sed -i s/^\#hdmi_mode=1/hdmi_mode=16/ $boot
grep -qxF 'enable_uart=1' $boot || echo "enable_uart=1" >> $boot
echo $NAME > /etc/hostname
# in case already changed hostname better to add another resolution than replace, maybe... can look at cleaning up if causes other issues but should be better while processing first run
# sed -i s/^127.0.1.1.*raspberrypi/127.0.1.1    $NAME/g /etc/hosts
echo "127.0.0.1    $NAME" >> /etc/hosts
echo "Installing Teamviewer host"
# remove old tv downloads as new would not be installed
/usr/bin/rm -f teamviewer-host*
/usr/bin/wget $tvpi
/usr/bin/dpkg -i $tvi >/dev/null 2>&1
/usr/bin/sudo /usr/bin/apt -y --fix-broken install
# remove redundant packages
/usr/bin/sudo /usr/bin/apt -y autoremove
teamviewer passwd easytr1dent25 >/dev/null 2>&1
TVID=$(/usr/bin/sudo teamviewer info | grep "TeamViewer ID:" | sed 's/^.*: \s*//' | tr -d ' ')
TVVER=$(/usr/bin/sudo teamviewer version | grep "TeamViewer" | sed 's/^.*TeamViewer \s*//' |tr -d ' ')
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
if [ "no" == $(ask_yes_or_no "Install 3cx SBC/PBX, for Raspberry Pi 4 uses (wget https://downloads-global.3cx.com/downloads/misc/d10pi.zip; sudo bash d10pi.zip) or for Pi 5 uses (wget http://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip -O- |sudo bash;), if instructions have changed then say no?") ]
    then
        echo "${tred}Please go to 3cx website for latest instructions to install SBC/PBX and continue manually.${tdef}"
        echo "${tyellow}Don't forget to reboot to finalise settings and then on new login complete Teamviewer setup process - \"teamviewer setup\" to add this device to the IBT account.${tdef}"
        echo "Below is a list of the info used for this setup - ${tred}take note for job sheet/asset info.${tdef}"
        echo "${tyellow}Monitoring hostname =${tdef} $NAME"
        echo "${tyellow}Password for pi =${tdef} $PASS"
        echo "${tyellow}Teamviewer ID =${tdef} $TVID"
        echo "${tyellow}Teamviewer Version =${tdef} $TVVER"
        echo "${tyellow}MAC address =${tdef} $MAC."
        echo "${tyellow}Model =${tdef} $model."
        echo "${tyellow}Debian ver =${tdef} $frver."
        echo "${tgreen}Please update helpdesk asset and ticket/job progress sheet.${tdef}"
        echo "Goodbye"
    exit 0
fi
/usr/bin/sudo bash -c "$($sbci)"
echo "${tyellow}Don't forget to reboot to finalise settings and then on new login complete Teamviewer setup process - \"teamviewer setup\" to add this device to the IBT account.${tdef}"
echo "Below is a list of the info used for this setup - ${tred}take note for job sheet/asset info.${tdef}"
echo "${tyellow}Monitoring hostname =${tdef} $NAME"
echo "${tyellow}Password for pi =${tdef} $PASS"
echo "${tyellow}Teamviewer ID =${tdef} $TVID"
echo "${tyellow}Teamviewer Version =${tdef} $TVVER"
echo "${tyellow}MAC address =${tdef} $MAC."
echo "${tyellow}Model =${tdef} $model."
echo "${tyellow}Debian ver =${tdef} $frver."
echo "${tgreen}Please update helpdesk asset and ticket/job progress sheet.${tdef}"
echo "Goodbye"
