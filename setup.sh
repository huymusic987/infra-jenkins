#!/bin/bash
set -e

INSTALL_DIR="/root/infra-jenkins"
JENKINS_HOME="/var/lib/jenkins"
CONFIGS_DIR="$JENKINS_HOME/configs"

# === Install Java 17 + Jenkins ===
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

yum install -y fontconfig java-17-amazon-corretto
yum install -y jenkins

systemctl daemon-reload
systemctl enable jenkins

mkdir -p /etc/systemd/system/jenkins.service.d/

# Create systemd override to add setup wizard bypass to JAVA_OPTS
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
EOF

systemctl daemon-reload

service jenkins start

sleep 30

# === Prepare Jenkins config dirs ===
mkdir -p "$CONFIGS_DIR"

# === Copy configs ===
cp "$INSTALL_DIR/jenkins.yaml" "$CONFIGS_DIR/jenkins.yaml"

chown -R jenkins:jenkins "$JENKINS_HOME"

# === Enable JCasC ===
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/configs/jenkins.yaml"
EOF

systemctl daemon-reload
service jenkins restart
