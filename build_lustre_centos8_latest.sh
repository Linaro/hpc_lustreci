#!/bin/bash

set -ex
shopt -s expand_aliases
# Build Lustre MASTER with ZFS on CentOS7.3 https://wiki.whamcloud.com/pages/viewpage.action?pageId=54428329

#### LOCAL BUILD ENV
### TX2 BUILD
NPROC=12
USER=bgerdeb
ROOT="/home/$USER"
DIR_HOME="$ROOT/lustre_build"
alias l_make="$MAKE_ENV make -C"  

### CREATEREPO FOR RPMS
DIR_REPO="$ROOT/repo_lustre"
REPO_FILE=/etc/yum.repos.d/lustre_build.repo

#### ZFS SPL BUILD ENV
DIR_ZFS="$DIR_HOME/zfs"
DIR_SPL="$DIR_HOME/zfs"
ZFS_VERSION='0.8.2'
ZFS_BRANCH='0.8.2'
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
DIR_RPMBUILD="/home/bgerdeb/rpmbuild/RPMS/aarch64/"

#### LUSTRE BUILD ENV
DIR_LUSTRE="$DIR_HOME/lustre"
DIR_LUSTRE_SRC="$DIR_LUSTRE/lustrearm"
LUSTRE_BRANCH="lustre-arm"


#### BUILD
DIR_KERNEL="/home/bgerdeb/rpmbuild/BUILD/kernel-4.18.0-80.11.2.el8_0/linux-4.18.0-80.11.2.el8.aarch64/"

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
# For CentOS 8 srpms seem slow to be uploaded... But sources (i.e linux tarball, kabi stuff) looks the same as RHEL8's, so reused those.
# Linaro HPC SIG has a SRPM of the latest kernel on the hpc-fileserver

sudo yum config-manager --set-enabled PowerTools
sudo yum -y install "@Development Tools"
sudo yum -y install kernel-abi-whitelists
sudo yum -y install xmlto asciidoc elfutils-libelf-devel zlib-devel binutils-devel newt-devel python3-devel \
			hmaccalc perl-ExtUtils-Embed bison elfutils-devel audit-libs-devel kernel-devel \
			libattr-devel libuuid-devel libblkid-devel libselinux-devel libudev-devel \
			pesign numactl-devel pciutils-devel ncurses-devel libselinux-devel fio \
			zlib-devel libuuid-devel libattr-devel libblkid-devel libselinux-devel libudev-devel \
			parted lsscsi ksh openssl-devel elfutils-libelf-devel createrepo \
			vim wget libaio-devel redhat-lsb-core kernel-rpm-macros \
			texinfo libyaml-devel libffi-devel libtirpc-devel lua tcl lua-json


sudo yum -y install --enablerepo="PowerTools" python3 python3-devel python3-setuptools python3-cffi libyaml-devel libyaml libtool

#sudo yum -y --exclude=kernel* install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/aarch64/ohpc-release-1.3-1.el7.aarch64.rpm || true 
#sudo yum -y update
#sudo yum -y install Lmod

# CentOS 8 cannot cope with ; 
#BuildRequires: %kernel_module_package_buildreqs
sed -i 's/BuildRequires: %kernel_module_package_buildreqs/#BuildRequires: %kernel_module_package_buildreqs/g' $DIR_ZFS_SRC/rpm/redhat/zfs-kmod.spec.in

# Couldn't find doc on how to do build-ids...
sudo sed -i 's/%{?_missing_build_ids_terminate_build:--strict-build-id}//g' /usr/lib/rpm/macros

## Build ZFS (and SPL :( ) upstream only.
if [[ ! -f "$DIR_ZFS/$(basename $ZFS_URL)" ]] ; then
	wget -P $DIR_ZFS/ $ZFS_URL

	tar -C $DIR_ZFS -xzf $DIR_ZFS/$(basename $ZFS_URL)
fi
# NO SPL ON RHEL8
# BUILD ZFS DKMS
#cd $DIR_ZFS_SRC
#sh "$DIR_ZFS_SRC/autogen.sh" \
#	&& $DIR_ZFS_SRC/configure --with-config=user --with-linux=$DIR_KERNEL --with-spl=$DIR_SPL_SRC \
#	&& l_make $DIR_ZFS_SRC -s -j $NPROC \
#	&& l_make $DIR_ZFS_SRC rpm \
#
# Install ZFS DKMS
#mv $DIR_ZFS_SRC/*.rpm $DIR_REPO/
##for file in $DIR_ZFS_SRC/*.deb; do sudo gdebi -q --non-interactive $file; mv $file $DIR_REPO/ ; done

