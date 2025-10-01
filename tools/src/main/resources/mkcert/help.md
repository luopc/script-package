1. 安装 mkcert
   首先确保你已经安装了 mkcert：

<BASH>
# Ubuntu/Debian
sudo apt install libnss3-tools
brew install mkcert  # macOS
# CentOS/RHEL
sudo yum install nss-tools
然后安装本地 CA：

<BASH>
mkcert -install
2. 创建证书
为你的测试域名(如 luopc.com)生成证书：

<BASH>
mkdir -p /opt/public/apps/mkcert
cd /opt/public/apps/mkcert
# 生成证书（支持多个域名和IP）
mkcert luopc.com "*.luopc.com" localhost 127.0.0.1 ::1
这会生成两个文件：

luopc.com+4-key.pem (私钥)
luopc.com+4.pem (证书)
3. 重命名文件为 Nginx 需要的格式
   <BASH>
   mv luopc.com+4-key.pem luopc.com.key
   mv luopc.com+4.pem luopc.com.cert
4. 配置 Nginx 使用这些证书
   在你的 Nginx 配置中添加：

<NGINX>
server {
    listen 443 ssl;
    server_name luopc.com;

    ssl_certificate     /opt/public/apps/mkcert/luopc.com.cert;
    ssl_certificate_key /opt/public/apps/mkcert/luopc.com.key;
    
    # 其他 SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256...';
    ssl_prefer_server_ciphers on;
    
    # 你的其他配置...
}
5. 信任证书(在不同设备上)
   <BASH>
# 查看 CA 证书位置
mkcert -CAROOT
# 将 CA 证书安装到系统信任库
# Windows: 双击 rootCA.pem 安装
# macOS: 双击 rootCA.pem 或使用钥匙串访问
# Linux (Ubuntu):
sudo cp $(mkcert -CAROOT)/rootCA.pem /usr/local/share/ca-certificates/local-root-ca.crt
sudo update-ca-certificates
6. 测试配置
   <BASH>
   sudo nginx -t  # 测试配置
   sudo systemctl restart nginx  # 重启Nginx
7. 浏览器验证
   访问 https://luopc.com 应该能看到绿色的锁标志（表示证书受信任）。

8. 更新证书(可选)
   如果你需要添加更多域名：

<BASH>
mkcert -key-file luopc.com.key -cert-file luopc.com.cert luopc.com new.luopc.com 192.168.1.100
注意事项
mkcert 生成的证书仅适用于开发和测试环境
生产环境请使用 Let's Encrypt 等受信任 CA 颁发的证书
确保证书和私钥文件的权限安全：
<BASH>
chmod 400 /opt/public/apps/mkcert/luopc.com.*
chown root:root /opt/public/apps/mkcert/luopc.com.*
如果你使用 Docker 容器，需要将 CA 证书也挂载到容器中
这样你就有了一个完全功能的 HTTPS 测试环境，所有设备只要安装了 mkcert 的根证书，都会信任这个测试证书。
