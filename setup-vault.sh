#!/bin/bash

# Complete Vault Setup Script for Trascender Project
# This script automates the entire Vault setup process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_PATH="/tmp/trascender-data"

echo -e "${BLUE}🚀 Trascender Vault Setup Script${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️ jq is not installed. Installing...${NC}"
    sudo apt-get update && sudo apt-get install -y jq
fi

echo -e "${GREEN}✅ Prerequisites checked${NC}"

# Create data directories
echo -e "${BLUE}📁 Creating data directories...${NC}"
sudo mkdir -p "$DATA_PATH"/{vault,vault-logs,sqlite,redis,prometheus,grafana,alertmanager}
sudo chown -R "$USER:$USER" "$DATA_PATH"
echo -e "${GREEN}✅ Data directories created at $DATA_PATH${NC}"

# Create environment file
echo -e "${BLUE}📄 Setting up environment file...${NC}"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    
    # Update DATA_PATH in .env
    sed -i "s|DATA_PATH=.*|DATA_PATH=$DATA_PATH|" "$SCRIPT_DIR/.env"
    
    echo -e "${GREEN}✅ Environment file created from template${NC}"
    echo -e "${YELLOW}💡 Review and modify .env file if needed${NC}"
else
    echo -e "${YELLOW}⚠️ .env file already exists, skipping...${NC}"
fi

# Build services
echo -e "${BLUE}🏗️ Building Docker services...${NC}"
docker compose build vault

# Start Vault
echo -e "${BLUE}🚀 Starting Vault service...${NC}"
echo "y" | docker compose up -d --force-recreate --remove-orphans vault

# Wait for Vault to be ready
echo -e "${BLUE}⏳ Waiting for Vault to be ready...${NC}"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s -f http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Vault is ready!${NC}"
        break
    fi
    sleep 2
    ((attempt++))
    echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts - waiting for Vault...${NC}"
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}❌ Vault failed to start within expected time${NC}"
    exit 1
fi

# Initialize Vault
echo -e "${BLUE}🔐 Initializing Vault...${NC}"
if ! docker exec hashicorp_vault test -f /vault/scripts/vault-keys.json; then
    docker exec -e VAULT_ADDR=http://localhost:8200 hashicorp_vault /vault/scripts/init-vault.sh
    
    # Copy keys and tokens to host
    docker cp hashicorp_vault:/vault/scripts/vault-keys.json "$SCRIPT_DIR/vault/scripts/"
    docker cp hashicorp_vault:/vault/scripts/service-tokens.json "$SCRIPT_DIR/vault/scripts/"
    
    echo -e "${GREEN}✅ Vault initialized successfully!${NC}"
else
    echo -e "${YELLOW}⚠️ Vault already initialized, unsealing...${NC}"
    docker exec -e VAULT_ADDR=http://localhost:8200 hashicorp_vault /vault/scripts/unseal-vault.sh
fi

# Seed Vault with secrets
echo -e "${BLUE}🌱 Seeding Vault with secrets...${NC}"
ROOT_TOKEN=$(docker exec hashicorp_vault jq -r '.root_token' /vault/scripts/service-tokens.json)
docker exec -e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN="$ROOT_TOKEN" \
    hashicorp_vault /vault/scripts/seed-secrets.sh

# Copy generated environment file
if docker exec hashicorp_vault test -f /vault/scripts/.env.vault; then
    docker cp hashicorp_vault:/vault/scripts/.env.vault "$SCRIPT_DIR/.env.generated"
    echo -e "${GREEN}✅ Generated environment file copied to .env.generated${NC}"
fi

