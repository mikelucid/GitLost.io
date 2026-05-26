#!/bin/bash
# gitlost.io - Production-Ready EC2 Deployment Script
# Features: security hardening, logging, error handling, modular design

set -euo pipefail

################################################################################
# Configuration
################################################################################
WEB_ROOT="/var/www/gitlost.io"
CONFIG_DIR="/etc/gitlost.io"
LOG_DIR="/var/log/gitlost.io"
LOG_FILE="$LOG_DIR/deploy.log"
NGINX_CONFIG="/etc/nginx/conf.d/gitlost.io.conf"
SCRIPTS_DIR="/opt/gitlost.io/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

################################################################################
# System Checks
################################################################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root"
    fi
}

check_aws_environment() {
    log "Checking AWS environment..."
    if ! curl -s -m 1 http://169.254.169.254/latest/meta-data/ami-id &>/dev/null; then
        warn "Not running on EC2 or metadata service unavailable"
    else
        log "✓ AWS EC2 metadata service available"
    fi
}

################################################################################
# Directory & User Setup
################################################################################
setup_directories() {
    log "Setting up directories..."
    mkdir -p "$WEB_ROOT" "$CONFIG_DIR" "$LOG_DIR" "$SCRIPTS_DIR"
    
    # Create nginx service user if doesn't exist
    if ! id -u nginx &>/dev/null 2>&1; then
        log "Creating nginx user..."
        useradd -r -s /bin/false nginx || warn "nginx user may already exist"
    fi
    
    # Set permissions
    chown -R nginx:nginx "$WEB_ROOT" "$LOG_DIR"
    chmod 755 "$WEB_ROOT"
    chmod 755 "$LOG_DIR"
    
    log "✓ Directories ready"
}

################################################################################
# Package Installation
################################################################################
install_packages() {
    log "Updating system and installing packages..."
    
    dnf update -y || error_exit "Failed to update system"
    
    local packages=(
        "nginx"
        "certbot"
        "python3-certbot-nginx"
        "curl"
        "logrotate"
        "wget"
        "git"
    )
    
    for pkg in "${packages[@]}"; do
        if ! dnf install -y "$pkg" &>/dev/null; then
            error_exit "Failed to install $pkg"
        fi
    done
    
    log "✓ All packages installed"
}

################################################################################
# HTML & Web Assets
################################################################################
deploy_web_content() {
    log "Deploying web content..."
    
    # Create main index.html
    cat > "$WEB_ROOT/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>gitlost.io — The Lost Commit Repository</title>
    <link rel="stylesheet" href="/static/styles.css">
    <link rel="manifest" href="/manifest.json">
    <meta name="theme-color" content="#000000">
</head>
<body>
<div class="cursor-glow" id="cursorGlow"></div>
<div class="lost-panel" id="lostPanel">
    <div class="glitch">gitlost.io</div>
    <div class="sub">> where lost commits find value — literally</div>

    <div class="terminal-log" id="logArea">
        <div class="log-line">>_ initializing lost commit resonance...</div>
        <div class="log-line">>_ scanning abandoned branches & WIP ghosts</div>
        <div class="log-line">>_ proof of lost work active</div>
        <div class="log-line blink">>_ awaiting the threshold...</div>
    </div>

    <div id="rewardZone" class="hidden">
        <div class="reward-badge">✨ BITCOIN FRAGMENT DETECTED ✨</div>
    </div>

    <div class="wallet">
        <span style="color:#aaa;">🗝️ your subconscious wallet</span>
        <div class="btc-amount" id="btcDisplay">0.00000000 BTC</div>
        <div style="font-size:0.7rem;">total lost satoshis recovered</div>
    </div>

    <hr />
    <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap;">
        <button id="seekBtn" aria-label="Seek lost commits">⟳ seek lost commits</button>
        <button id="resetBtn" aria-label="Reset wallet">🗑️ git reset --hard</button>
    </div>
    <footer>
        ⚡ proof of lost work — random rewards appear when the void chooses you.<br>
        every refresh, every click. no pattern. no promises. only lost magic.
    </footer>
</div>

<script src="/static/app.js"></script>
</body>
</html>
HTMLEOF
    
    # Create static assets directory
    mkdir -p "$WEB_ROOT/static"
    
    # Deploy CSS
    cat > "$WEB_ROOT/static/styles.css" << 'CSSEOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    cursor: crosshair;
}

