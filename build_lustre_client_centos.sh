#!/bin/bash

set -ex
shopt -s expand_aliases
# Build Lustre MASTER with ZFS on CentOS7.3 https://wiki.whamcloud.com/pages/viewpage.action?pageId=54428329

#### LOCAL BUILD ENV
### TX2 BUILD
NPROC=8
USER=build
ROOT="/home/$USER"
DIR_HOME="$ROOT/lustre_build"
alias l_make="$MAKE_ENV make -C"  

### CREATEREPO FOR RPMS
DIR_REPO="$ROOT/repo_lustre"
REPO_FILE=/etc/yum.repos.d/lustre_build.repo

#### ZFS SPL BUILD ENV
DIR_ZFS="$DIR_HOME/zfs"
DIR_SPL="$DIR_HOME/zfs"
ZFS_VERSION='0.8.1'
ZFS_BRANCH='0.8.1'
DIR_SPL_SRC=$DIR_ZFS/spl-$ZFS_VERSION
DIR_ZFS_SRC=$DIR_ZFS/zfs-$ZFS_VERSION
ZFS_URL="https://github.com/zfsonlinux/zfs/releases/download/zfs-$ZFS_VERSION/zfs-$ZFS_VERSION.tar.gz"
SPL_URL="https://github.com/zfsonlinux/zfs/releases/download/zfs-$ZFS_VERSION/spl-$ZFS_VERSION.tar.gz"
ZFS_URL="https://github.com/zfsonlinux/zfs/releases/download/zfs-$ZFS_VERSION/zfs-$ZFS_VERSION.tar.gz"
SPL_URL="https://github.com/zfsonlinux/zfs/releases/download/zfs-$ZFS_VERSION/spl-$ZFS_VERSION.tar.gz"

#### E2FSPROGS BUILD ENV
DIR_E2PROGS="$DIR_HOME/e2fsprogs"
DIR_E2PROGS_SRC="$DIR_E2PROGS/e2fsprogs"
E2FSPROGS_PACKAGING_URL="http://archive.ubuntu.com/ubuntu/pool/main/e/e2fsprogs/e2fsprogs_1.44.6-1.debian.tar.xz"
DIR_RPMBUILD="$ROOT/rpmbuild/RPMS/aarch64/"

#### LUSTRE BUILD ENV
DIR_LUSTRE="$DIR_HOME/lustre"
DIR_LUSTRE_SRC="$DIR_LUSTRE/lustrearm"
LUSTRE_BRANCH="master"


#### BUILD
DIR_KERNEL="/usr/src/kernels/$(uname -r)/"

mkdir -p $DIR_HOME
mkdir -p $DIR_REPO
mkdir -p $DIR_ZFS_SRC
mkdir -p $DIR_SPL_SRC
mkdir -p $DIR_E2PROGS_SRC
mkdir -p $DIR_LUSTRE_SRC

### FUNCTIONS
function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    echo "$@ not installed"
    false
  fi
}

######
# Kernel sources !
# Better kernel sources : http://lxsoft101.cern.ch/centos-debuginfo/7/aarch64/
# For kernel 4.14.0-115.10.1
# wget http://lxsoft101.cern.ch/centos-debuginfo/7/aarch64/kernel-debuginfo-4.14.0-115.10.1.el7a.aarch64.rpm
# wget http://lxsoft101.cern.ch/centos-debuginfo/7/aarch64/kernel-debuginfo-common-4.14.0-115.10.1.el7a.aarch64.rpm
# NOTE : It seems wget http://lxsoft101.cern.ch/centos-debuginfo/7/aarch64/kernel-debuginfo-$(uname -a).rpm should work


sudo yum -y install "@Development Tools"
sudo yum -y install xmlto asciidoc elfutils-libelf-devel zlib-devel binutils-devel newt-devel python-devel \
			hmaccalc perl-ExtUtils-Embed bison elfutils-devel audit-libs-devel kernel-devel \
			libattr-devel libuuid-devel libblkid-devel libselinux-devel libudev-devel \
			pesign numactl-devel pciutils-devel ncurses-devel libselinux-devel fio \
			zlib-devel libuuid-devel libattr-devel libblkid-devel libselinux-devel libudev-devel \
			parted lsscsi ksh openssl-devel elfutils-libelf-devel createrepo \
			vim wget libaio-devel redhat-lsb-core lsof texinfo

# Python 3 is in epel...
sudo yum -y --exclude=kernel* install epel-release
sudo yum -y --exclude=kernel* install --enablerepo=epel python36 python36-devel python36-setuptools python36-cffi libyaml-devel libyaml libtool

sudo yum -y --exclude=kernel* install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/aarch64/ohpc-release-1.3-1.el7.aarch64.rpm || true 

# We need to reload bash for lmod to be picked up (Ansible task...)
# WIP: So this will fail the first time, and you'll have to relaunch the script
# Couldn't find doc on how to do build-ids...
sudo sed -i 's/%{?_missing_build_ids_terminate_build:--strict-build-id}//g' /usr/lib/rpm/macros

# Build SPL KMOD
if ! isinstalled 'spl'; then
	echo "SPL : SKIPPING BUILD"