# Update service tokens in .env
if [ -f "$SCRIPT_DIR/vault/scripts/service-tokens.json" ]; then
    echo -e "${BLUE}🔑 Updating service tokens in environment...${NC}"
    
    # Extract tokens
    ROOT_TOKEN=$(jq -r '.root_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json")
    AUTH_TOKEN=$(jq -r '.auth_service_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json")
    GAME_TOKEN=$(jq -r '.game_service_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json")
    CHAT_TOKEN=$(jq -r '.chat_service_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json")
    DB_TOKEN=$(jq -r '.db_service_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json")
    API_TOKEN=$(jq -r '.api_gateway_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json")
    
    # Create tokens file for services
    cat > "$SCRIPT_DIR/.env.tokens" << EOF
# Vault Service Tokens - Source this file or add to your .env
export VAULT_TOKEN_ROOT="$ROOT_TOKEN"
export VAULT_TOKEN_AUTH_SERVICE="$AUTH_TOKEN"
export VAULT_TOKEN_GAME_SERVICE="$GAME_TOKEN"
export VAULT_TOKEN_CHAT_SERVICE="$CHAT_TOKEN"
export VAULT_TOKEN_DB_SERVICE="$DB_TOKEN"
export VAULT_TOKEN_API_GATEWAY="$API_TOKEN"
EOF
    
    echo -e "${GREEN}✅ Service tokens saved to .env.tokens${NC}"
fi

# Create systemd service for auto-unseal (optional)
echo -e "${BLUE}🔧 Setting up auto-unseal service...${NC}"
cat > "/tmp/vault-unseal.service" << EOF
[Unit]
Description=Vault Auto Unseal for Trascender
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/manage-vault.sh unseal
User=$USER
WorkingDirectory=$SCRIPT_DIR

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}💡 Auto-unseal service created at /tmp/vault-unseal.service${NC}"
echo -e "${YELLOW}💡 To install: sudo cp /tmp/vault-unseal.service /etc/systemd/system/ && sudo systemctl enable vault-unseal${NC}"

# Setup token renewal cron job
echo -e "${BLUE}⏰ Setting up token renewal cron job...${NC}"
cat > "/tmp/vault-cron" << EOF
# Vault token renewal for Trascender - runs daily at 2 AM
0 2 * * * $SCRIPT_DIR/manage-vault.sh renew >> /var/log/vault-renewal.log 2>&1
EOF

echo -e "${YELLOW}💡 Cron job created at /tmp/vault-cron${NC}"
echo -e "${YELLOW}💡 To install: crontab /tmp/vault-cron${NC}"

# Final status check
echo -e "${BLUE}🔍 Final status check...${NC}"
docker exec hashicorp_vault vault status

# Summary
echo ""
echo -e "${GREEN}🎉 Vault setup completed successfully!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  ✅ Vault server running on: ${BLUE}http://localhost:8200${NC}"
echo -e "  ✅ Vault UI available at: ${BLUE}http://localhost:8200/ui${NC}"
echo -e "  ✅ Root token: ${YELLOW}$(jq -r '.root_token' "$SCRIPT_DIR/vault/scripts/service-tokens.json" 2>/dev/null || echo 'Check vault/scripts/service-tokens.json')${NC}"
echo -e "  ✅ Data directory: ${BLUE}$DATA_PATH${NC}"
echo -e "  ✅ Configuration: ${BLUE}.env${NC}"
echo -e "  ✅ Service tokens: ${BLUE}.env.tokens${NC}"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo -e "  1. Review and source the token environment: ${YELLOW}source .env.tokens${NC}"
echo -e "  2. Start all services: ${YELLOW}docker compose up -d${NC}"
echo -e "  3. Verify service health: ${YELLOW}./manage-vault.sh status${NC}"
echo -e "  4. Open Vault UI: ${YELLOW}./manage-vault.sh ui${NC}"
echo ""
echo -e "${YELLOW}⚠️ Important Security Notes:${NC}"
echo -e "  🔐 Backup vault/scripts/vault-keys.json securely"
echo -e "  🔐 Backup vault/scripts/service-tokens.json securely"
echo -e "  🔐 Consider enabling TLS in production"
echo -e "  🔐 Set up regular backups with: ${YELLOW}./manage-vault.sh backup${NC}"
echo ""
echo -e "${BLUE}📚 Documentation: ${YELLOW}vault/README.md${NC}"
echo -e "${BLUE}🛠️ Management: ${YELLOW}./manage-vault.sh help${NC}"
