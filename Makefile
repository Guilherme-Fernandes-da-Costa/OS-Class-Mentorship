.PHONY: all setup-docker setup-deps setup-xv6 build-docker run-xv6 create-iso clean help
.DEFAULT_GOAL := help

# Variáveis
DOCKER_IMAGE = xv6-docker
XV6_REPO = https://github.com/mit-pdos/xv6-public.git
XV6_DIR = xv6-public
DISTRO := $(shell lsb_release -si 2>/dev/null || echo "Unknown")

# Cores para output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

all: setup-deps setup-docker setup-xv6 build-docker ## Setup completo (dependências + Docker + xv6)

help: ## Mostrar ajuda
	@echo "$(BLUE)Makefile para Setup Docker + xv6 no Linux$(NC)"
	@echo "$(BLUE)======================================$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

detect-distro: ## Detectar distribuição Linux
	@echo "$(BLUE)Detectando distribuição...$(NC)"
	@if command -v lsb_release > /dev/null 2>&1; then \
		echo "$(GREEN)Distribuição: $(shell lsb_release -si)$(NC)"; \
		echo "$(GREEN)Versão: $(shell lsb_release -sr)$(NC)"; \
	elif [ -f /etc/os-release ]; then \
		echo "$(GREEN)Distribuição: $(shell grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')$(NC)"; \
	else \
		echo "$(RED)Não foi possível detectar a distribuição$(NC)"; \
	fi

check-docker: ## Verificar se Docker está instalado
	@echo "$(BLUE)Verificando Docker...$(NC)"
	@if command -v docker > /dev/null 2>&1; then \
		echo "$(GREEN)Docker encontrado: $(shell docker --version)$(NC)"; \
		if systemctl is-active --quiet docker; then \
			echo "$(GREEN)Docker está rodando$(NC)"; \
		else \
			echo "$(YELLOW)Docker instalado mas não está rodando$(NC)"; \
			sudo systemctl start docker; \
		fi; \
	else \
		echo "$(RED)Docker não encontrado$(NC)"; \
		exit 1; \
	fi

install-docker-ubuntu: ## Instalar Docker no Ubuntu/Debian
	@echo "$(BLUE)Instalando Docker no Ubuntu/Debian...$(NC)"
	@sudo apt-get update
	@sudo apt-get install -y ca-certificates curl gnupg lsb-release
	@sudo mkdir -m 0755 -p /etc/apt/keyrings
	@if [ ! -f /etc/apt/keyrings/docker.gpg ]; then \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
	fi
	@echo "deb [arch=$(shell dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(shell lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	@sudo apt-get update
	@sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	@sudo systemctl enable docker
	@sudo systemctl start docker
	@sudo usermod -aG docker $$USER
	@echo "$(GREEN)Docker instalado com sucesso!$(NC)"
	@echo "$(YELLOW)IMPORTANTE: Faça logout e login novamente para usar Docker sem sudo$(NC)"

install-docker-fedora: ## Instalar Docker no Fedora/RHEL
	@echo "$(BLUE)Instalando Docker no Fedora/RHEL...$(NC)"
	@sudo dnf -y install dnf-plugins-core
	@sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
	@sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	@sudo systemctl enable docker
	@sudo systemctl start docker
	@sudo usermod -aG docker $$USER
	@echo "$(GREEN)Docker instalado com sucesso!$(NC)"

install-docker-arch: ## Instalar Docker no Arch Linux
	@echo "$(BLUE)Instalando Docker no Arch Linux...$(NC)"
	@sudo pacman -Sy --needed --noconfirm docker docker-compose
	@sudo systemctl enable docker
	@sudo systemctl start docker
	@sudo usermod -aG docker $$USER
	@echo "$(GREEN)Docker instalado com sucesso!$(NC)"

