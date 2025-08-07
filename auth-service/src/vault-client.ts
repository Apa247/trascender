import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();

// ========================================
// CONFIGURACIÓN BÁSICA
// ========================================

const VAULT_URL = process.env.VAULT_ADDR || 'https://vault:8200';
const VAULT_TOKEN = process.env.VAULT_TOKEN || 'dev-token';

// ========================================
// CLIENTE BÁSICO DE VAULT
// ========================================

/**
 * Función simple para hacer peticiones a Vault
 */
async function vaultRequest(path: string, method: string = 'GET', data?: any): Promise<any> {
  const url = `${VAULT_URL}${path}`;
  
  const options: any = {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-Vault-Token': VAULT_TOKEN
    }
  };

  // Ignorar certificados SSL en desarrollo
  if (process.env.VAULT_SKIP_VERIFY === 'true') {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  }

  // Agregar body si hay datos
  if (data) {
    options.body = JSON.stringify(data);
  }

  try {
    console.log(`🔑 Haciendo petición a Vault: ${method} ${path}`);
    const response = await fetch(url, options);
    
    if (!response.ok) {
      console.warn(`⚠️  Error de Vault: ${response.status} ${response.statusText}`);
      return null;
    }

    const result = await response.text();
    return result ? JSON.parse(result) : {};
    
  } catch (error) {
    console.warn(`⚠️  No se pudo conectar con Vault:`, error);
    return null;
  }
}

// ========================================
// FUNCIONES PRINCIPALES
// ========================================

/**
 * Obtiene el JWT secret - primero intenta Vault, luego variables de entorno
 */
export async function getJWTSecret(): Promise<string> {
  console.log('🔍 Buscando JWT secret...');
  
  // Intentar obtener desde Vault
  try {
    const response = await vaultRequest('/v1/secret/data/transcendence/jwt-secret');
    
    if (response?.data?.data?.value) {
      console.log('✅ JWT secret obtenido desde Vault');
      return response.data.data.value;
    }
  } catch (error) {
    console.warn('⚠️  Error obteniendo JWT secret desde Vault:', error);
  }

  // Fallback: usar variable de entorno
  const envSecret = process.env.JWT_SECRET || 'default_secret_key';
  console.log('🔄 Usando JWT secret desde variable de entorno');
  return envSecret;
}

/**
 * Verifica si Vault está disponible
 */
export async function checkVaultHealth(): Promise<boolean> {
  console.log('🏥 Verificando salud de Vault...');
  
  try {
    const response = await fetch(`${VAULT_URL}/v1/sys/health`);
    const isHealthy = response.ok;
    
    if (isHealthy) {
      console.log('✅ Vault está disponible y saludable');
    } else {
      console.warn('⚠️  Vault no está saludable');
    }
    
    return isHealthy;
  } catch (error) {
    console.warn('❌ Vault no está disponible:', error);
    return false;
  }
}

/**
 * Guarda el JWT secret en Vault (para pruebas)
 */
export async function saveJWTSecret(secret: string): Promise<boolean> {
  console.log('💾 Guardando JWT secret en Vault...');
  
  try {
    const response = await vaultRequest('/v1/secret/data/transcendence/jwt-secret', 'POST', {
      data: {
        value: secret
      }
    });
    
    if (response !== null) {
      console.log('✅ JWT secret guardado en Vault');
      return true;
    } else {
      console.warn('⚠️  No se pudo guardar en Vault');
      return false;
    }
  } catch (error) {
    console.error('❌ Error guardando JWT secret en Vault:', error);
    return false;
  }
}

/**
 * Inicializa la conexión con Vault (función principal)
 */
export async function initVault(): Promise<void> {
  console.log('🚀 Inicializando conexión con Vault...');
  
  const isHealthy = await checkVaultHealth();
  
  if (isHealthy) {
    console.log('✅ Vault listo para usar');
  } else {
    console.log('⚠️  Vault no disponible - usando modo fallback');
  }
}

// ========================================
// EXPORTACIÓN POR DEFECTO
// ========================================

export default {
  getJWTSecret,
  checkVaultHealth,
  saveJWTSecret,
  initVault
};
