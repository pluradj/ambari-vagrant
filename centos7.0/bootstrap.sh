#!/usr/bin/env bash

cp /vagrant/hosts /etc/hosts
cp /vagrant/resolv.conf /etc/resolv.conf
yum install ntp -y
sed -i 's/centos.pool.ntp.org/us.pool.ntp.org/g' /etc/ntp.conf
service ntpd start
chkconfig ntpd on
mkdir -p /root/.ssh; chmod 600 /root/.ssh; cp /home/vagrant/.ssh/authorized_keys /root/.ssh/

# Increasing swap space
sudo dd if=/dev/zero of=/swapfile bs=1024 count=1024k
sudo mkswap /swapfile
echo 10 | sudo tee /proc/sys/vm/swappiness
echo vm.swappiness = 10 | sudo tee -a /etc/sysctl.conf
sudo chown root:root /swapfile
sudo chmod 600 /swapfile
sudo swapon /swapfile
echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab

sudo cp /vagrant/insecure_private_key /root/ec2-keypair
sudo chmod 600 /root/ec2-keypair

# Workaround from https://www.digitalocean.com/community/questions/can-t-install-mysql-on-centos-7
#rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm

yum install wget curl git unzip zip vim -y
