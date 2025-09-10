#!/bin/bash
set -e

echo "tmpfs /tmp tmpfs defaults,size=3G 0 0" | sudo tee -a /etc/fstab

mount -o remount /tmp

yum update -y
yum install -y git

git clone https://github.com/huymusic987/infra-jenkins.git

chmod +x infra-jenkins/setup.sh

./infra-jenkins/setup.sh