else

	cd $DIR_SPL_SRC
	sh "$DIR_SPL_SRC/autogen.sh" \
		&& $DIR_SPL_SRC/configure --with-spec=redhat --with-linux=$DIR_KERNEL \
		&& l_make $DIR_SPL_SRC -s -j $NPROC \
		&& l_make $DIR_SPL_SRC -j1 pkg-utils \
		&& l_make $DIR_SPL_SRC -j1 pkg-kmod rpms

	mv $DIR_SPL_SRC/*.rpm $DIR_REPO/
	sudo createrepo $DIR_REPO

	if [ ! -f $REPO_FILE ]; then
		echo "[lustre_repo]" | sudo tee $REPO_FILE
		echo "name=LustreRepo" | sudo tee -a $REPO_FILE
		echo "baseurl=file://$DIR_REPO" | sudo tee -a $REPO_FILE
		echo "enabled=1" | sudo tee -a $REPO_FILE
		echo "gpgcheck=0" | sudo tee -a $REPO_FILE
	fi

	sudo yum clean all
	sudo yum update --exclude=kernel* -y || true
	sudo yum -y --exclude=kernel* install spl kmod-spl-devel
	##for file in $DIR_SPL_SRC/*.deb; do sudo gdebi -q --non-interactive $file; done
fi

if ! isinstalled 'zfs'; then
	echo "ZFS : SKIPPING BUILD"
else
	# If you have a "debug kernel", it won't accept CDDL
	sudo sed -i 's/CDDL/GPL/g' $DIR_ZFS_SRC/META

	# BUILD ZFS KMOD
	cd $DIR_ZFS_SRC
	sh "$DIR_ZFS_SRC/autogen.sh" \
		&& $DIR_ZFS_SRC/configure --with-spec=redhat --with-linux=$DIR_KERNEL --with-spl=$DIR_SPL_SRC \
		&& l_make $DIR_ZFS_SRC -s -j $NPROC \
		&& l_make $DIR_ZFS_SRC -j1 pkg-utils \
		&& l_make $DIR_ZFS_SRC -j1 pkg-kmod rpms

	mv $DIR_ZFS_SRC/*.rpm $DIR_REPO/
	sudo createrepo $DIR_REPO
	sudo yum clean all
	sudo yum update --exclude=kernel* -y || true
	sudo yum -y --exclude=kernel* install zfs kmod-zfs-devel
	##for file in $DIR_ZFS_SRC/*.deb; do sudo gdebi -q --non-interactive $file; done
fi



if isinstalled 'e2fsprogs'; then
	echo "E2FSPROGS INSTALLED : SKIPPING BUILD"
else
	# Build e2fsprogs

	git clone -b master-lustre git://git.whamcloud.com/tools/e2fsprogs.git $DIR_E2PROGS_SRC || true

	# Get packaging
	wget -P $DIR_E2PROGS $E2FSPROGS_PACKAGING_URL
	tar --exclude "debian/changelog" -xf "$DIR_E2PROGS/$(basename $E2FSPROGS_PACKAGING_URL)"

	# e2fsprogs lustre hack
	sed -i 's/ext2_types-wrapper.h$//g' $DIR_E2PROGS_SRC/lib/ext2fs/Makefile.in

	cd $DIR_E2PROGS_SRC
	sh $DIR_E2PROGS_SRC/configure \
		&& l_make $DIR_E2PROGS_SRC rpm
	#	&& dpkg-buildpackage -b -us -uc 

	# Install e2fsprogs packages
	mv $DIR_RPMBUILD/*.rpm $DIR_REPO/
	sudo createrepo $DIR_REPO
	sudo yum clean all
	sudo yum update --exclude=kernel* -y || true
	sudo yum -y --exclude=kernel* --disabelrepo='*' --enablerepo='lustre_repo' install e2fsprogs

fi

# Get Lustre source
git clone -b $LUSTRE_BRANCH git://git.whamcloud.com/fs/lustre-release.git $DIR_LUSTRE_SRC || true

# Build Lustre-client
cd $DIR_LUSTRE_SRC
sh "$DIR_LUSTRE_SRC/autogen.sh" \
	&& $DIR_LUSTRE_SRC/configure --disable-server \
	&& l_make $DIR_LUSTRE_SRC rpms -j $NPROC

# Build Lustre-server with ZFS and LDISKFS Support

#cd $DIR_LUSTRE_SRC
#sh "$DIR_LUSTRE_SRC/autogen.sh" \
#	&& $DIR_LUSTRE_SRC/configure --enable-server --enable-modules \
#  		--with-zfs="$DIR_ZFS_SRC" \
#		--enable-ldiskfs \
#       	&& l_make $DIR_LUSTRE_SRC rpms -j $NPROC

echo "###########LUSTRE BUILT#################"

mv $DIR_LUSTRE_SRC/*.rpm $DIR_REPO/
sudo createrepo $DIR_REPO
sudo yum clean all
sudo yum update --exclude=kernel* -y || true

# TODO: Tests
# For ZFS: //tests/zfs-test.sh -vx (takes two hours to run)
# For Lustre : FSTYPE=zfs //llmount.sh and llmountcleanup.sh going through is the first step (but needs multiple disk/block devices)
