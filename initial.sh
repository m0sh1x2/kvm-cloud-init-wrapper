#!/bin/bash
PUBLIC_KEY_PATH=$(cat ~/.ssh/id_rsa.pub)
MACHINE_NAME="test_machine"
USER="ubuntu"
PASS="ubuntu"
IP="192.168.1.245"

qemu-img create -b ./focal-server-cloudimg-amd64.img -f qcow2 -F qcow2 machine-${MACHINE_NAME}.qcow2 35G

# qemu-img info snapshot-bionic-server-cloudimg.qcow2


echo "#cloud-config
hostname: ${MACHINE_NAME}
fqdn: ${MACHINE_NAME}.example.com
manage_etc_hosts: true
users:
  - name: ${USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/${USER}
    shell: /bin/bash
    lock_passwd: false
    ssh-authorized-keys:
      - ${PUBLIC_KEY_PATH}
# only cert auth via ssh (console access can still login)
ssh_pwauth: false
disable_root: false
chpasswd:
  list: |
     ${USER{}:${PASS}
  expire: False

package_update: true
packages:
  - qemu-guest-agent
# written to /var/log/cloud-init-output.log
final_message: \"The system is finally up, after \$UPTIME seconds\"" > cloud_init.cfg


echo "version: 2
ethernets:
  enp1s0:
     dhcp4: false
     # default libvirt network
     addresses: [ ${IP}/24 ]
     gateway4: 192.168.1.1
     nameservers:
       addresses: [ 1.1.1.1,1.0.0.1 ]
       search: [ example.com ]" > network_config_static.cfg


cloud-localds -v --network-config=network_config_static.cfg ${MACHINE_NAME}-seed.img cloud_init.cfg

virt-install --name ${MACHINE_NAME} \
  --virt-type kvm --memory 2048 --vcpus 2 \
  --boot hd,menu=on \
  --disk path=${MACHINE_NAME}-seed.img,device=cdrom \
  --disk path=machine-${MACHINE_NAME}.qcow2,device=disk \
  --os-type Linux --os-variant ubuntu18.04 \
  --network network=host-bridge \
  --graphics vnc,listen=0.0.0.0 --noautoconsole

  --console pty,target_type=serial