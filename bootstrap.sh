#!/usr/bin/env bash

# Check that user is root, exit if not
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

os=$(head -1 /etc/os-release)

# Set up host key for root, put keys in resources/authorized_keys
if [ -s /tmp/resources/authorized_keys ]; then
  mkdir -p /root/.ssh
  cp -f /tmp/resources/authorized_keys /root/.ssh
fi

# Allow root to login with key
sed -i -e 's/^PermitRootLogin (yes|no)$/\#PermitRootLogin no/' /etc/ssh/sshd_config
echo "PermitRootLogin without-password" >> /etc/ssh/sshd_config

# Only allow other users to login with key
sed -i -e 's/^PasswordAuthentication yes$//' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Install modded bashrc
cp -f /tmp/resources/.bashrc ~/.bashrc

# Set bashrc for non-root users based on OS
if [[ $os =~ .*"Debian".* || $os =~ .*"Kali".* || $os =~ .*"Ubuntu".* ]] ; then
    sed -i -e 's/^PS1="${debian.*$/PS1="${debian_chroot:+($debian_chroot)}\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "/' /etc/skel/.bashrc
elif [[ $os =~ .*"CentOS".* ]] ; then
    echo 'PS1="${debian_chroot:+($debian_chroot)}\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "' >> /etc/skel/.bashrc
fi

# Set up profile for new accounts:
sed -i -e 's/^\#force_color_prompt=yes$/force_color_prompt=yes/' /etc/skel/.bashrc
cat >> /etc/skel/.bashrc <<bashrcadds
alias ll='ls -lh'
alias la='ls -lah'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
bashrcadds

# Setup vimrc
cp -f /tmp/resources/.vimrc /root
cp -f /tmp/resources/.vimrc /etc/skel

# Install nice things
if [[ $os =~ .*"Debian".* || $os =~ .*"Kali".* || $os =~ .*"Ubuntu".* ]] ; then
    apt-get update
    apt-get -y install rsync wget curl screen vim lynx sudo firewalld network-manager grepcidr mlocate gawk
    apt-get -y upgrade
elif [[ $os =~ .*"CentOS".* ]] ; then
    yum check-update
    yum -y install rsync wget curl screen vim lynx sudo firewalld net-tools mlocate gawk
    yum -y upgrade
else
    echo "Linux distribution not supported by this script. Please run only on CentOS, Debian, or Kali."
fi

# Make sure system is not using local interfaces, we want to use NetworkManager
# Reference: https://help.ubuntu.com/community/NetworkManager
sed -ie "s/^\([^#].*eth\)/#\1/" /etc/network/interfaces

# Stop and disable Firewalld
systemctl stop firewalld
systemctl disable firewalld

# VMWare : https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1006427
# VMWARE : https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2011861
# Hyper-V : https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/best-practices-for-running-linux-on-hyper-v
# NMI Watchdog should help high CPU usage on Debian systems
# Add Kernel Options if we are on HyperV
if [[ "$(dmidecode -s system-product-name)" == "Virtual Machine" ]] && [[ $os =~ .*"CentOS".* ]] ; then
        sed -i -e 's/^GRUB_TIMEOUT=[0-9]$/GRUB_TIMEOUT=5000/' /etc/default/grub
        grub2-mkconfig -o "$(readlink /etc/grub2.conf)"
elif [[ "$(dmidecode -s system-product-name)" == "Virtual Machine" ]] ; then
        sed -i -e 's/^GRUB_CMDLINE_LINUX=\"\"$/GRUB_CMDLINE_LINUX=\"numa=off elevator=noop nmi_watchdog=0\"/' /etc/default/grub
        update-grub
elif [[ "$(dmidecode -s system-product-name)" =~ .*"VMWare".* ]] &&  [[ $os =~ .*"CentOS".* ]] ; then
        sed -i -e 's/^GRUB_CMDLINE_LINUX=\"\"$/GRUB_CMDLINE_LINUX=\"elevator=noop\"/' /etc/default/grub
        grub2-mkconfig -o "$(readlink /etc/grub2.conf)"
fi