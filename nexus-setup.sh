#!/bin/bash
# hello this is for Nexus Repo Setup 
# Set Variables
NEXUS_VERSION="3.77.2-02"
NEXUS_USER="nexus"
NEXUS_HOME="/opt/nexus"
NEXUS_DATA="/opt/sonatype-work"
NEXUS_TAR_URL="https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz"
NEXUS_DIR="/opt/nexus-${NEXUS_VERSION}"
NEXUS_SERVICE="/etc/systemd/system/nexus.service"

POSTGRES_USER="nexus"
POSTGRES_DB="nexusdb"
POSTGRES_PASSWORD="Nexus@123"  # Change this to a strong password

# Step 1: Update system
echo "Updating system packages..."
dnf update -y

# Step 2: Install Java 17
echo "Installing OpenJDK 17..."
dnf install -y java-17-openjdk

# Step 3: Install PostgreSQL
echo "Installing PostgreSQL..."
dnf install -y postgresql-server postgresql-contrib

# Step 4: Initialize PostgreSQL and start the service
echo "Initializing PostgreSQL..."
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# Step 5: Create PostgreSQL database and user for Nexus
echo "Configuring PostgreSQL database..."
sudo -i -u postgres psql <<EOF
CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER;
ALTER ROLE $POSTGRES_USER SET client_encoding TO 'utf8';
ALTER ROLE $POSTGRES_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $POSTGRES_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
EOF

# Step 6: Create Nexus user
echo "Creating Nexus user..."
useradd -r -d $NEXUS_HOME -s /bin/bash $NEXUS_USER

# Step 7: Download and Extract Nexus
echo "Downloading Nexus Repository Manager..."
curl -o /tmp/nexus.tar.gz -L $NEXUS_TAR_URL

echo "Extracting Nexus..."
tar -xvf /tmp/nexus.tar.gz -C /opt/
mv $NEXUS_DIR $NEXUS_HOME

# Step 8: Set Permissions
echo "Setting permissions..."
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_HOME
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_DATA

# Step 9: Configure Nexus to use PostgreSQL
echo "Configuring Nexus to use PostgreSQL..."
cat <<EOF > $NEXUS_HOME/etc/nexus.properties
# Nexus Repository Configuration
nexus.datastore.enabled=true
nexus.datastore.type=jdbc
nexus.jdbc.driver=org.postgresql.Driver
nexus.jdbc.url=jdbc:postgresql://localhost:5432/$POSTGRES_DB
nexus.jdbc.username=$POSTGRES_USER
nexus.jdbc.password=$POSTGRES_PASSWORD
EOF

# Step 10: Enable Nexus to run as a service
echo "Creating Nexus systemd service..."
cat <<EOF > $NEXUS_SERVICE
[Unit]
Description=Nexus Repository Manager
After=network.target postgresql.service

[Service]
Type=forking
User=$NEXUS_USER
Group=$NEXUS_USER
ExecStart=$NEXUS_HOME/bin/nexus start
ExecStop=$NEXUS_HOME/bin/nexus stop
Restart=on-abort
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Step 11: Allow nexus user to run Nexus
echo "Setting run permissions..."
echo 'run_as_user="nexus"' > $NEXUS_HOME/bin/nexus.rc
chown nexus:nexus $NEXUS_HOME/bin/nexus.rc

# Step 12: Configure Firewall Rules
echo "Configuring firewall to allow Nexus (port 8081)..."
firewall-cmd --permanent --add-port=8081/tcp
firewall-cmd --reload

# Step 13: Reload systemd, start and enable Nexus service
echo "Starting Nexus service..."
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus

echo "Nexus Repository Manager installation and PostgreSQL configuration completed!"
echo "Access Nexus at: http://$(hostname -I | awk '{print $1}'):8081"
echo "PostgreSQL Credentials - User: $POSTGRES_USER, Database: $POSTGRES_DB"
