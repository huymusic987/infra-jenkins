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

echo "=== Preparing Jenkins directories ==="
mkdir -p "$CONFIGS_DIR"
mkdir -p "$JENKINS_HOME/plugins"

# Set proper ownership BEFORE starting Jenkins
chown -R jenkins:jenkins "$JENKINS_HOME"

echo "=== Copying configuration files ==="
cp "$INSTALL_DIR/jenkins.yaml" "$CONFIGS_DIR/jenkins.yaml"
chown jenkins:jenkins "$CONFIGS_DIR/jenkins.yaml"

echo "=== Setting up systemd override ==="
mkdir -p /etc/systemd/system/jenkins.service.d/

cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/configs/jenkins.yaml"
EOF

systemctl daemon-reload

echo "=== Installing Jenkins Plugin Manager ==="
curl -L -o /usr/local/bin/jenkins-plugin-manager-2.13.2.jar \
  https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.2/jenkins-plugin-manager-2.13.2.jar

cat << 'EOF' > /usr/local/bin/jenkins-plugin-cli
#!/bin/bash
exec java -jar /usr/local/bin/jenkins-plugin-manager-2.13.2.jar "$@"
EOF
chmod +x /usr/local/bin/jenkins-plugin-cli

echo "=== Installing plugins BEFORE starting Jenkins ==="
if [ -f "$INSTALL_DIR/plugins.txt" ]; then
    # Install plugins to the correct directory with proper ownership
    jenkins-plugin-cli \
        --plugin-file "$INSTALL_DIR/plugins.txt" \
        --plugin-download-directory "$JENKINS_HOME/plugins" \
        --war /usr/share/java/jenkins.war \
        --verbose
    
    # Ensure proper ownership after plugin installation
    chown -R jenkins:jenkins "$JENKINS_HOME"
else
    echo "ERROR: plugins.txt not found at $INSTALL_DIR/plugins.txt"
    exit 1
fi

echo "Installing Docker"

yum install docker -y

usermod -aG docker jenkins

echo "Starting Docker and Jenkins"

systemctl enable docker
systemctl enable jenkins

service docker start
service jenkins start

echo "Jenkins setup complete"