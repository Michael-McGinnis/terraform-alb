#!/bin/bash
# Runs on every EC2 instance at boot
# Installs nginx
# Creates HTML page that identifies the host + AZ

# Code will update the package, install nginx, resolves metadata for host and AZ
# Overwrite the default html doc root: cat >/usr/share/nginx/html/index.html <<EOF

yum -y update
yum -y install nginx
HOST=$(hostname)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html>
  <head><title>Hello from ${HOST}</title></head>
  <body style="font-family:sans-serif;text-align:center;">
    <h1>Hello from ${HOST}</h1>
    <p>Availability Zone: <strong>${AZ}</strong></p>
  </body>
</html>
EOF
systemctl enable --now nginx