#### TODO: INSERT TESTS HERE

#l_make $DIR_SPL_SRC clean || true
#l_make $DIR_ZFS_SRC clean || true

if isinstalled 'zfs'; then
	echo "ZFS INSTALLED : SKIPPING BUILD"
else
	# If you have a "debug kernel", it won't accept CDDL
	sudo sed -i 's/CDDL/GPL/g' $DIR_ZFS_SRC/META

	cd $DIR_ZFS_SRC
	sh "$DIR_ZFS_SRC/autogen.sh" \
		&& $DIR_ZFS_SRC/configure --with-spec=redhat --with-linux=$DIR_KERNEL \
		&& l_make $DIR_ZFS_SRC -s -j $NPROC \
		&& l_make $DIR_ZFS_SRC -j1 pkg-utils \
		&& l_make $DIR_ZFS_SRC -j1 pkg-kmod rpms

	mv $DIR_ZFS_SRC/*.rpm $DIR_REPO/
	sudo createrepo $DIR_REPO
	sudo yum clean all
	sudo yum update -y || true
	sudo yum -y install zfs kmod-zfs-devel
	##for file in $DIR_ZFS_SRC/*.deb; do sudo gdebi -q --non-interactive $file; done
fi



if isinstalled 'e2fsprogs'; then
	echo "E2FSPROGS INSTALLED : SKIPPING BUILD"
else
	# Build e2fsprogs

	git clone -b master-lustre git://git.whamcloud.com/tools/e2fsprogs.git $DIR_E2PROGS_SRC

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
	sudo yum update -y || true
	sudo yum -y --enablerepo='lustre_repo' install e2fsprogs

fi
# for file in $DIR_E2PROGS/*.deb; do sudo gdebi -q --non-interactive $file; done

# Get Lustre source
#git clone -b $LUSTRE_BRANCH git://git.whamcloud.com/fs/lustre-release.git $DIR_LUSTRE_SRC || true
#git --git-dir $DIR_LUSTRE_SRC reset --hard && git --git-dir $DIR_LUSTRE_SRC clean -dfx || true

# Build Lustre-client
if isinstalled 'lustre-client-tests'; then
	echo "LUSTRE CLIENT TESTS INSTALLED: SKIPPING BUILD"
else
	cd $DIR_LUSTRE_SRC
	sh "$DIR_LUSTRE_SRC/autogen.sh" \
		&& $DIR_LUSTRE_SRC/configure --disable-server \
		&& l_make $DIR_LUSTRE_SRC rpms -j $NPROC
fi
#git --git-dir $DIR_LUSTRE_SRC reset --hard && git --git-dir $DIR_LUSTRE_SRC clean -dfx || true

# Build Lustre-server with ZFS and LDISKFS Support

# CentOS 8 cannot cope with ; 
#BuildRequires: %kernel_module_package_buildreqs
sed -i 's/BuildRequires: %kernel_module_package_buildreqs/#BuildRequires: %kernel_module_package_buildreqs/g' $DIR_LUSTRE_SRC/lustre.spec.in

cd $DIR_LUSTRE_SRC
sh "$DIR_LUSTRE_SRC/autogen.sh" \
	&& $DIR_LUSTRE_SRC/configure --enable-server --enable-modules \
		--enable-ldiskfs \
  		--with-zfs="$DIR_ZFS_SRC" \
		--with-linux="$DIR_KERNEL" \
       	&& l_make $DIR_LUSTRE_SRC rpms -j $NPROC

echo "###########LUSTRE BUILT#################"

mv $DIR_LUSTRE_SRC/*.rpm $DIR_REPO/
sudo createrepo $DIR_REPO
sudo yum clean all
sudo yum update -y || true

# TODO: Tests
# For ZFS: //tests/zfs-test.sh -vx (takes two hours to run)
# For Lustre : FSTYPE=zfs //llmount.sh and llmountcleanup.sh going through is the first step (but needs multiple disk/block devices)
