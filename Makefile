COMPOSE = /usr/bin/docker compose -f docker-compose.yml --env-file .env

PROJECT_NAME := transcendence
DATA_PATH ?= $(HOME)/data/$(PROJECT_NAME)
export DATA_PATH
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))

# CONSTRUCCION__________________________________________________________________

all-auto: ip set-ip prepare build vault-setup up

ip:
	@./update_machine_ip.sh
	@./generate_prometheus_config.sh

all: prepare build vault-init up

vault-deploy: prepare build vault-setup up
	@echo "🎉 Vault deployment completed!"
	@echo "🔑 Access Vault UI at: http://localhost:8200/ui"
	@echo "📊 Check services: make show"
	@echo "🔍 Vault status: make vault-status"

prepare:
	mkdir -p "$(HOME)/data/transcendence/sqlite"
	chmod -R 777 "$(HOME)/data/transcendence/sqlite"
	@echo "SQLite data directory prepared at: $(HOME)/data/transcendence/sqlite"

	mkdir -p "$(HOME)/data/transcendence/redis"
	chown -R 1000:1000 "$(HOME)/data/transcendence/redis" || true
	chmod -R 750 "$(HOME)/data/transcendence/redis"
	@echo "Redis data directory prepared at: $(HOME)/data/transcendence/redis"

	mkdir -p "$(HOME)/data/transcendence/frontend"

	mkdir -p "$(HOME)/data/transcendence/prometheus"
	chmod -R 777 "$(HOME)/data/transcendence/prometheus"
	@echo "Prometheus data directory prepared at: $(HOME)/data/transcendence/prometheus"

	mkdir -p "$(HOME)/data/transcendence/grafana"
	chmod -R 777 "$(HOME)/data/transcendence/grafana"
	@echo "Grafana data directory prepared at: $(HOME)/data/transcendence/grafana"

	mkdir -p "$(HOME)/data/transcendence/alertmanager"
	chmod -R 777 "$(HOME)/data/transcendence/alertmanager"
	@echo "Alertmanager data directory prepared at: $(HOME)/data/transcendence/alertmanager"

	mkdir -p "$(HOME)/data/transcendence/vault"
	chmod -R 755 "$(HOME)/data/transcendence/vault"
	@echo "Vault data directory prepared at: $(HOME)/data/transcendence/vault"

	mkdir -p "$(HOME)/data/transcendence/vault-logs"
	chmod -R 755 "$(HOME)/data/transcendence/vault-logs"
	@echo "Vault logs directory prepared at: $(HOME)/data/transcendence/vault-logs"

	@echo "Frontend data directory prepared at: $(HOME)/data/transcendence/frontend"

build:
	@$(COMPOSE) build

up:
	@$(COMPOSE) up -d

show:
	@./show_services.sh

down:
	@$(COMPOSE) down

start:
	@$(COMPOSE) start

stop:
	@$(COMPOSE) stop

shell:
	@bash -c '\
		read -p "=> Enter service: " service; \
		$(COMPOSE) exec -it $$service /bin/bash || $(COMPOSE) exec -it $$service /bin/sh'

# VAULT MANAGEMENT______________________________________________________________
vault-setup:
	@echo "🚀 Setting up Vault..."
	@./setup-vault.sh

vault-init:
	@echo "🔐 Initializing Vault..."
	@./manage-vault.sh init

vault-unseal:
	@echo "🔓 Unsealing Vault..."
	@./manage-vault.sh unseal

vault-seed:
	@echo "🌱 Seeding Vault with secrets..."
	@./manage-vault.sh seed

vault-status:
	@echo "📊 Checking Vault status..."
	@./manage-vault.sh status

vault-ui:
	@echo "🌐 Opening Vault UI..."
	@./manage-vault.sh ui

vault-logs:
	@echo "📋 Showing Vault logs..."
	@./manage-vault.sh logs

vault-renew:
	@echo "🔄 Renewing Vault tokens..."
	@./manage-vault.sh renew

vault-backup:
	@echo "💾 Creating Vault backup..."
	@./manage-vault.sh backup

vault-help:
	@echo "📚 Vault management help:"
	@./manage-vault.sh help

# LIMPIEZA______________________________________________________________________
clean: down

fclean: clean
	@echo "Stopping and removing all containers..."
	@$(COMPOSE) down --volumes --rmi all --remove-orphans 2>/dev/null || true
	@echo "Cleaning up any manually created containers..."
	@docker stop WAF nginx-proxy hashicorp_vault 2>/dev/null || true
	@docker rm WAF nginx-proxy hashicorp_vault 2>/dev/null || true
	@echo "Cleaning up networks..."
	@docker network inspect inception_network > /dev/null 2>&1 && \
	docker network rm inception_network || true
	@docker network inspect transcendence_net > /dev/null 2>&1 && \
	docker network rm transcendence_net || true
	@echo "Pruning volumes..."
	@docker volume prune -f 2>/dev/null || true
	@echo "Cleaning up Vault keys and tokens..."
	@rm -f vault/scripts/vault-keys.json vault/scripts/service-tokens.json .env.tokens .env.generated 2>/dev/null || true
	@echo "Removing data directory..."
	@sudo rm -rf "$(DATA_PATH)"

# REBUILD_______________________________________________________________________
quick-re: clean
	@$(COMPOSE) up -d --force-recreate

re: fclean all

# HELP__________________________________________________________________________
help:
	@echo "🚀 Transcendence Project - Available Commands"
	@echo "=============================================="
	@echo ""
	@echo "📦 BUILD & DEPLOYMENT:"
	@echo "  make all-auto        - Complete setup with IP update and Vault setup"
	@echo "  make all             - Standard build with Vault initialization"
	@echo "  make vault-deploy    - Complete deployment with Vault setup"
	@echo "  make prepare         - Create data directories"
	@echo "  make build           - Build Docker images"
	@echo "  make up              - Start all services"
	@echo ""
	@echo "🔐 VAULT MANAGEMENT:"
	@echo "  make vault-setup     - Complete Vault setup (automated)"
	@echo "  make vault-init      - Initialize Vault (first time)"
	@echo "  make vault-unseal    - Unseal Vault after restart"
	@echo "  make vault-seed      - Populate Vault with secrets"
	@echo "  make vault-status    - Check Vault status"
	@echo "  make vault-ui        - Open Vault web interface"
	@echo "  make vault-logs      - Show Vault logs"
	@echo "  make vault-renew     - Renew service tokens"
	@echo "  make vault-backup    - Create Vault backup"
	@echo "  make vault-help      - Vault-specific help"
	@echo ""
	@echo "🛠️  SERVICE MANAGEMENT:"
	@echo "  make show            - Show running services"
	@echo "  make down            - Stop all services"
	@echo "  make start           - Start stopped services"
	@echo "  make stop            - Stop running services"
	@echo "  make shell           - Interactive shell into service"
	@echo ""
	@echo "🧹 CLEANUP:"
	@echo "  make clean           - Stop services"
	@echo "  make fclean          - Complete cleanup (removes all data)"
	@echo "  make re              - Full rebuild"
	@echo "  make quick-re        - Quick rebuild"
	@echo ""
	@echo "💡 QUICK START:"
	@echo "  make vault-deploy    - One command full deployment"
	@echo "  make vault-status    - Check if everything is running"
	@echo "  make show            - See all services status"

.PHONY: all all-auto build up down start stop shell clean fclean re quick-re prepare set-ip show \
         vault-setup vault-init vault-unseal vault-seed vault-status vault-ui vault-logs \
         vault-renew vault-backup vault-help vault-deploy help
