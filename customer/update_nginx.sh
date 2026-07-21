cat > /etc/nginx/sites-enabled/delivery << 'NGINX'
server {
    listen 80;
    server_name _;
    client_max_body_size 100M;

    location /privacy/ {
        alias /root/delivery-server/privacy/;
        add_header Access-Control-Allow-Origin *;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location /admin {
        alias /root/delivery-server/admin;
        try_files $uri $uri/ /admin/index.html;
    }
}
NGINX
nginx -t && systemctl reload nginx