body {
    background: radial-gradient(circle at 20% 30%, #0a0c12, #000000);
    min-height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    font-family: 'Courier New', 'Fira Code', monospace;
    padding: 1rem;
}

.lost-panel {
    max-width: 800px;
    width: 100%;
    background: rgba(0, 0, 0, 0.85);
    border: 1px solid #2aff6e30;
    border-radius: 24px;
    backdrop-filter: blur(4px);
    box-shadow: 0 0 40px rgba(42, 255, 110, 0.1), inset 0 0 10px #2aff6e10;
    padding: 2rem;
    transition: all 0.3s ease;
}

.glitch {
    font-size: 3rem;
    font-weight: bold;
    color: #2aff6e;
    text-shadow: 0 0 5px #2aff6e, 0 0 2px #0f0;
    letter-spacing: -2px;
    animation: flicker 3s infinite;
}

@keyframes flicker {
    0% { opacity: 0.9; text-shadow: 0 0 2px #2aff6e; }
    50% { opacity: 1; text-shadow: 0 0 12px #6eff8c, 0 0 4px #2aff6e; }
    100% { opacity: 0.95; text-shadow: 0 0 2px #2aff6e; }
}

.sub {
    color: #8bc34a;
    border-left: 3px solid #2aff6e;
    padding-left: 1rem;
    margin: 1.5rem 0;
    font-size: 0.9rem;
    opacity: 0.8;
}

.terminal-log {
    background: #0f121b;
    padding: 1rem;
    border-radius: 14px;
    font-size: 0.85rem;
    color: #b4ffb4;
    font-family: monospace;
    height: 180px;
    overflow-y: auto;
    border: 1px solid #2aff6e30;
    margin: 1.5rem 0;
    scroll-behavior: smooth;
}

.log-line {
    border-bottom: 1px dashed #2aff6e20;
    padding: 4px 0;
    white-space: pre-wrap;
    word-break: break-word;
}

.blink {
    animation: blink-anime 1.2s step-end infinite;
}

@keyframes blink-anime {
    0%, 100% { opacity: 1; }
    50% { opacity: 0; }
}

.reward-badge {
    background: #2aff6e10;
    border: 1px solid #ffd966;
    color: #ffd966;
    padding: 0.6rem 1rem;
    border-radius: 40px;
    font-weight: bold;
    display: inline-block;
    margin-top: 0.5rem;
    backdrop-filter: blur(4px);
    animation: pulse 0.5s ease-in-out;
}

@keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
}

button {
    background: none;
    border: 1px solid #2aff6e;
    color: #2aff6e;
    padding: 8px 18px;
    font-family: monospace;
    font-weight: bold;
    border-radius: 40px;
    transition: 0.2s;
    margin-top: 1rem;
    cursor: pointer;
}

button:hover {
    background: #2aff6e20;
    box-shadow: 0 0 8px #2aff6e;
}

button:active {
    transform: scale(0.98);
}

button:focus {
    outline: 2px solid #2aff6e;
    outline-offset: 2px;
}

.wallet {
    background: #02061780;
    border-radius: 20px;
    padding: 1rem;
    text-align: center;
    margin-top: 1rem;
    border: 1px solid #f4c54230;
}

.btc-amount {
    font-size: 2rem;
    color: #f7931a;
    text-shadow: 0 0 6px #f7931a80;
}

hr {
    border-color: #2aff6e20;
    margin: 1rem 0;
}

footer {
    font-size: 0.7rem;
    text-align: center;
    margin-top: 2rem;
    color: #4a6741;
}

.hidden {
    display: none;
}

.cursor-glow {
    position: fixed;
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: radial-gradient(circle, #2aff6e40, transparent);
    pointer-events: none;
    z-index: 999;
    transform: translate(-50%, -50%);
    transition: 0.05s linear;
}

@media (prefers-reduced-motion: reduce) {
    * {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
    }
}

@media (max-width: 640px) {
    .lost-panel {
        padding: 1.5rem;
    }
    
    .glitch {
        font-size: 2rem;
    }
    
    button {
        padding: 6px 14px;
        font-size: 0.9rem;
    }
}
CSSEOF
    
    # Deploy JavaScript
    cat > "$WEB_ROOT/static/app.js" << 'JSEOF'
// gitlost.io - Lost Commit Rewards System
(function() {
    'use strict';

    let totalSatoshis = 0;
    let seekCount = 0;
    let welcomeRewardGiven = false;

    const rewardMessages = [
        ">_ a forgotten commit surfaces: +1337 satoshis",
        ">_ you hear a whisper from an orphaned branch... +4200 sat",
        ">_ the ghost of 'fix stuff' leaves a tip: +800 sats",
        ">_ your regret over `git push --force` manifests as +250 sats",
        ">_ a 3am coffee commit yields: +5550 sats",
        ">_ the lost repository smiles: +999 sats",
        ">_ someone, somewhere, typed `git commit --allow-empty` - +77 sats"
    ];

    const failMessages = [
        ">_ nothing but a detached HEAD and regret.",
        ">_ you found an empty commit message: 'asdf' — worthless.",
        ">_ the lost commit evades you... try again later.",
        ">_ a stray .DS_Store file. no satoshis this time.",
        ">_ your 'lostness' score is low. commit more chaos."
    ];

    /**
     * Load persisted wallet from localStorage
     */
    function loadWallet() {
        try {
            const saved = localStorage.getItem("gitlost_sats");
            if (saved !== null && !isNaN(parseInt(saved, 10))) {
                totalSatoshis = parseInt(saved, 10);
            } else {
                totalSatoshis = 0;
            }
        } catch (e) {
            console.warn("localStorage unavailable:", e);
            totalSatoshis = 0;
        }
        updateDisplay();
    }

    /**
     * Update BTC display
     */
    function updateDisplay() {
        const btcValue = totalSatoshis / 100000000;
        const btcDisplay = document.getElementById("btcDisplay");
        if (btcDisplay) {
            btcDisplay.textContent = btcValue.toFixed(8) + " BTC";
        }
    }

    /**
     * Persist wallet to localStorage
     */
    function saveWallet() {
        try {
            localStorage.setItem("gitlost_sats", totalSatoshis.toString());
        } catch (e) {
            console.warn("Failed to save wallet:", e);
        }
    }

    /**
     * Add a line to the terminal log
     */
    function addLogLine(text) {
        const logDiv = document.getElementById("logArea");
        if (!logDiv) return;

        const newLine = document.createElement("div");
        newLine.className = "log-line";
        newLine.textContent = text;
        logDiv.appendChild(newLine);
        logDiv.scrollTop = logDiv.scrollHeight;

        // Keep only last 55 lines
        while (logDiv.children.length > 55) {
            logDiv.removeChild(logDiv.firstChild);
        }
    }

    /**
     * Grant random reward
     */
    function grantRandomReward() {
        let rewardSats = Math.floor(Math.random() * 15000) + 50;
        
        // 4% chance of big reward
        if (Math.random() < 0.04) {
            rewardSats = Math.floor(Math.random() * 100000) + 25000;
        }
        
        totalSatoshis += rewardSats;
        saveWallet();
        updateDisplay();

        const msg = rewardMessages[Math.floor(Math.random() * rewardMessages.length)];
        const btcValue = (rewardSats / 100000000).toFixed(8);
        const rewardLine = `✨ ${msg} → +${rewardSats} satoshis (${btcValue} BTC) ✨`;
        
        addLogLine(rewardLine);
        addLogLine(">_ the void trembles. reward absorbed.");

        // Show reward badge
        const rewardZone = document.getElementById("rewardZone");
        if (rewardZone) {
            rewardZone.classList.remove("hidden");
            setTimeout(() => {
                rewardZone.classList.add("hidden");
            }, 2000);
        }

        // Analytics (if available)
        if (window.gtag) {
            gtag('event', 'reward_granted', {
                sats: rewardSats,
                total_sats: totalSatoshis
            });
        }
    }

    /**
     * Handle seek button click
     */
    function onSeek() {
        seekCount++;
        addLogLine(`>_ scanning lost commit objects... (seek #${seekCount})`);
        
        const willReward = Math.random() < 0.28;
        
        setTimeout(() => {
            if (willReward) {
                grantRandomReward();
                addLogLine(">_ gitlost.io whispers: 'proof of lost work accepted'");
            } else {
                const failMsg = failMessages[Math.floor(Math.random() * failMessages.length)];
                addLogLine(`🌫️ ${failMsg}`);
            }
            
            // Analytics
            if (window.gtag) {
                gtag('event', 'seek', {
                    seek_count: seekCount,
                    rewarded: willReward
                });
            }
        }, 180 + Math.random() * 400);
    }

    /**
     * Handle reset button click
     */
    function resetWallet() {
        if (confirm("⚠️ git reset --hard : erase all recovered satoshis? This cannot be undone.")) {
            totalSatoshis = 0;
            saveWallet();
            updateDisplay();
            addLogLine("💀 HARD RESET: your lost satoshis return to the void.");
            addLogLine(">_ you feel lighter. and emptier.");
            seekCount = 0;
            const rewardZone = document.getElementById("rewardZone");
            if (rewardZone) {
                rewardZone.classList.add("hidden");
            }
            
            if (window.gtag) {
                gtag('event', 'hard_reset');
            }
        } else {
            addLogLine(">_ phew. your lost stash survives another day.");
        }
    }

    /**
     * Cursor glow effect
     */
    function initCursorGlow() {
        const glow = document.getElementById("cursorGlow");
        if (!glow) return;

        document.addEventListener("mousemove", function(e) {
            glow.style.left = e.clientX + "px";
            glow.style.top = e.clientY + "px";
        });
    }

    /**
     * Try to give welcome reward
     */
    function tryWelcomeReward() {
        if (!welcomeRewardGiven && Math.random() < 0.22) {
            welcomeRewardGiven = true;
            setTimeout(() => {
                addLogLine(">_ the threshold opens... a forgotten commit finds you.");
                grantRandomReward();
            }, 1200);
        } else {
            addLogLine(">_ the lost repository watches. maybe next time.");
        }
    }

    /**
     * Initialize application
     */
    function init() {
        // Wait for DOM
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', init);
            return;
        }

        loadWallet();
        initCursorGlow();
        tryWelcomeReward();

        // Event listeners
        const seekBtn = document.getElementById("seekBtn");
        const resetBtn = document.getElementById("resetBtn");
        
        if (seekBtn) seekBtn.addEventListener("click", onSeek);
        if (resetBtn) resetBtn.addEventListener("click", resetWallet);

        console.log(
            "%c gitlost.io — where lost commits find value. (simulated BTC rewards)",
            "color: #2aff6e; font-size: 14px;"
        );
        console.log("No real crypto. Portfolio magic only. Enjoy the lore.");
    }

    // Start initialization
    init();
})();
JSEOF
    
    # Create manifest.json for PWA
    cat > "$WEB_ROOT/manifest.json" << 'JSONEOF'
{
  "name": "gitlost.io - The Lost Commit Repository",
  "short_name": "gitlost.io",
  "description": "Where lost commits find value — literally",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#000000",
  "theme_color": "#2aff6e",
  "orientation": "portrait-primary"
}
JSONEOF
    
    # Create robots.txt
    cat > "$WEB_ROOT/robots.txt" << 'ROBOTSEOF'
User-agent: *
Allow: /
Disallow: /admin/

Sitemap: /sitemap.xml
ROBOTSEOF
    
    # Create sitemap.xml
    cat > "$WEB_ROOT/sitemap.xml" << 'SITEMAPEOF'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://gitlost.io/</loc>
    <lastmod>2026-05-26</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
SITEMAPEOF
    
    # Create health check endpoint
    echo "gitlost.io is alive" > "$WEB_ROOT/health.html"
    
    # Set permissions
    chown -R nginx:nginx "$WEB_ROOT"
    chmod 755 "$WEB_ROOT"
    chmod 644 "$WEB_ROOT"/*.{html,json,xml}
    chmod 755 "$WEB_ROOT/static"
    chmod 644 "$WEB_ROOT/static"/*
    
    log "✓ Web content deployed"
}

################################################################################
# Nginx Configuration
################################################################################
setup_nginx() {
    log "Configuring nginx..."
    
    # Backup existing config if it exists
    if [[ -f "$NGINX_CONFIG" ]]; then
        cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%s)"
        log "Backed up existing config"
    fi
    
    # Create nginx config with security headers and optimizations
    cat > "$NGINX_CONFIG" << 'NGINXEOF'
# gitlost.io nginx configuration

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=general_limit:10m rate=30r/s;
limit_req_zone $binary_remote_addr zone=seek_limit:10m rate=10r/s;

upstream backend {
    # Placeholder for future API backend
    server 127.0.0.1:3000;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    # Logs
    access_log /var/log/gitlost.io/access.log combined buffer=32k;
    error_log /var/log/gitlost.io/error.log warn;
    
    # Document root
    root /var/www/gitlost.io;
    index index.html;
    
    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://www.google-analytics.com;" always;
    
    # Gzip compression
    gzip on;
    gzip_types text/plain text/css text/javascript application/json application/javascript;
    gzip_min_length 1024;
    gzip_vary on;
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Health check endpoint
    location /health.html {
        access_log off;
        try_files $uri =404;
    }
    
    # Main application with rate limiting
    location / {
        limit_req zone=general_limit burst=50 nodelay;
        try_files $uri $uri/ /index.html;
        
        # Cache control for HTML
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # API endpoint (future use)
    location /api/ {
        limit_req zone=seek_limit burst=20 nodelay;
        
        # Proxy to backend if available
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 10s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # 404 handling
    error_page 404 /index.html;
}
NGINXEOF
    
    # Test nginx configuration
    if ! nginx -t 2>&1 | grep -q "successful"; then
        error_exit "nginx configuration test failed"
    fi
    
    log "✓ nginx configured and validated"
}

################################################################################
# Log Rotation Setup
################################################################################
setup_logrotate() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/gitlost.io << 'LOGROTATEEOF'
/var/log/gitlost.io/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 nginx nginx
    sharedscripts
    postrotate
        if systemctl is-active --quiet nginx; then
            nginx -s reload
        fi
    endscript
}
LOGROTATEEOF
    
    log "✓ Log rotation configured"
}

################################################################################
# Firewall Configuration
################################################################################
setup_firewall() {
    log "Configuring firewall..."
    
    if ! command -v firewall-cmd &>/dev/null; then
        warn "firewall-cmd not found, skipping firewall setup"
        return
    fi
    
    if firewall-cmd --state &>/dev/null; then
        firewall-cmd --permanent --add-service=http || warn "Failed to add HTTP service"
        firewall-cmd --reload || warn "Failed to reload firewall"
        log "✓ Firewall configured (HTTP allowed)"
    else
        warn "Firewall is not active"
    fi
}

################################################################################
# Service Management
################################################################################
setup_services() {
    log "Setting up services..."
    
    # Enable and start nginx
    systemctl enable nginx || error_exit "Failed to enable nginx"
    systemctl start nginx || error_exit "Failed to start nginx"
    
    log "✓ nginx service enabled and started"
}

################################################################################
# CloudWatch Integration (Optional)
################################################################################
setup_cloudwatch() {
    log "Setting up CloudWatch..."
    
    # Check if CloudWatch agent is installed
    if command -v amazon-cloudwatch-agent-ctl &>/dev/null; then
        cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWCONFIGEOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/gitlost.io/access.log",
            "log_group_name": "/aws/ec2/gitlost.io/nginx/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/gitlost.io/error.log",
            "log_group_name": "/aws/ec2/gitlost.io/nginx/error",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/gitlost.io/deploy.log",
            "log_group_name": "/aws/ec2/gitlost.io/deployment",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWCONFIGEOF
        log "✓ CloudWatch agent configured"
    else
        log "ℹ CloudWatch agent not installed (optional)"
    fi
}

################################################################################
# Metadata & Deployment Info
################################################################################
get_deployment_info() {
    log "Retrieving deployment information..."
    
    # Get IMDSv2 token
    local token=""
    token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null) || true
    
    local public_ip="unknown"
    local instance_id="unknown"
    local region="unknown"
    local availability_zone="unknown"
    
    if [[ -n "$token" ]]; then
        public_ip=$(curl -s -H "X-aws-ec2-metadata-token: $token" \
            http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null) || public_ip="unknown"
        
        instance_id=$(curl -s -H "X-aws-ec2-metadata-token: $token" \
            http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null) || instance_id="unknown"
        
        availability_zone=$(curl -s -H "X-aws-ec2-metadata-token: $token" \
            http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null) || availability_zone="unknown"
        
        if [[ "$availability_zone" != "unknown" ]]; then
            region="${availability_zone%?}"
        fi
    else
        warn "IMDSv2 token unavailable, falling back to IMDSv1"
        public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null) || public_ip="unknown"
        instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null) || instance_id="unknown"
        availability_zone=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null) || availability_zone="unknown"
    fi
    
    cat > "$CONFIG_DIR/deployment.info" << INFEOF
================================================================================
gitlost.io Deployment Information
================================================================================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Public IP: http://$public_ip
Instance ID: $instance_id
Region: $region
Availability Zone: $availability_zone
Web Root: $WEB_ROOT
Config Directory: $CONFIG_DIR
Log Directory: $LOG_DIR
nginx Config: $NGINX_CONFIG

Deployed by: User Data Script (v1.0)
================================================================================
INFEOF
    
    cat "$CONFIG_DIR/deployment.info" | tee -a "$LOG_FILE"
}

################################################################################
# Main Execution
################################################################################
main() {
    log "========================================"
    log "gitlost.io - Production Deployment"
    log "========================================"
    log "Starting deployment at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    check_root
    check_aws_environment
    setup_directories
    install_packages
    deploy_web_content
    setup_nginx
    setup_logrotate
    setup_firewall
    setup_services
    setup_cloudwatch
    get_deployment_info
    
    log "========================================"
    log "✅ Deployment completed successfully!"
    log "========================================"
    log "View deployment info: cat $CONFIG_DIR/deployment.info"
    log "View logs: tail -f $LOG_FILE"
}

# Execute main function
main "$@"
