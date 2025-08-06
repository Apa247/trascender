# 🔐 HashiCorp Vault - Guía de Inicio Rápido
## Proyecto Trascender

### 🎯 ¿Qué es Vault?

HashiCorp Vault es tu **caja fuerte digital** que centraliza y protege todos los secretos de tu aplicación: contraseñas, tokens, claves API, certificados, y cualquier información sensible.

**¿Por qué usar Vault?**
- ✅ **Seguridad centralizada**: Todos los secretos en un lugar seguro
- ✅ **Control de acceso**: Cada servicio solo accede a lo que necesita
- ✅ **Rotación automática**: Cambio periódico de credenciales
- ✅ **Auditoría completa**: Registro de quién accede a qué
- ✅ **Cifrado**: Datos protegidos en reposo y en tránsito

### ⚡ Instalación Express (3 minutos)

```bash
# 1. Clonar el proyecto (si no lo tienes)
git clone <tu-repo>
cd trascender

# 2. ¡UN SOLO COMANDO! Despliegue completo con Vault
make vault-deploy

# 3. ¡Listo! Todo funcionando incluyendo Vault
```

### 🎛️ Instalación Alternativa (Paso a Paso)

```bash
# Si prefieres control manual:
./setup-vault.sh         # O usar: make vault-setup
make show                # Verificar servicios
```

### 🚀 Uso Diario

#### ⭐ Comandos Make (Recomendados)
```bash
# 🎯 COMANDOS MÁS USADOS
make vault-status        # Ver estado de Vault y servicios
make vault-ui            # Abrir interfaz web
make vault-renew         # Renovar tokens
make show                # Ver todos los servicios corriendo

# 🔧 GESTIÓN COMPLETA
make vault-deploy        # Despliegue completo (primera vez)
make vault-unseal        # Desbloquear Vault si está sellado
make vault-backup        # Crear respaldo de Vault
make help                # Ver TODOS los comandos disponibles
```

#### 🔧 Comandos Scripts (Alternativos)
```bash
# Si prefieres usar scripts directos:
./manage-vault.sh status # Ver estado de Vault
./manage-vault.sh ui     # Abrir interfaz web
./manage-vault.sh renew  # Renovar tokens
./manage-vault.sh logs   # Ver logs si hay problemas
```

#### 📋 Acceso a la Interfaz Web
1. Ejecuta: `make vault-ui` (o `./manage-vault.sh ui`)
2. Usa el token root desde: `vault/scripts/service-tokens.json`
3. Explora los secretos en: `secret/` 

### 🔑 Estructura de Secretos

Tu información está organizada así:
```
📁 secret/
├── 🌍 common/          # Configuración compartida
├── 🗄️ database/        # Configuración de base de datos  
├── 🔴 redis/           # Configuración de Redis
├── 🎫 jwt/             # Configuración de tokens JWT
├── 👤 auth-service/    # Secretos de autenticación
├── 🎮 game-service/    # Secretos del juego
├── 💬 chat-service/    # Secretos del chat
├── 📊 db-service/      # Secretos de base de datos
├── 🌐 api-gateway/     # Secretos del gateway
└── 📈 monitoring/      # Secretos de monitoreo
```

### 🛠️ Integración en Código

#### Para servicios TypeScript/Node.js:

```typescript
// 1. Importar cliente Vault
import { vaultConfig } from './vault-integration';

// 2. Obtener configuración
const config = await vaultConfig.getConfig();
console.log('JWT Secret:', config.jwtSecret);

// 3. Obtener valor específico
const redisPassword = await vaultConfig.getConfigValue('redisPassword');

// 4. Actualizar secreto
await vaultConfig.updateSecret('auth-service/config', {
    nueva_clave: 'valor-secreto'
});
```

#### Variables de Entorno por Servicio:

```bash
# Auth Service
VAULT_TOKEN=auth_service_token_aqui

# Game Service  
VAULT_TOKEN=game_service_token_aqui

# Chat Service
VAULT_TOKEN=chat_service_token_aqui
```

### 🔄 Flujo de Trabajo

#### ⚡ Con Comandos Make (Recomendado)
```bash
# 🚀 PRIMERA VEZ
make vault-deploy        # Instala y configura todo automáticamente

# 📅 USO DIARIO
make up                  # Iniciar todos los servicios
make vault-status        # Verificar estado de Vault
make show                # Ver servicios corriendo

# 🔧 SI HAY PROBLEMAS
make vault-unseal        # Si Vault está bloqueado
make vault-renew         # Si tokens expiran
make vault-logs          # Ver logs de Vault
```

