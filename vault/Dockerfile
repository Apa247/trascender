FROM hashicorp/vault:1.15

# Set working directory
WORKDIR /vault

# Copy configuration files
COPY config/vault.hcl /vault/config/vault.hcl
COPY policies/ /vault/policies/
COPY scripts/ /vault/scripts/

# Create necessary directories
RUN mkdir -p /vault/file /vault/logs /vault/plugins /vault/certs

# Make scripts executable
RUN chmod +x /vault/scripts/*.sh

# Expose Vault port
EXPOSE 8200 8201

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD vault status || exit 1

# Start Vault server
CMD ["vault", "server", "-config=/vault/config/vault.hcl"]
