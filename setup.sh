#!/bin/bash
set -e

sudo su -

INSTALL_DIR="/root/infra-jenkins"
JENKINS_HOME="/var/lib/jenkins"
CONFIGS_DIR="$JENKINS_HOME/configs"

echo "started"

# === Install Java 17 + Jenkins ===
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

echo "debugging"
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

yum install -y fontconfig java-17-amazon-corretto
yum install -y jenkins

systemctl daemon-reload
systemctl enable jenkins

if ! grep -q "runSetupWizard=false" /etc/sysconfig/jenkins; then
  sed -i 's/JENKINS_JAVA_OPTIONS="/JENKINS_JAVA_OPTIONS="-Djenkins.install.runSetupWizard=false /' /etc/sysconfig/jenkins
fi

service jenkins start

sleep 30

# === Prepare Jenkins config dirs ===
mkdir -p "$CONFIGS_DIR"
chown -R jenkins:jenkins "$JENKINS_HOME"

# === Copy configs ===
cp "$INSTALL_DIR/jenkins.yaml" "$CONFIGS_DIR/jenkins.yaml"
cp "$INSTALL_DIR/plugins.txt" "$JENKINS_HOME/plugins.txt"

sudo chown -R jenkins:jenkins "$JENKINS_HOME"

# === Enable JCasC ===
if ! grep -q "CASC_JENKINS_CONFIG" /etc/sysconfig/jenkins; then
  echo 'JENKINS_JAVA_OPTIONS="$JENKINS_JAVA_OPTIONS -Dcasc.jenkins.config=/var/lib/jenkins/configs/jenkins.yaml"' | sudo tee -a /etc/sysconfig/jenkins
fi