setup-docker: detect-distro ## Setup Docker baseado na distribuição
	@if command -v docker > /dev/null 2>&1; then \
		echo "$(GREEN)Docker já está instalado$(NC)"; \
		make check-docker; \
	else \
		if [ -f /etc/debian_version ]; then \
			make install-docker-ubuntu; \
		elif [ -f /etc/redhat-release ]; then \
			make install-docker-fedora; \
		elif [ -f /etc/arch-release ]; then \
			make install-docker-arch; \
		else \
			echo "$(RED)Distribuição não suportada. Instale Docker manualmente.$(NC)"; \
			exit 1; \
		fi; \
	fi

setup-deps: ## Instalar dependências gerais
	@echo "$(BLUE)Instalando dependências...$(NC)"
	@if [ -f /etc/debian_version ]; then \
		sudo apt-get update; \
		sudo apt-get install -y git make curl wget qemu-system-x86 build-essential; \
	elif [ -f /etc/redhat-release ]; then \
		sudo dnf install -y git make curl wget qemu-system-x86 gcc gcc-c++; \
	elif [ -f /etc/arch-release ]; then \
		sudo pacman -Sy --needed --noconfirm git make curl wget qemu base-devel; \
	fi
	@echo "$(GREEN)Dependências instaladas!$(NC)"

setup-xv6: ## Baixar/atualizar código fonte do xv6
	@echo "$(BLUE)Configurando xv6...$(NC)"
	@if [ -d $(XV6_DIR) ]; then \
		echo "$(YELLOW)xv6 já existe. Atualizando...$(NC)"; \
		cd $(XV6_DIR) && git pull; \
	else \
		echo "$(GREEN)Clonando xv6...$(NC)"; \
		git clone $(XV6_REPO) $(XV6_DIR); \
	fi
	@echo "$(GREEN)xv6 configurado!$(NC)"

build-docker: setup-xv6 ## Construir imagem Docker do xv6
	@echo "$(BLUE)Construindo imagem Docker...$(NC)"
	@cd $(XV6_DIR) && cat > Dockerfile << 'EOF'
FROM ubuntu:20.04

# Definir timezone para evitar interação
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo

# Configurar timezone
RUN ln -snf /usr/share/zoneinfo/$$TZ /etc/localtime && echo $$TZ > /etc/timezone

# Instalar pacotes
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-multilib \
    qemu-system-x86 \
    gdb \
    tmux \
    genisoimage \
    syslinux-utils \
    syslinux-common \
    isolinux \
    mtools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /xv6-public
CMD ["bash"]
EOF
	@cd $(XV6_DIR) && docker build -t $(DOCKER_IMAGE) .
	@echo "$(GREEN)Imagem Docker construída!$(NC)"

run-xv6: ## Executar xv6 no container Docker
	@echo "$(BLUE)Executando xv6...$(NC)"
	@echo "$(YELLOW)Comandos úteis no xv6: ls, cat README, echo hello$(NC)"
	@echo "$(YELLOW)Para sair do xv6: Ctrl+A depois x$(NC)"
	@echo "$(YELLOW)Para sair do container: digite 'exit'$(NC)"
	@cd $(XV6_DIR) && docker run --rm -it -v $$(pwd):/xv6-public $(DOCKER_IMAGE) bash -c "make clean && make && echo '$(GREEN)xv6 compilado! Execute: make qemu-nox$(NC)' && bash"

create-iso: ## Criar ISO inicializável do xv6
	@echo "$(BLUE)Criando ISO do xv6...$(NC)"
	@cd $(XV6_DIR) && docker run --rm -it -v $$(pwd):/xv6-public $(DOCKER_IMAGE) bash -c '\
		make clean && make && \
		mkdir -p /iso/boot/{isolinux,xv6} && \
		cp xv6.img /iso/boot/xv6/vmlinuz && \
		cp fs.img /iso/boot/xv6/initrd.img && \
		cp /usr/lib/ISOLINUX/isolinux.bin /iso/boot/isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/*.c32 /iso/boot/isolinux/ 2>/dev/null || true && \
		cat > /iso/boot/isolinux/isolinux.cfg << "EOFCFG" \
DEFAULT menu.c32\
TIMEOUT 300\
MENU TITLE xv6 Operating System\
\
LABEL xv6\
    MENU LABEL Boot xv6\
    KERNEL /boot/xv6/vmlinuz\
    APPEND initrd=/boot/xv6/initrd.img console=ttyS0\
EOFCFG\
		genisoimage -r -V "XV6-OS" -cache-inodes -J -l \
			-b boot/isolinux/isolinux.bin \
			-c boot/isolinux/boot.cat \
			-no-emul-boot -boot-load-size 4 -boot-info-table \
			-o /xv6-public/xv6-bootable.iso /iso && \
		echo "$(GREEN)ISO criado: xv6-bootable.iso$(NC)"'

