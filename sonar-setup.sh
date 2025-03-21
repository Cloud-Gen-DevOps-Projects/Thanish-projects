#!/bin/bash

# Step 1: Update system
echo "Updating system packages..."
sudo apt-get update -y

# Step 2: Install Docker
echo "Installing Docker..."
sudo apt-get install docker.io -y

# Step 3: Add current user to the Docker group
echo "Adding user to Docker group..."
sudo usermod -aG docker $(whoami)

# Step 4: Apply group changes
echo "Applying new group permissions..."
newgrp docker

# Step 5: Set permissions for Docker socket
# this one use for to give the permission to execute the task in jenkins to job befoe build the docker image. we must have this to build and execute job successfully in jenkins.
echo "Changing Docker socket permissions..."
sudo chmod 777 /var/run/docker.sock

# Step 6: Pull and Run SonarQube container
echo "Pulling and running SonarQube LTS Community Edition..."
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

# Step 7: Verify SonarQube container is running
echo "Checking running Docker containers..."
docker ps

echo "SonarQube is running! Access it at: http://$(hostname -I | awk '{print $1}'):9000"
