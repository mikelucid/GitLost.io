#!/bin/bash
# Development setup script for local testing

set -euo pipefail

echo "🚀 Setting up gitlost.io development environment..."

# Install Node.js (for http-server)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://fnm.io/install | bash
    source ~/.bashrc
    fnm install 18
fi

# Install http-server globally
if ! command -v http-server &> /dev/null; then
    npm install -g http-server
fi

# Create directory structure if needed
mkdir -p src/static src/pages

# Copy or symlink files
if [ ! -f src/index.html ]; then
    echo "Note: Copy your index.html to src/index.html"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start development server:"
echo "  cd src && http-server -p 8080"
echo ""
echo "Or use Python:"
echo "  cd src && python3 -m http.server 8080"
echo ""
echo "Then visit: http://localhost:8080"