test-iso: ## Testar ISO no QEMU
	@echo "$(BLUE)Testando ISO...$(NC)"
	@echo "$(YELLOW)Para sair: Ctrl+A depois x$(NC)"
	@cd $(XV6_DIR) && qemu-system-x86_64 -cdrom xv6-bootable.iso -nographic

clean: ## Limpar arquivos temporários
	@echo "$(BLUE)Limpando...$(NC)"
	@if [ -d $(XV6_DIR) ]; then \
		cd $(XV6_DIR) && make clean 2>/dev/null || true; \
		rm -f xv6-bootable.iso; \
	fi
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)Limpeza concluída!$(NC)"

status: ## Mostrar status do sistema
	@echo "$(BLUE)Status do Sistema$(NC)"
	@echo "$(BLUE)=================$(NC)"
	@echo -n "Docker: "
	@if command -v docker > /dev/null 2>&1; then \
		echo "$(GREEN)✓ Instalado $(shell docker --version | cut -d' ' -f3)$(NC)"; \
		if systemctl is-active --quiet docker; then \
			echo "        $(GREEN)✓ Rodando$(NC)"; \
		else \
			echo "        $(RED)✗ Parado$(NC)"; \
		fi; \
	else \
		echo "$(RED)✗ Não instalado$(NC)"; \
	fi
	@echo -n "Git: "
	@if command -v git > /dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell git --version)$(NC)"; \
	else \
		echo "$(RED)✗ Não instalado$(NC)"; \
	fi
	@echo -n "QEMU: "
	@if command -v qemu-system-x86_64 > /dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell qemu-system-x86_64 --version | head -n1)$(NC)"; \
	else \
		echo "$(RED)✗ Não instalado$(NC)"; \
	fi
	@echo -n "xv6: "
	@if [ -d $(XV6_DIR) ]; then \
		echo "$(GREEN)✓ Disponível em $(XV6_DIR)$(NC)"; \
	else \
		echo "$(RED)✗ Não baixado$(NC)"; \
	fi
	@echo -n "Docker Image: "
	@if docker images -q $(DOCKER_IMAGE) | grep -q .; then \
		echo "$(GREEN)✓ $(DOCKER_IMAGE) construída$(NC)"; \
	else \
		echo "$(RED)✗ Não construída$(NC)"; \
	fi

# ============================================================================
# Makefile para Windows (PowerShell/WSL2)
# Setup automático Docker + xv6
# ============================================================================

.PHONY: all-win setup-wsl setup-docker-win setup-deps-win setup-xv6-win build-docker-win run-xv6-win create-iso-win clean-win help-win

all-win: setup-wsl setup-docker-win setup-deps-win setup-xv6-win build-docker-win ## Setup completo Windows

help-win: ## Mostrar ajuda Windows
	@echo "$(BLUE)Makefile para Setup Docker + xv6 no Windows$(NC)"
	@echo "$(BLUE)===========================================$(NC)"
	@echo "$(YELLOW)Prerequisites:$(NC)"
	@echo "  - Windows 10/11 versão 1903 ou superior"
	@echo "  - WSL2 habilitado"
	@echo "  - PowerShell como Administrador"
	@echo ""
	@grep -E '^[a-zA-Z_-]+.*:.*?## .*$$' $(MAKEFILE_LIST) | grep -E 'win:|setup-wsl' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

