#!/bin/bash

# Vault Initialization Script for Trascender Project
# This script initializes and unseals Vault, sets up authentication and policies

set -e

echo "=== Vault Initialization Script ==="
echo "Waiting for Vault to be ready..."

# Wait for Vault to be available
until vault status >/dev/null 2>&1; do
  echo "Waiting for Vault to start..."
  sleep 2
done

echo "Vault is running. Checking initialization status..."

# Check if Vault is already initialized
if vault status | grep -q "Initialized.*true"; then
  echo "Vault is already initialized."
else
  echo "Initializing Vault..."
  
  # Initialize Vault with 3 key shares and threshold of 2
  vault operator init \
    -key-shares=3 \
    -key-threshold=2 \
    -format=json > /vault/scripts/vault-keys.json
  
  echo "Vault initialized successfully!"
  echo "Keys and root token saved to /vault/scripts/vault-keys.json"
  
  # Extract unseal keys and root token
  UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' /vault/scripts/vault-keys.json)
  UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' /vault/scripts/vault-keys.json)
  ROOT_TOKEN=$(jq -r '.root_token' /vault/scripts/vault-keys.json)
  
  echo "Unsealing Vault with first key..."
  vault operator unseal "$UNSEAL_KEY_1"
  
  echo "Unsealing Vault with second key..."
  vault operator unseal "$UNSEAL_KEY_2"
  
  echo "Vault unsealed successfully!"
  
  # Set root token for further operations
  export VAULT_TOKEN="$ROOT_TOKEN"
  
  echo "Setting up Vault configuration..."
  
  # Enable the KV secrets engine at 'secret'
  echo "Enabling KV secrets engine..."
  vault secrets enable -path=secret kv-v2
  
  # Create policies
  echo "Creating policies..."
  vault policy write admin-policy /vault/policies/admin-policy.hcl
  vault policy write auth-service-policy /vault/policies/auth-service-policy.hcl
  vault policy write game-service-policy /vault/policies/game-service-policy.hcl
  vault policy write chat-service-policy /vault/policies/chat-service-policy.hcl
  vault policy write db-service-policy /vault/policies/db-service-policy.hcl
  vault policy write api-gateway-policy /vault/policies/api-gateway-policy.hcl
  
  # Create service tokens
  echo "Creating service tokens..."
  
  # Auth service token
  AUTH_TOKEN=$(vault write -field=token auth/token/create \
    policies="auth-service-policy" \
    ttl=720h \
    renewable=true \
    display_name="auth-service")
  
  # Game service token  
  GAME_TOKEN=$(vault write -field=token auth/token/create \
    policies="game-service-policy" \
    ttl=720h \
    renewable=true \
    display_name="game-service")
  
  # Chat service token
  CHAT_TOKEN=$(vault write -field=token auth/token/create \
    policies="chat-service-policy" \
    ttl=720h \
    renewable=true \
    display_name="chat-service")
  
  # DB service token
  DB_TOKEN=$(vault write -field=token auth/token/create \
    policies="db-service-policy" \
    ttl=720h \
    renewable=true \
    display_name="db-service")
  
  # API Gateway token
  API_TOKEN=$(vault write -field=token auth/token/create \
    policies="api-gateway-policy" \
    ttl=720h \
    renewable=true \
    display_name="api-gateway")
  
  # Save service tokens to file
  cat > /vault/scripts/service-tokens.json << EOF
{
  "root_token": "$ROOT_TOKEN",
  "auth_service_token": "$AUTH_TOKEN",
  "game_service_token": "$GAME_TOKEN",
  "chat_service_token": "$CHAT_TOKEN",
  "db_service_token": "$DB_TOKEN",
  "api_gateway_token": "$API_TOKEN"
}
EOF
  
  echo "Service tokens created and saved to /vault/scripts/service-tokens.json"
  
  echo "=== Vault setup completed successfully! ==="
  echo "Root Token: $ROOT_TOKEN"
  echo "Vault UI available at: http://localhost:8200/ui"
  echo ""
  echo "IMPORTANT: Save the vault-keys.json and service-tokens.json files securely!"
  echo "You will need the unseal keys to restart Vault."
  
fi