#### 🔄 Desarrollo Tradicional (Scripts)
1. **Iniciar**: `docker-compose up -d`
2. **Si Vault está bloqueado**: `./manage-vault.sh unseal`
3. **Desarrollar normalmente** - los servicios obtienen secretos automáticamente
4. **Renovar tokens**: `./manage-vault.sh renew` (o automático)

#### Agregar Nuevos Secretos
1. **Via Web UI**: Ir a http://localhost:8200/ui → secret/ → Crear
2. **Via CLI**:
   ```bash
   docker exec -it hashicorp_vault sh
   vault kv put secret/mi-servicio/config nuevo_secreto="valor"
   ```

#### Actualizar Secretos Existentes
1. **Via Web UI**: Navegar al secreto → Edit
2. **Via código**: Usar `vaultConfig.updateSecret()`

### 🆘 Solución de Problemas

#### ⚡ Con Make (Más Simple)
```bash
# Problema: "Vault is sealed"
make vault-unseal

# Problema: "Permission denied" (tokens expirados)
make vault-renew

# Problema: Vault no responde
make vault-logs          # Ver logs
docker-compose restart vault
make vault-unseal

# Ver estado general
make vault-status
make show
```

#### 🔧 Con Scripts (Tradicional)
```bash
# Problema: "Vault is sealed"
./manage-vault.sh unseal

# Problema: "Permission denied" 
./manage-vault.sh renew

# Verificar que los secretos existen:
docker exec hashicorp_vault vault kv list secret/

# Verificar tokens de servicio:
cat vault/scripts/service-tokens.json

# Problema: Vault no responde
docker ps | grep vault
docker logs hashicorp_vault
docker-compose restart vault
./manage-vault.sh unseal
```

### 💡 Tips y Mejores Prácticas

#### ✅ Hacer Siempre
- Usar `make help` para ver todos los comandos
- Renovar tokens: `make vault-renew` (o automático)
- Hacer backup: `make vault-backup`
- Verificar estado: `make vault-status` antes de desarrollar
- Usar la UI web para explorar secretos: `make vault-ui`

#### ❌ Nunca Hacer
- Compartir el token root
- Dejar tokens en código fuente
- Eliminar `vault-keys.json` sin backup
- Usar secretos hardcodeados en desarrollo

#### 🔄 Automatización Recomendada
```bash
# Opción 1: Con Make (Recomendado)
crontab -e
# Agregar: 0 2 * * * cd /ruta/a/trascender && make vault-renew

# Opción 2: Con script directo
crontab -e
# Agregar: 0 2 * * * /ruta/a/manage-vault.sh renew
```

### 📊 Monitoreo

#### Health Checks
- **Vault**: http://localhost:8200/v1/sys/health
- **Servicios**: http://localhost:8001/health/vault

#### Métricas
- Vault expone métricas para Prometheus
- Grafana dashboards incluidos en monitoring/

### 🎓 Para Aprender Más

#### Comandos Útiles
```bash
# Explorar Vault CLI
docker exec -it hashicorp_vault sh

# Ver todas las políticas
vault policy list

# Información del token actual
vault token lookup

# Listar secretos
vault kv list secret/
vault kv get secret/jwt/config
```

#### Archivos Importantes
- `vault/README.md` - Documentación completa
- `vault/scripts/service-tokens.json` - Tokens de servicios
- `vault/scripts/vault-keys.json` - Claves de desbloqueo
- `.env.tokens` - Variables de entorno con tokens

### 🎉 ¡Ya estás listo!

Con Vault configurado, tu aplicación es más segura y profesional. Los secretos están centralizados, protegidos y cada servicio solo accede a lo que necesita.

**Próximos pasos:**
1. Explora la UI web: `make vault-ui`
2. Integra Vault en tus servicios usando los ejemplos
3. Configura renovación automática de tokens
4. Haz backups regulares: `make vault-backup`

**¿Necesitas ayuda?**
- Ejecuta: `make help` (comandos completos)
- Ejecuta: `make vault-help` (solo Vault)
- Revisa: `vault/README.md` (documentación técnica)
- Verifica logs: `make vault-logs`

### 🎯 Comandos de Referencia Rápida

```bash
# 🚀 DESPLIEGUE
make vault-deploy        # Todo en uno (primera vez)
make all-auto           # Con actualización de IP

# 📊 MONITOREO  
make vault-status       # Estado de Vault
make show              # Todos los servicios
make vault-ui          # Interfaz web

# 🔧 MANTENIMIENTO
make vault-renew       # Renovar tokens
make vault-backup      # Crear backup
make vault-unseal      # Desbloquear

# 📚 AYUDA
make help             # Todos los comandos
make vault-help       # Solo comandos Vault
```

---
🔐 **Vault = Seguridad sin complicaciones** 🔐