check-wsl: ## Verificar se WSL2 está disponível
	@echo "$(BLUE)Verificando WSL2...$(NC)"
	@powershell.exe -Command "if (Get-Command wsl -ErrorAction SilentlyContinue) { Write-Host 'WSL encontrado' -ForegroundColor Green; wsl --status } else { Write-Host 'WSL não encontrado' -ForegroundColor Red; exit 1 }"

setup-wsl: ## Instalar/configurar WSL2 com Ubuntu
	@echo "$(BLUE)Configurando WSL2...$(NC)"
	@powershell.exe -Command "\
		if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 'Enabled') { \
			Write-Host 'Habilitando WSL...' -ForegroundColor Yellow; \
			dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart; \
		}; \
		if (-not (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -eq 'Enabled') { \
			Write-Host 'Habilitando Virtual Machine Platform...' -ForegroundColor Yellow; \
			dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart; \
		}; \
		Write-Host 'Definindo WSL2 como versão padrão...' -ForegroundColor Yellow; \
		wsl --set-default-version 2; \
		if (-not (wsl -l -q | Select-String 'Ubuntu')) { \
			Write-Host 'Instalando Ubuntu...' -ForegroundColor Yellow; \
			wsl --install -d Ubuntu; \
		} else { \
			Write-Host 'Ubuntu já está instalado' -ForegroundColor Green; \
		}"
	@echo "$(YELLOW)IMPORTANTE: Se WSL foi instalado agora, reinicie o computador!$(NC)"

setup-docker-win: check-wsl ## Instalar Docker Desktop no Windows
	@echo "$(BLUE)Verificando Docker Desktop...$(NC)"
	@powershell.exe -Command "\
		if (Get-Command docker -ErrorAction SilentlyContinue) { \
			Write-Host 'Docker já está instalado' -ForegroundColor Green; \
			docker --version; \
		} else { \
			Write-Host 'Baixando Docker Desktop...' -ForegroundColor Yellow; \
			$$url = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'; \
			$$output = '$$env:TEMP\DockerDesktopInstaller.exe'; \
			Invoke-WebRequest -Uri $$url -OutFile $$output; \
			Write-Host 'Instalando Docker Desktop...' -ForegroundColor Yellow; \
			Start-Process -FilePath $$output -ArgumentList 'install --quiet' -Wait; \
			Write-Host 'Docker Desktop instalado!' -ForegroundColor Green; \
		}"
	@echo "$(YELLOW)IMPORTANTE: Inicie o Docker Desktop e configure integração com WSL2$(NC)"

setup-deps-win: ## Instalar dependências no WSL2
	@echo "$(BLUE)Instalando dependências no WSL2...$(NC)"
	@wsl -d Ubuntu -- bash -c "\
		sudo apt-get update && \
		sudo apt-get install -y git make curl wget qemu-system-x86 build-essential && \
		echo 'Dependências instaladas no WSL2!'"

setup-xv6-win: ## Configurar xv6 no WSL2
	@echo "$(BLUE)Configurando xv6 no WSL2...$(NC)"
	@wsl -d Ubuntu -- bash -c "\
		if [ -d xv6-public ]; then \
			echo 'xv6 já existe. Atualizando...'; \
			cd xv6-public && git pull; \
		else \
			echo 'Clonando xv6...'; \
			git clone https://github.com/mit-pdos/xv6-public.git; \
		fi"

build-docker-win: ## Construir imagem Docker no WSL2
	@echo "$(BLUE)Construindo imagem Docker no WSL2...$(NC)"
	@wsl -d Ubuntu -- bash -c "\
		cd xv6-public && \
		cat > Dockerfile << 'EOF' \
FROM ubuntu:20.04\
\
ENV DEBIAN_FRONTEND=noninteractive\
ENV TZ=America/Sao_Paulo\
\
RUN ln -snf /usr/share/zoneinfo/\$$TZ /etc/localtime && echo \$$TZ > /etc/timezone\
\
RUN apt-get update && apt-get install -y \\\
    build-essential \\\
    gcc-multilib \\\
    qemu-system-x86 \\\
    gdb \\\
    tmux \\\
    genisoimage \\\
    syslinux-utils \\\
    syslinux-common \\\
    isolinux \\\
    mtools \\\
    && rm -rf /var/lib/apt/lists/*\
\
WORKDIR /xv6-public\
CMD [\"bash\"]\
EOF\
		docker build -t xv6-docker ."

