#!/bin/bash

function green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

function red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

function install_trojan() {
    # Install Trojan dependencies
    apt-get update
    apt-get install -y nginx

    # Your domain configuration
    green "======================="
    blue "Please enter your domain"
    green "======================="
    read your_domain

    # Install Trojan
    wget https://github.com/trojan-gfw/trojan/releases/latest/download/trojan-1.16.0-linux-amd64.tar.xz
    tar xf trojan-1.16.0-linux-amd64.tar.xz
    mv trojan /usr/local/bin/

    # Nginx configuration
    cat > /etc/nginx/nginx.conf <<-EOF
user  www-data;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  120;
    client_max_body_size 20m;

    server {
        listen 80;
        server_name  $your_domain;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name  $your_domain;

        ssl_certificate /etc/nginx/fullchain.pem;
        ssl_certificate_key /etc/nginx/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384';

        location / {
            proxy_pass http://127.0.0.1:1080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

    systemctl restart nginx
    systemctl enable nginx

    # Configure Trojan
    green "======================="
    blue "Please enter Trojan password"
    green "======================="
    read trojan_passwd

    cat > /etc/trojan/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "0.0.0.0",
    "remote_port": 443,
    "password": ["$trojan_passwd"],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/nginx/fullchain.pem",
        "key": "/etc/nginx/privkey.pem",
        "key_password": "",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": ["http/1.1"],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF

    systemctl restart trojan
    systemctl enable trojan

    green "======================="
    green "Trojan installed and configured successfully!"
    green "======================="
}

# Start installation
install_trojan
