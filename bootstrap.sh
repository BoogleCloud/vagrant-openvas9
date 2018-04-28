#!/usr/bin/env bash

# Check that user is root, exit if not
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

os=$(head -1 /etc/os-release)

#TODO Add checking for key being added. If key is nor found, tell user to add and exit.

# Set up host key for root, paste needed keys here
mkdir -p /root/.ssh
# Paste your SSH key after ssh-rsa on the same line
cat >> /root/.ssh/authorized_keys <<sshkey
ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAjZT7yrwz7RsDwl9fkAGmP7mo/vcps00/UJh4rVUDMCcAZo5QrnTCyfvn9NAW3Jv33bGMhSNAcOilLsjfi2fZ5JBpsD6H8334AxvdUs8YTSQqGGEyJe7526u+pg94WdEgJpnOSLT+3IerazUJkd+KBdYMUVpJR4YsOuovB8kGqiWgzvZ3CERuEBs0z2+z0eT/kbXCUKrzM6s2XXKTJDWRhfhoWLDh+5wrRj6RtLWclPVYlw++A+oRnh96l4d68E2hsSI2L4B73JNMMu2MB4lR0lW8dtL4OP2Wa1Jg8U33gI0eymdC6bNp0XxOl/JDqLTQ+Yvd9WYhjT7OgflySoEHcZHAn5WwDhVRke51Sz3gglQgpy5xr7+gSRCLh0jg8qiKiMyPL9J1pzMCmuGzdqM9T2dpeHg8hRAjCStC64o/QXgI6e3XjEF6X5JxDKvV0fR2G0B9BrJhN0vedIh1C4IpbWCjREjmvfPMRlqHafmnZrHIBAHoWZ9/cpuRoWJMpRUanyH/2TF3Vw/xACasZ5UqFCj0UN52G1MQWPWUA8WrlD4GxV0OliptbXqymHSAQxdN9GbR9KXykd7HsTAJmLM0eOWwMFqJCb+XwVpdHX/chZaO7BMwhfmBG3OzQBn69BzLNOqly82XHNA101pSJQNJwI0nDTxAJVWRLinAJdCFUNU= rsa-key-20151027
sshkey

# Allow root to login with key
sed -i -e 's/^PermitRootLogin (yes|no)$/\#PermitRootLogin no/' /etc/ssh/sshd_config
echo "PermitRootLogin without-password" >> /etc/ssh/sshd_config

# Only allow other users to login with key
sed -i -e 's/^PasswordAuthentication yes$//' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Put SSH rules into effect
if [[ $os =~ .*"Debian".* || $os =~ .*"CentOS".* || $os =~ .*"Ubuntu".* ]] ; then
    systemctl reload sshd
elif [[ $os =~ .*"Kali".* ]] ; then
    systemctl reload ssh
fi

# Install modded bashrc for root
cat > /root/.bashrc <<EOF
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case \$- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "\$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "\${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=\$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "\$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "\$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
    else
    color_prompt=
    fi
fi

if [ "\$color_prompt" = yes ]; then
    PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;31m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '
else
    PS1='\${debian_chroot:+(\$debian_chroot)}\\u@\\h:\\w\\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "\$TERM" in
xterm*|rxvt*)
    PS1="\\[\\e]0;\${debian_chroot:+(\$debian_chroot)}\\u@\\h: \\w\\a\\]\$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 and umask are already set in /etc/profile. You should not
# need this unless you want different defaults for root.
# PS1='\${debian_chroot:+(\$debian_chroot)}\\h:\\w\\$ '
# umask 022

# You may uncomment the following lines if you want \`ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "\`dircolors\`"
# alias ls='ls \$LS_OPTIONS'
# alias ll='ls \$LS_OPTIONS -l'
# alias l='ls \$LS_OPTIONS -lA'
#
# Some more alias to avoid making mistakes:
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
EOF

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

# Create vimrc
cat >> /root/.vimrc <<vimrcadds
syntax on
set smartindent
set bg=dark
set tabstop=4
vimrcadds
cat >> /etc/skel/.vimrc <<vimrcadds
syntax on
set smartindent
set bg=dark
set tabstop=4
vimrcadds

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

#reboot


