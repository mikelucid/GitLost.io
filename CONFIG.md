# gitlost.io - Deployment Configuration Examples

## Environment-Specific Deployments

### Staging (Docker)
   
```dockerfile
FROM nginx:alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/gitlost.io.conf
COPY src/ /var/www/gitlost.io/

RUN mkdir -p /var/log/gitlost.io && \
    touch /var/log/gitlost.io/access.log && \
    touch /var/log/gitlost.io/error.log && \
    chown -R nginx:nginx /var/log/gitlost.io

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

Build & run:
```bash
docker build -t gitlost.io:latest .
docker run -p 8080:80 gitlost.io:latest
```

### Production (Terraform)

```hcl
# main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "gitlost" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  user_data = file("${path.module}/deploy/deploy.sh")
  
  security_groups = [aws_security_group.gitlost.name]
  
  monitoring = true
  
  tags = {
    Name = "gitlost.io"
    Env  = "production"
  }
}

resource "aws_security_group" "gitlost" {
  name = "gitlost-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "instance_public_ip" {
  value = aws_instance.gitlost.public_ip
}
```

Deploy:
```bash
terraform init
terraform plan
terraform apply
```

### GitHub Actions CI/CD

```yaml
name: Deploy gitlost.io

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'deploy/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate HTML/CSS/JS
        run: |
          npm install -g html-validate
          html-validate src/index.html
      
      - name: Test nginx config
        run: |
          docker run --rm -v $PWD/deploy:/etc/nginx/conf.d nginx:alpine nginx -t
      
      - name: Deploy to EC2
        if: github.ref == 'refs/heads/main'
        env:
          EC2_HOST: ${{ secrets.EC2_HOST }}
          EC2_KEY: ${{ secrets.EC2_KEY }}
        run: |
          mkdir -p ~/.ssh
          echo "$EC2_KEY" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          ssh-keyscan $EC2_HOST >> ~/.ssh/known_hosts
          
          rsync -avz --delete src/ ec2-user@$EC2_HOST:/var/www/gitlost.io/
          ssh ec2-user@$EC2_HOST "sudo systemctl reload nginx"
          
          echo "✅ Deployed to http://$EC2_HOST"
```

Secrets needed:
- `EC2_HOST`: EC2 public IP
- `EC2_KEY`: Private SSH key (ensure EC2 has public key)

## Monitoring & Alerting

### CloudWatch Alarms

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name gitlost-error-rate \
  --alarm-description "Alert if error rate exceeds 5%" \
  --metric-name StatusCode5xx \
  --namespace AWS/ELB \
  --statistic Sum \
  --period 300 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:123456789:alerts
```

### Log Insights Queries

```
# Top IPs seeking rewards
fields @timestamp, @message | filter @message like /seeking/ | stats count() by @message

# Performance (p99 response time)
fields @duration | stats pct(@duration, 99)

# Error rates by hour
fields @timestamp | stats count() as errors by bin(5m)
```

## Rollout Strategy

### Blue-Green Deployment

```bash
#!/bin/bash
# Deploy to standby instance
STANDBY_IP="10.0.0.20"

# Copy new assets
rsync -avz src/ ec2-user@$STANDBY_IP:/var/www/gitlost.io/

# Test on standby
curl http://$STANDBY_IP/health.html

# Switch traffic (update Route53 weighted record)
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "gitlost.io",
        "Type": "A",
        "SetIdentifier": "Production",
        "Weight": 100,
        "AliasTarget": {
          "HostedZoneId": "Z123",
          "DNSName": "gitlost-prod.elb.amazonaws.com"
        }
      }
    }]
  }'
```

### Canary Deployment

```bash
# Route 5% traffic to new version
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "gitlost.io",
          "Type": "A",
          "SetIdentifier": "Production",
          "Weight": 95,
          "AliasTarget": {"HostedZoneId": "Z123", "DNSName": "prod.elb.amazonaws.com"}
        }
      },
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "gitlost.io",
          "Type": "A",
          "SetIdentifier": "Canary",
          "Weight": 5,
          "AliasTarget": {"HostedZoneId": "Z123", "DNSName": "canary.elb.amazonaws.com"}
        }
      }
    ]
  }'

# Monitor canary metrics
sleep 300
CANARY_ERROR_RATE=$(aws cloudwatch get-metric-statistics \
  --metric-name StatusCode5xx \
  --namespace AWS/ELB \
  --start-time $(date -u -d '5 min ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum | jq '.Datapoints[0].Sum // 0')

if (( $(echo "$CANARY_ERROR_RATE > 10" | bc -l) )); then
  echo "Canary failed, rolling back..."
  # Rollback to 100% production traffic
fi
```

## Backup & Disaster Recovery

### Automated EBS Snapshots

```bash
#!/bin/bash
# Create daily EBS snapshots

INSTANCE_ID="i-1234567890abcdef0"
VOLUME_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "gitlost.io backup - $(date +%Y-%m-%d)"

# Cleanup old snapshots (keep last 7 days)
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=description,Values=gitlost.io backup*" \
  --query "sort_by(Snapshots, &StartTime)[*].[SnapshotId,StartTime]" \
  --output text | head -n -7 | awk '{print $1}' | \
  while read snap; do
    aws ec2 delete-snapshot --snapshot-id $snap
  done
```

Schedule via cron:
```bash
# Add to root crontab
0 2 * * * /opt/gitlost.io/scripts/backup.sh >> /var/log/gitlost.io/backup.log 2>&1
```

## Performance Optimization

### Asset Compression

```bash
#!/bin/bash
# Pre-compress static assets for gzip
cd /var/www/gitlost.io/static

for file in *.{js,css,json}; do
  if [ -f "$file" ] && [ ! -f "$file.gz" ]; then
    gzip -9 -k "$file"
  fi
done
```

Update nginx:
```nginx
location ~* \.(js|css)$ {
    # Serve .gz version if available
    gzip on;
    # Pre-compressed files
    try_files $uri.gz $uri =404;
    types {
        text/javascript application/javascript;
        text/css text/css;
    }
}
```

## Cost Optimization

### Estimated Monthly Costs

| Component | Cost | Notes |
|-----------|------|-------|
| EC2 t3.micro | $0–8.47 | Free tier 12 months |
| Data out | $0–5 | First 1GB free, ~$0.09/GB |
| CloudWatch Logs | $0.50 | 500 MB logs/month |
| **Total** | **~$9/month** | After free tier |

Reduce costs:
- Use t3.nano ($0.0096/hr) if not memory-intensive
- Compress logs before archival
- Archive old logs to S3 Glacier (~$0.004/GB)

---

For more info, see `DEPLOYMENT.md`
