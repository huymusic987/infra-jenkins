#!/bin/bash
set -e

sudo su -

# === CONFIG ===
GIT_REPO="https://github.com/my-org/infra-jenkins.git"
INSTALL_DIR="/home/ec2-user/infra-jenkins"
JENKINS_HOME="/var/lib/jenkins"
CONFIGS_DIR="$JENKINS_HOME/configs"
GROOVY_DIR="$JENKINS_HOME/init.groovy.d"

# === Install Java 17 + Jenkins ===
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

yum install -y fontconfig java-17-amazon-corretto
yum install -y jenkins git

systemctl daemon-reload
systemctl enable jenkins

# === Clone repo ===
if [ ! -d "$INSTALL_DIR" ]; then
  git clone "$GIT_REPO" "$INSTALL_DIR"
else
  echo "Repo already exists at $INSTALL_DIR."
fi

# === Prepare Jenkins config dirs ===
mkdir -p "$CONFIGS_DIR"
mkdir -p "$GROOVY_DIR"
chown -R jenkins:jenkins "$JENKINS_HOME"

# === Copy configs ===
cp "$INSTALL_DIR/jenkins.yaml" "$CONFIGS_DIR/jenkins.yaml"
cp "$INSTALL_DIR/plugins.txt" "$JENKINS_HOME/plugins.txt"
cp "$INSTALL_DIR/jobs/"*.groovy "$GROOVY_DIR/" || true

sudo chown -R jenkins:jenkins "$JENKINS_HOME"

# === Enable JCasC ===
if ! grep -q "CASC_JENKINS_CONFIG" /etc/sysconfig/jenkins; then
  echo 'JENKINS_JAVA_OPTIONS="$JENKINS_JAVA_OPTIONS -Dcasc.jenkins.config=/var/lib/jenkins/configs/jenkins.yaml"' | sudo tee -a /etc/sysconfig/jenkins
fi

service jenkins start
