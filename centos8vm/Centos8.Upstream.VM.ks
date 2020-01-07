# Required Kernel options to install ERP CentOS7 build: 
# ip=dhcp text inst.stage2=http://mirrors.coreix.net/centos/8/BaseOS/aarch64/os/ inst.repo=http://mirrors.coreix.net/centos/8/BaseOS/aarch64/os/ earlycon
# Use network installation
url --url="http://mirrors.coreix.net/centos/8/BaseOS/aarch64/os/"
repo --name="upstream" --baseurl="http://mirrors.coreix.net/centos/8/BaseOS/aarch64/os/"
# Use text mode install
text
# Do not configure the X Window System
skipx

# Keyboard layouts
keyboard --vckeymap=us --xlayouts=''
# System language
lang en_US.UTF-8
# System timezone
timezone Europe/London
# Root password
rootpw --iscrypted !!

# Network information
network --bootproto=dhcp
%include "/tmp/hostname.ks"

# System services
services --enabled="chronyd"

# Install to sda.
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
ignoredisk --only-use=sda
autopart --type=plain
clearpart --all --initlabel --drives=sda


# Reboot after installation
reboot

%packages
@core
@Development Tools
chrony
kexec-tools
git
vim

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
%pre
#!/bin/sh

echo “network -–hostname={{ hostname }}” > /tmp/hostname.ks
for x in `cat /proc/cmdline`; do
        case $x in SERVERNAME*)
               eval $x
        	   echo "network --hostname=$SERVERNAME" > /tmp/hostname.ks
               ;;
            esac;
done
%end
%post
#---- Install our SSH key ----
mkdir -m0700 /root/.ssh/
yum update -y

{% for key in ssh_keys %}
printf "{{key}}\n" >> /root/.ssh/authorized_keys ;
{% endfor %}

### Display IP on login
echo "My IP address: \4" > /etc/issue

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
#restorecon -R /root/.ssh/

# Add apt-cacher-ng to conf
#echo "proxy=http://10.40.0.13:3142" >> /etc/yum.conf
%end
