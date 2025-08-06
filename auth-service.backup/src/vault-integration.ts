// vault-integration.ts - Integration example for Vault in auth-service
import { VaultClient, initializeVault, getVaultClient } from '../../shared/vault-client';

interface AuthServiceConfig {
  jwtSecret: string;
  sessionTimeout: number;
  maxLoginAttempts: number;
  lockoutDuration: number;
  googleClientId: string;
  googleClientSecret: string;
  oauthCallbackUrl: string;
  redisHost: string;
  redisPort: number;
  redisPassword: string;
}

class VaultConfigManager {
  private vault: VaultClient;
  private config: AuthServiceConfig | null = null;
  private configCacheTime: number = 0;
  private readonly CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

  constructor() {
    // Initialize Vault client
    const vaultToken = process.env.VAULT_TOKEN;
    const vaultAddr = process.env.VAULT_ADDR || 'http://vault:8200';

    if (!vaultToken) {
      throw new Error('VAULT_TOKEN environment variable is required');
    }

    this.vault = initializeVault({
      address: vaultAddr,
      token: vaultToken,
      timeout: 10000,
    });

    // Setup automatic token renewal (every hour)
    this.setupTokenRenewal();
  }

  /**
   * Get all configuration for auth service from Vault
   */
  async getConfig(): Promise<AuthServiceConfig> {
    // Return cached config if still valid
    if (this.config && Date.now() - this.configCacheTime < this.CACHE_DURATION) {
      return this.config;
    }

    try {
      console.log('🔑 Fetching configuration from Vault...');
      
      // Fetch all required secrets from Vault
      const [
        jwtConfig,
        authConfig,
        oauthConfig,
        redisConfig
      ] = await Promise.all([
        this.vault.getSecret('jwt/config'),
        this.vault.getSecret('auth-service/config'),
        this.vault.getSecret('auth-service/oauth'),
        this.vault.getSecret('redis/config')
      ]);

      // Build configuration object
      this.config = {
        jwtSecret: jwtConfig.secret as string,
        sessionTimeout: Number(authConfig.session_timeout) || 1800,
        maxLoginAttempts: Number(authConfig.max_login_attempts) || 5,
        lockoutDuration: Number(authConfig.lockout_duration) || 900,
        googleClientId: oauthConfig.google_client_id as string,
        googleClientSecret: oauthConfig.google_client_secret as string,
        oauthCallbackUrl: oauthConfig.oauth_callback_url as string,
        redisHost: redisConfig.host as string,
        redisPort: Number(redisConfig.port) || 6379,
        redisPassword: redisConfig.password as string,
      };

      this.configCacheTime = Date.now();
      console.log('✅ Configuration loaded from Vault successfully');
      
      return this.config;
    } catch (error) {
      console.error('❌ Failed to load configuration from Vault:', error);
      
      // Fallback to environment variables if Vault fails
      return this.getFallbackConfig();
    }
  }

  /**
   * Get specific configuration value
   */
  async getConfigValue<K extends keyof AuthServiceConfig>(key: K): Promise<AuthServiceConfig[K]> {
    const config = await this.getConfig();
    return config[key];
  }

  /**
   * Update a secret in Vault
   */
  async updateSecret(path: string, data: Record<string, any>): Promise<void> {
    try {
      await this.vault.setSecret(path, data);
      console.log(`✅ Secret updated in Vault: ${path}`);
      
      // Clear cache to force reload on next access
      this.config = null;
      this.configCacheTime = 0;
    } catch (error) {
      console.error(`❌ Failed to update secret in Vault: ${path}`, error);
      throw error;
    }
  }

  /**
   * Health check for Vault connection
   */
  async healthCheck(): Promise<boolean> {
    try {
      return await this.vault.healthCheck();
    } catch (error) {
      console.error('Vault health check failed:', error);
      return false;
    }
  }

  /**
   * Fallback configuration using environment variables
   */
  private getFallbackConfig(): AuthServiceConfig {
    console.warn('⚠️ Using fallback configuration from environment variables');
    
    return {
      jwtSecret: process.env.JWT_SECRET || 'fallback-secret-change-me',
      sessionTimeout: Number(process.env.SESSION_TIMEOUT) || 1800,
      maxLoginAttempts: Number(process.env.MAX_LOGIN_ATTEMPTS) || 5,
      lockoutDuration: Number(process.env.LOCKOUT_DURATION) || 900,
      googleClientId: process.env.GOOGLE_CLIENT_ID || '',
      googleClientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
      oauthCallbackUrl: process.env.OAUTH_CALLBACK_URL || '',
      redisHost: process.env.REDIS_HOST || 'redis',
      redisPort: Number(process.env.REDIS_PORT) || 6379,
      redisPassword: process.env.REDIS_PASSWORD || '',
    };
  }

  /**
   * Setup automatic token renewal
   */
  private setupTokenRenewal(): void {
    // Renew token every 50 minutes (tokens typically last 1 hour)
    setInterval(async () => {
      try {
        await this.vault.renewToken();
        console.log('🔄 Vault token renewed successfully');
      } catch (error) {
        console.error('❌ Failed to renew Vault token:', error);
      }
    }, 50 * 60 * 1000);
  }
}

// Export singleton instance
export const vaultConfig = new VaultConfigManager();

/**
 * Middleware to inject Vault configuration into Fastify
 */
export async function registerVaultConfig(fastify: any) {
  // Add vault config to fastify instance
  fastify.decorate('vaultConfig', vaultConfig);
  
  // Add health check route for Vault
  fastify.get('/health/vault', async (request: any, reply: any) => {
    const isHealthy = await vaultConfig.healthCheck();
    
    if (isHealthy) {
      reply.code(200).send({ status: 'ok', vault: 'connected' });
    } else {
      reply.code(503).send({ status: 'error', vault: 'disconnected' });
    }
  });
  
  // Preload configuration on startup
  try {
    await vaultConfig.getConfig();
    console.log('🚀 Vault configuration preloaded successfully');
  } catch (error) {
    console.error('⚠️ Failed to preload Vault configuration, will use fallback');
  }
}

export default vaultConfig;
