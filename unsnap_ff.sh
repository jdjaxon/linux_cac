#!/usr/bin/env bash

#snap remove firefox
#
#sudo add-apt-repository -y ppa:mozillateam/ppa
#
#echo '
#Package: *
#Pin: release o=LP-PPA-mozillateam
#Pin-Priority: 1001
#' | sudo tee /etc/apt/preferences.d/mozilla-firefox
#
#echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox
#
#sudo apt install firefox

ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

echo -e "${INFO_COLOR}[INFO]${NO_COLOR} Starting Firefox silently to complete post-install actions..."
echo -e "Running as user: \"$SUDO_USER\" with home: \"$ORIG_HOME\""
sudo -H -u "$SUDO_USER" bash -c 'firefox --headless --first-startup >/dev/null 2>&1 &'
sleep 3
pkill -9 firefox
sleep 1
echo -e "${INFO_COLOR}[INFO]${NO_COLOR} Finished, closing Firefox."