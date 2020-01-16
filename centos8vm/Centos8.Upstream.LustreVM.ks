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
wget
lvm2

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

{% for name, key in users.items() %}{% if "lustreclusterprivate" not in name|string %}
printf "{{key}}\n" >> /root/.ssh/authorized_keys ;
{% endif %}{% endfor %}

### Display IP on login
echo "My IP address: \4" > /etc/issue

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### LUSTRE : Install cluster private key
{% for name, key in users.items() %}{% if "lustreclusterprivate" in name|string %}
printf "{{key}}\n" >> /root/.ssh/lustrecluster ;
{% endif %}{% endfor %}
chmod 0600 /root/.ssh/lustrecluster

### LUSTRE : Install compatible kernel
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-core-4.18.0-80.11.2.el8.aarch64.rpm 
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-cross-headers-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-devel-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-headers-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-modules-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-modules-extra-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-tools-libs-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/kernel-tools-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/perf-4.18.0-80.11.2.el8.aarch64.rpm 
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/python3-perf-4.18.0-80.11.2.el8.aarch64.rpm
rpm -ivh --oldpackage http://10.40.0.13/lustre_deps/linux/Packages/bpftool-4.18.0-80.11.2.el8.aarch64.rpm
# And exclude kernel from upgrades
echo "exclude=kernel*" >> /etc/yum.conf

### LUSTRE : Install dependencies for build
yum install --enablerepo="PowerTools" -y audit-libs-devel binutils-devel elfutils-devel java-devel kabi-dw ncurses-devel newt-devel numactl-devel openssl-devel pciutils-devel perl-devel python3-devel python3-docutils xmlto xz-devel zlib-devel perl-ExtUtils-Embed readline-devel bc net-tools

### LUSTRE : Disable SELinux
sed -i "s/enforcing/disabled/g" /etc/selinux/config

### LUSTRE : Create runas user with IDs 500:500
groupadd -g 500 runas
useradd -g 500 -m -u 500 runas

### LUSTRE : Create builder user and passwordless sudo
sed -i "s/%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
useradd -m builder
usermod -a -G wheel builder

### LUSTRE : Add rpm dependencies repo
cat << EOF > /etc/yum.repos.d/lustre_deps.repo
[lustre_deps_repo]
name=Lustre Dependencies repo
baseurl=http://10.40.0.13/lustre_deps/repo/
enabled=1
gpgcheck=0
EOF

### LUSTRE : Add e2fsprogs and lustre repo
### NOTE: You still need to manually wget and rpm -ivh --nodeps the kmods...

cat << EOF > /etc/yum.repos.d/lustre.repo
[lustre_repo]
name=Lustre repo
baseurl=http://10.40.0.13/lustre/latest/
enabled=1
gpgcheck=0
EOF

yum update -y
## NOTE : This update should update e2fsprogs, so if it is a bad build...

### LUSTRE : Install pdsh
yum install -y pdsh pdsh-rcmd-ssh

### LUSTRE : Disable all network control
systemctl disable firewalld
systemctl stop firewalld

### LUSTRE : Fetch kernel sources for build
wget -P /home/builder/ http://10.40.0.13/lustre_deps/linux/kernel-latest_SOURCES.tar.gz
cd /home/builder && tar xf kernel-latest_SOURCES.tar.gz


%end
