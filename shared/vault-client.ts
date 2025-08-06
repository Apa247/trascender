import axios, { AxiosInstance } from 'axios';

export interface VaultConfig {
  address: string;
  token: string;
  namespace?: string;
  timeout?: number;
}

export interface VaultSecret {
  [key: string]: string | number | boolean;
}

export interface VaultSecretResponse {
  data: {
    data: VaultSecret;
    metadata: {
      created_time: string;
      deletion_time: string;
      destroyed: boolean;
      version: number;
    };
  };
}

export class VaultClient {
  private client: AxiosInstance;
  private config: VaultConfig;

  constructor(config: VaultConfig) {
    this.config = config;
    this.client = axios.create({
      baseURL: `${config.address}/v1`,
      timeout: config.timeout || 5000,
      headers: {
        'X-Vault-Token': config.token,
        'Content-Type': 'application/json',
        ...(config.namespace && { 'X-Vault-Namespace': config.namespace }),
      },
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        console.error('Vault API Error:', {
          status: error.response?.status,
          statusText: error.response?.statusText,
          data: error.response?.data,
          path: error.config?.url,
        });
        throw error;
      }
    );
  }

  /**
   * Read a secret from Vault KV v2 engine
   */
  async getSecret(path: string): Promise<VaultSecret> {
    try {
      const response = await this.client.get<VaultSecretResponse>(
        `secret/data/${path.replace(/^\//, '')}`
      );
      return response.data.data.data;
    } catch (error) {
      console.error(`Failed to read secret from path: ${path}`, error);
      throw new Error(`Failed to read secret: ${path}`);
    }
  }

  /**
   * Write a secret to Vault KV v2 engine
   */
  async setSecret(path: string, data: VaultSecret): Promise<void> {
    try {
      await this.client.post(`secret/data/${path.replace(/^\//, '')}`, {
        data,
      });
    } catch (error) {
      console.error(`Failed to write secret to path: ${path}`, error);
      throw new Error(`Failed to write secret: ${path}`);
    }
  }

  /**
   * Delete a secret from Vault KV v2 engine
   */
  async deleteSecret(path: string): Promise<void> {
    try {
      await this.client.delete(`secret/metadata/${path.replace(/^\//, '')}`);
    } catch (error) {
      console.error(`Failed to delete secret from path: ${path}`, error);
      throw new Error(`Failed to delete secret: ${path}`);
    }
  }

  /**
   * List secrets at a given path
   */
  async listSecrets(path: string): Promise<string[]> {
    try {
      const response = await this.client.request({
        method: 'LIST',
        url: `secret/metadata/${path.replace(/^\//, '')}`,
      });
      return response.data.data.keys || [];
    } catch (error) {
      console.error(`Failed to list secrets at path: ${path}`, error);
      throw new Error(`Failed to list secrets: ${path}`);
    }
  }

  /**
   * Renew the current token
   */
  async renewToken(): Promise<void> {
    try {
      await this.client.post('auth/token/renew-self');
      console.log('Token renewed successfully');
    } catch (error) {
      console.error('Failed to renew token', error);
      throw new Error('Failed to renew token');
    }
  }

  /**
   * Check token information
   */
  async getTokenInfo(): Promise<any> {
    try {
      const response = await this.client.get('auth/token/lookup-self');
      return response.data.data;
    } catch (error) {
      console.error('Failed to get token info', error);
      throw new Error('Failed to get token info');
    }
  }

  /**
   * Health check for Vault
   */
  async healthCheck(): Promise<boolean> {
    try {
      const response = await axios.get(`${this.config.address}/v1/sys/health`, {
        timeout: 3000,
      });
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }

  /**
   * Get multiple secrets at once
   */
  async getSecrets(paths: string[]): Promise<Record<string, VaultSecret>> {
    const results: Record<string, VaultSecret> = {};
    
    await Promise.all(
      paths.map(async (path) => {
        try {
          results[path] = await this.getSecret(path);
        } catch (error) {
          console.warn(`Failed to get secret for path: ${path}`);
          results[path] = {};
        }
      })
    );

    return results;
  }
}

/**
 * Singleton instance for easy access across the application
 */
let vaultInstance: VaultClient | null = null;

export function initializeVault(config: VaultConfig): VaultClient {
  vaultInstance = new VaultClient(config);
  return vaultInstance;
}

export function getVaultClient(): VaultClient {
  if (!vaultInstance) {
    throw new Error(
      'Vault client not initialized. Call initializeVault() first.'
    );
  }
  return vaultInstance;
}

/**
 * Helper function to get common configuration
 */
export async function getCommonConfig(): Promise<VaultSecret> {
  const vault = getVaultClient();
  return vault.getSecret('common/environment');
}

/**
 * Helper function to get database configuration
 */
export async function getDatabaseConfig(): Promise<VaultSecret> {
  const vault = getVaultClient();
  return vault.getSecret('database/config');
}

/**
 * Helper function to get Redis configuration
 */
export async function getRedisConfig(): Promise<VaultSecret> {
  const vault = getVaultClient();
  return vault.getSecret('redis/config');
}

/**
 * Helper function to get JWT configuration
 */
export async function getJWTConfig(): Promise<VaultSecret> {
  const vault = getVaultClient();
  return vault.getSecret('jwt/config');
}

/**
 * Auto-renewal setup for tokens
 */
export function setupTokenAutoRenewal(intervalMinutes: number = 60): void {
  const vault = getVaultClient();
  
  setInterval(async () => {
    try {
      await vault.renewToken();
      console.log('Token auto-renewed successfully');
    } catch (error) {
      console.error('Failed to auto-renew token:', error);
    }
  }, intervalMinutes * 60 * 1000);
}

export default VaultClient;
