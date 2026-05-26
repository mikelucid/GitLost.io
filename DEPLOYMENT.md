# gitlost.io Production Deployment Guide

## Overview

This guide covers the production-ready deployment of **gitlost.io** on AWS EC2. The improved deployment script includes:

- ✅ Modular bash functions with error handling
- ✅ Comprehensive logging with timestamps
- ✅ Security hardening (headers, CSP, rate limiting)
- ✅ Separated HTML, CSS, and JavaScript assets
- ✅ nginx optimization (compression, caching, CDN-ready)
- ✅ Log rotation and CloudWatch integration
- ✅ Accessibility improvements (ARIA labels, focus states)
- ✅ Progressive Web App (PWA) support

## Prerequisites

- AWS EC2 instance running **Amazon Linux 2** or **RHEL 8/9**
- Instance type: `t3.micro` or higher
- Root or sudo access
- Security group allows HTTP (port 80) and optionally HTTPS (port 443)

## Quick Deploy

### 1. Launch EC2 Instance

```bash
# Using AWS CLI
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --security-groups default \
  --user-data file://deploy/deploy.sh \
  --region us-east-1
```

Or manually in AWS Console:
- **AMI**: Amazon Linux 2 (free tier eligible)
- **Instance Type**: t3.micro
- **User Data**: Copy entire `deploy/deploy.sh` script

### 2. Access Your Deployment

```bash
# Get the public IP from AWS Console or CLI
aws ec2 describe-instances --instance-ids i-xxxxx --query 'Reservations[0].Instances[0].PublicIpAddress'

# Visit in browser
http://<PUBLIC_IP>
```

## Deployment Checklist

### Before Deployment
- [ ] EC2 instance is running
- [ ] Security group allows HTTP inbound (0.0.0.0/0)
- [ ] IAM instance profile has CloudWatch logs permissions (optional)
- [ ] Domain name is ready (if using custom domain)

### During Deployment
- Script will output to `/var/log/gitlost.io/deploy.log`
- Monitor first run: `ssh ec2-user@<IP> -c "tail -f /var/log/gitlost.io/deploy.log"`

### After Deployment
- [ ] Visit `http://<PUBLIC_IP>/health.html` → should return "gitlost.io is alive"
- [ ] Check nginx is running: `systemctl status nginx`
- [ ] Verify logs: `tail -20 /var/log/gitlost.io/access.log`
- [ ] Test functionality: click "seek lost commits" button

## Configuration

### Directory Structure

```
/var/www/gitlost.io/
├── index.html              # Main HTML
├── health.html             # Health check endpoint
├── manifest.json           # PWA manifest
├── robots.txt             # SEO/crawler rules
├── sitemap.xml            # Site map
└── static/
    ├── app.js             # Application logic
    └── styles.css         # Styling

/etc/gitlost.io/
├── deployment.info        # Deployment metadata
└── (future config files)

/var/log/gitlost.io/
├── access.log             # nginx access logs
├── error.log              # nginx error logs
└── deploy.log             # Deployment log
```

### nginx Configuration

The script creates `/etc/nginx/conf.d/gitlost.io.conf` with:

#### Security Headers
```nginx
X-Content-Type-Options: nosniff        # Prevent MIME-type sniffing
X-Frame-Options: DENY                  # Prevent clickjacking
X-XSS-Protection: 1; mode=block        # Legacy XSS protection
Content-Security-Policy: ...           # Prevent script injection
Permissions-Policy: ...                # Disable sensors/camera/mic
```

#### Performance
- **Gzip compression** for text/JS/CSS
- **Cache headers** for static assets (30 days)
- **Rate limiting**:
  - General: 30 req/s per IP
  - Seek API: 10 req/s per IP

#### Static Files
```nginx
location ~* \.(js|css|png|jpg|gif|svg)$ {
    expires 30d;  # Browser caches for 30 days
}
```

## Customization

### Change Web Root

Edit deployment script:
```bash
WEB_ROOT="/var/www/custom-path"
```

### Modify Reward Messages

Edit `deploy/deploy.sh` → search `rewardMessages` array, or edit `/var/www/gitlost.io/static/app.js` post-deployment.

### Add HTTPS/TLS

After deployment:
```bash
sudo certbot --nginx -d yourdomain.com
```

The script includes `certbot` pre-installed for easy setup.

### Enable CloudWatch Logs

The script auto-configures CloudWatch if the agent is installed. To install agent:

```bash
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
```

## Monitoring & Maintenance

### View Logs