run-xv6-win: ## Executar xv6 no WSL2
	@echo "$(BLUE)Executando xv6 no WSL2...$(NC)"
	@echo "$(YELLOW)Para sair do xv6: Ctrl+A depois x$(NC)"
	@wsl -d Ubuntu -- bash -c "\
		cd xv6-public && \
		docker run --rm -it -v \$$(pwd):/xv6-public xv6-docker bash -c '\
			make clean && make && \
			echo \"xv6 compilado! Execute: make qemu-nox\" && \
			bash'"

create-iso-win: ## Criar ISO no WSL2
	@echo "$(BLUE)Criando ISO no WSL2...$(NC)"
	@wsl -d Ubuntu -- bash -c "\
		cd xv6-public && \
		docker run --rm -it -v \$$(pwd):/xv6-public xv6-docker bash -c '\
			make clean && make && \
			mkdir -p /iso/boot/{isolinux,xv6} && \
			cp xv6.img /iso/boot/xv6/vmlinuz && \
			cp fs.img /iso/boot/xv6/initrd.img && \
			cp /usr/lib/ISOLINUX/isolinux.bin /iso/boot/isolinux/ && \
			cp /usr/lib/syslinux/modules/bios/*.c32 /iso/boot/isolinux/ 2>/dev/null || true && \
			cat > /iso/boot/isolinux/isolinux.cfg << \"EOFCFG\" \
DEFAULT menu.c32\
TIMEOUT 300\
MENU TITLE xv6 Operating System\
\
LABEL xv6\
    MENU LABEL Boot xv6\
    KERNEL /boot/xv6/vmlinuz\
    APPEND initrd=/boot/xv6/initrd.img console=ttyS0\
EOFCFG\
			genisoimage -r -V \"XV6-OS\" -cache-inodes -J -l \
				-b boot/isolinux/isolinux.bin \
				-c boot/isolinux/boot.cat \
				-no-emul-boot -boot-load-size 4 -boot-info-table \
				-o /xv6-public/xv6-bootable.iso /iso && \
			echo \"ISO criado: xv6-bootable.iso\"'"

test-iso-win: ## Testar ISO no WSL2
	@echo "$(BLUE)Testando ISO no WSL2...$(NC)"
	@wsl -d Ubuntu -- bash -c "cd xv6-public && qemu-system-x86_64 -cdrom xv6-bootable.iso -nographic"

clean-win: ## Limpar no WSL2
	@echo "$(BLUE)Limpando WSL2...$(NC)"
	@wsl -d Ubuntu -- bash -c "\
		if [ -d xv6-public ]; then \
			cd xv6-public && make clean 2>/dev/null || true; \
			rm -f xv6-bootable.iso; \
		fi; \
		docker rmi xv6-docker 2>/dev/null || true"

status-win: ## Status do sistema Windows
	@echo "$(BLUE)Status do Sistema Windows$(NC)"
	@echo "$(BLUE)=========================$(NC)"
	@powershell.exe -Command "\
		Write-Host -NoNewline 'WSL2: '; \
		if (Get-Command wsl -ErrorAction SilentlyContinue) { \
			Write-Host '✓ Instalado' -ForegroundColor Green; \
			wsl --list --verbose; \
		} else { \
			Write-Host '✗ Não instalado' -ForegroundColor Red; \
		}; \
		Write-Host -NoNewline 'Docker Desktop: '; \
		if (Get-Command docker -ErrorAction SilentlyContinue) { \
			Write-Host '✓ Instalado' -ForegroundColor Green; \
			docker --version; \
		} else { \
			Write-Host '✗ Não instalado' -ForegroundColor Red; \
		}"
