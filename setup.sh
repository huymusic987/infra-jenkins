#!/bin/bash
set -e

INSTALL_DIR="/root/infra-jenkins"
JENKINS_HOME="/var/lib/jenkins"
CONFIGS_DIR="$JENKINS_HOME/configs"

echo "=== Installing Java 17 + Jenkins ==="
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

yum update -y
yum install -y fontconfig java-17-amazon-corretto jenkins

echo "Installing Docker"

yum install docker -y

usermod -aG docker jenkins

echo "Starting Docker and Jenkins"

systemctl enable docker

systemctl start docker

echo "=== Preparing Jenkins directories ==="
mkdir -p "$CONFIGS_DIR"
mkdir -p "$JENKINS_HOME/plugins"

chown -R jenkins:jenkins "$JENKINS_HOME"

echo "Installing Jenkins Plugin Manager"
curl -L -o /usr/local/bin/jenkins-plugin-manager-2.13.2.jar \
  https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.2/jenkins-plugin-manager-2.13.2.jar

cat << 'EOF' > /usr/local/bin/jenkins-plugin-cli
#!/bin/bash
exec java -jar /usr/local/bin/jenkins-plugin-manager-2.13.2.jar "$@"
EOF
chmod +x /usr/local/bin/jenkins-plugin-cli

echo "=== Installing plugins BEFORE starting Jenkins ==="
if [ -f "$INSTALL_DIR/plugins.txt" ]; then
    jenkins-plugin-cli \
        --plugin-file "$INSTALL_DIR/plugins.txt" \
        --plugin-download-directory "$JENKINS_HOME/plugins" \
        --war /usr/share/java/jenkins.war \
        --verbose
    
    chown -R jenkins:jenkins "$JENKINS_HOME"
else
    echo "ERROR: plugins.txt not found at $INSTALL_DIR/plugins.txt"
    exit 1
fi

echo "=== Copying configuration files ==="
cp "$INSTALL_DIR/jenkins.yaml" "$CONFIGS_DIR/jenkins.yaml"
chown jenkins:jenkins "$CONFIGS_DIR/jenkins.yaml"

echo "=== Setting up systemd override ==="
mkdir -p /etc/systemd/system/jenkins.service.d/

cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/configs/jenkins.yaml"
EOF

systemctl daemon-reexec
systemctl daemon-reload

systemctl enable jenkins

systemctl start jenkins

echo "Jenkins setup complete"
