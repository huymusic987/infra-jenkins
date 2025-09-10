#!/bin/bash
set -e

INSTALL_DIR="/root/infra-jenkins"
JENKINS_HOME="/var/lib/jenkins"
CONFIGS_DIR="$JENKINS_HOME/configs"

# === Install Java 17 + Jenkins ===
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

yum install -y fontconfig java-17-amazon-corretto jenkins

# === Enable Jenkins service ===
systemctl daemon-reload
systemctl enable jenkins

mkdir -p /etc/systemd/system/jenkins.service.d/

# === Set systemd override for first boot (skip setup wizard + enable JCasC) ===
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/configs/jenkins.yaml"
EOF

systemctl daemon-reload

# === Prepare Jenkins config directory and copy YAML ===
mkdir -p "$CONFIGS_DIR"
cp "$INSTALL_DIR/jenkins.yaml" "$CONFIGS_DIR/jenkins.yaml"

chown -R jenkins:jenkins "$JENKINS_HOME"

# === Download and prepare plugin manager ===
curl -L -o /usr/local/bin/jenkins-plugin-manager-2.13.2.jar \
  https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.2/jenkins-plugin-manager-2.13.2.jar

cat << 'EOF' > /usr/local/bin/jenkins-plugin-cli
#!/bin/bash
exec java -jar /usr/local/bin/jenkins-plugin-manager-2.13.2.jar "$@"
EOF
chmod +x /usr/local/bin/jenkins-plugin-cli

# === Install plugins before starting Jenkins ===
if [ -f "$INSTALL_DIR/plugins.txt" ]; then
    jenkins-plugin-cli --plugin-file "$INSTALL_DIR/plugins.txt" --plugins-directory "$JENKINS_HOME/plugins"
else
    echo "ERROR: plugins.txt not found at $INSTALL_DIR/plugins.txt"
    exit 1
fi

# === Start Jenkins for the first time ===
service jenkins start

# Wait until Jenkins is responsive
echo "Waiting for Jenkins to start..."
until curl -s -f http://localhost:8080 > /dev/null; do
    echo "Waiting..."
    sleep 5
done

echo "Jenkins setup complete! Admin user, plugins, and tools should be configured."
