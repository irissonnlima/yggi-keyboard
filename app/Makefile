# Yggi · app do computador. Rode `make help` para ver os comandos.

# O xcodebuild precisa do Xcode completo, mesmo se o xcode-select apontar para as Command Line Tools.
ifneq (,$(findstring CommandLineTools,$(shell xcode-select -p)))
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
endif

BUILD_DIR := build
APP := $(BUILD_DIR)/Build/Products/Debug/Yggi.app
XCODEBUILD := xcodebuild -project macos/Yggi.xcodeproj -scheme Yggi -configuration Debug -derivedDataPath $(BUILD_DIR) -destination "platform=macOS,arch=$(shell uname -m)"

.PHONY: help core universal test check app install run snapshots xcode clean

help: ## mostra os comandos
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

core: ## compila o núcleo em Rust e gera a ponte Swift
	scripts/build-core.sh

universal: ## igual a core, para Apple Silicon e Intel
	scripts/build-core.sh --universal

test: app ## testes do núcleo (Rust) e verificações da camada Swift
	cd core && cargo test --quiet
	$(APP)/Contents/MacOS/Yggi --verificar

check: ## tudo que roda antes de subir: formato, lint, testes, verificações e imagens
	cd core && cargo fmt --check
	cd core && cargo clippy --all-targets --quiet -- -D warnings
	$(MAKE) test
	$(MAKE) snapshots
	@echo "✓ tudo certo para subir"

app: core ## compila o app macOS (Debug)
	$(XCODEBUILD) build -quiet

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
INSTALLED := $(HOME)/Applications/Yggi.app

install: app ## instala em ~/Applications (Dock, Spotlight e Launchpad acham ele lá)
	@pkill -x Yggi || true
	@mkdir -p $(HOME)/Applications
	@rm -rf "$(INSTALLED)"
	@ditto $(APP) "$(INSTALLED)"
	@# Só a cópia instalada fica registrada, para o Dock e o Spotlight não usarem uma velha.
	@$(LSREGISTER) -u $(APP) 2>/dev/null || true
	@touch "$(INSTALLED)" && $(LSREGISTER) -f "$(INSTALLED)"
	@mdimport "$(INSTALLED)" 2>/dev/null || true
	@# A pasta build não entra no Spotlight (senão aparecem dois Yggi).
	@touch $(BUILD_DIR)/.metadata_never_index
	@echo "✓ instalado em $(INSTALLED)"

run: install ## instala e abre o app (Dock e ícone na barra de menus)
	open "$(INSTALLED)"

snapshots: app ## desenha as telas de cada cenário em PNG (build/snapshots)
	$(APP)/Contents/MacOS/Yggi --snapshots $(BUILD_DIR)/snapshots
	@echo "✓ imagens em $(BUILD_DIR)/snapshots"

xcode: core ## gera a ponte e abre o projeto no Xcode
	open macos/Yggi.xcodeproj

clean: ## apaga tudo que foi gerado
	rm -rf $(BUILD_DIR) core/target macos/YggiCore/.build macos/YggiCore/YggiCoreFFI.xcframework macos/YggiCore/Sources/YggiCore/yggi_core.swift