```bash
# Deployment log
sudo tail -f /var/log/gitlost.io/deploy.log

# nginx access
sudo tail -f /var/log/gitlost.io/access.log

# nginx errors
sudo tail -f /var/log/gitlost.io/error.log
```

### Check Service Status

```bash
# nginx status
sudo systemctl status nginx

# nginx reload (no downtime)
sudo systemctl reload nginx

# nginx restart
sudo systemctl restart nginx
```

### Test nginx Configuration

```bash
sudo nginx -t
```

### Log Rotation

Configured automatically via `/etc/logrotate.d/gitlost.io`:
- Rotates daily
- Keeps 14 days of logs
- Compresses old logs
- Auto-reloads nginx after rotation

### Performance Monitoring

```bash
# Monitor real-time traffic
sudo tail -f /var/log/gitlost.io/access.log | grep -E "seek|health|static"

# Count requests by endpoint
sudo cat /var/log/gitlost.io/access.log | awk '{print $7}' | sort | uniq -c

# Find slow requests (>1s)
sudo awk '$NF>1000 {print}' /var/log/gitlost.io/access.log
```

## Troubleshooting

### "Connection refused" when visiting IP

1. Verify EC2 instance is running
2. Check security group allows HTTP (port 80)
3. Verify nginx started: `sudo systemctl status nginx`
4. Check nginx logs: `sudo tail -20 /var/log/gitlost.io/error.log`

### nginx fails to start

```bash
# Validate config
sudo nginx -t

# Check for port conflicts
sudo netstat -tlnp | grep :80

# View detailed error
sudo journalctl -u nginx -n 50
```

### High CPU/Memory usage

1. Check rate limiting is working:
   ```bash
   grep "limiting requests" /var/log/gitlost.io/access.log | wc -l
   ```

2. Monitor processes:
   ```bash
   top -p $(pgrep -f nginx | tr '\n' ',')
   ```

### Logs aren't rotating

```bash
# Test logrotate
sudo logrotate -f /etc/logrotate.d/gitlost.io

# Check logrotate status
sudo cat /var/lib/logrotate/status | grep gitlost
```

## Scaling Considerations

### For Production

1. **Auto Scaling Group** (ASG)
   - Use this script as launch template user data
   - Scale behind load balancer

2. **CloudFront CDN**
   - Cache static assets globally
   - Reduce origin load

3. **S3 Static Hosting** (alternative)
   - Offload static assets to S3 + CloudFront
   - Reduce EC2 bandwidth

4. **API Backend** (future)
   - Move `/api/` requests to separate service
   - nginx acts as reverse proxy

Example with backend:
```bash
# Edit /etc/nginx/conf.d/gitlost.io.conf
upstream backend {
    server api.example.com:3000;
}

location /api/ {
    proxy_pass http://backend;
    # See script for full config
}
```

## Security Hardening

### Additional Steps (Recommended)

1. **Enable HTTPS**
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

2. **Restrict EC2 Security Group**
   - Only allow known IPs if possible
   - Use VPN for admin access

3. **Enable WAF** (AWS Web Application Firewall)
   - Attach to ALB/CloudFront
   - Blocks common attacks

4. **Monitoring**
   - Enable VPC Flow Logs
   - Set up CloudWatch alarms for errors

5. **Backup**
   - Snapshot EC2 volume regularly
   - Store config in version control

## Rollback

If deployment fails or you need to revert:

```bash
# Stop nginx
sudo systemctl stop nginx

# Restore from backup (if made earlier)
sudo cp /etc/nginx/conf.d/gitlost.io.conf.backup.XXXX /etc/nginx/conf.d/gitlost.io.conf

# Start nginx
sudo systemctl start nginx
```

## Cost Estimation

**Monthly cost (us-east-1, free tier)**
- EC2 t3.micro: $0 (free tier) / ~$8.47 (paid)
- Data transfer: $0 (first 1GB free, then ~$0.09/GB)
- CloudWatch Logs: ~$0.50 (if enabled)

**Total**: Free (first year) or ~$9-15/month thereafter

## Support & Documentation

- **Deployment issues**: Check `/var/log/gitlost.io/deploy.log`
- **nginx reference**: https://nginx.org/en/docs/
- **AWS EC2 guide**: https://docs.aws.amazon.com/ec2/
- **Let's Encrypt**: https://letsencrypt.org/docs/

## Next Steps

1. ✅ Deploy script to EC2
2. ✅ Verify deployment at `/health.html`
3. 🔄 Add custom domain (Route53 CNAME)
4. 🔐 Enable HTTPS with certbot
5. 📊 Enable CloudWatch monitoring
6. 🚀 Set up CI/CD for updates
