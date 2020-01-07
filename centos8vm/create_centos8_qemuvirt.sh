#!/usr/bin/bash

yum install -y wget vim "@Development Tools" tk tcsh gcc-gfortran lsof python36-devel kernel-rpm-macros pciutils python36 createrepo libvirt qemu-kvm virt-install python2 AAVMF -y
systemctl enable libvirtd
systemctl start libvirtd

fallocate -l 45G /var/lib/libvirt/images/"$name".qcow2
fallocate -l 15G /var/lib/libvirt/images/"$name"ost.qcow2
qemu-img create -f qcow2 /var/lib/libvirt/images/"$name"ost.qcow2 45G
qemu-img create -f qcow2 /var/lib/libvirt/images/"$name".qcow2 15G

num="1"
vf=$(($num+1)) #num+1
name="centos8$(hostname)$num"
ib_if="ib$((16-$num))"
pci_address=$(ethtool -i ${ib_if} | awk '{if(/bus-info: 0000:/) print $2}' | sed 's/0000://g')
virt-install -d \
	--name $name \
	--ram 32768 \
	--disk path=/var/lib/libvirt/images/"$name".qcow2,size=45 \
	--disk path=/var/lib/libvirt/images/"$name"ost.qcow2,size=15 \
	--host-device ${pci_address},driver_name="vfio",address.type="pci" \
	--vcpus 16 \
	--os-type linux \
	--os-variant "rhel8.0" \
	--network type=direct,source=enp1s0f0,source_mode=bridge,model=virtio \
	--console pty \
	--location 'http://mirrors.coreix.net/centos/8/BaseOS/aarch64/os/'  \
	--extra-args "ks=http://10.40.0.11:5000/preseed/32" \
	--noautoconsole --force \
#	--boot uefi,loader=/usr/share/AAVMF/AAVMF_CODE.verbose.fd,loader_ro=yes,loader_type=pflash,nvram_template=/usr/share/AAVMF/AAVMF_VARS.fd \
