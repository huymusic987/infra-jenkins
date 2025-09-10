#!/bin/bash
set -e

yum update -y
yum install -y git

git clone https://github.com/huymusic987/infra-jenkins.git

chmod +x infra-jenkins/setup.sh

./infra-jenkins/setup.sh

