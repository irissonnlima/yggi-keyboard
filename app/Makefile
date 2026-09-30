# Yggi · app do computador. Rode `make help` para ver os comandos.

# O xcodebuild precisa do Xcode completo, mesmo se o xcode-select apontar para as Command Line Tools.
ifneq (,$(findstring CommandLineTools,$(shell xcode-select -p)))
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
endif

BUILD_DIR := build
APP := $(BUILD_DIR)/Build/Products/Debug/Yggi.app
XCODEBUILD := xcodebuild -project macos/Yggi.xcodeproj -scheme Yggi -configuration Debug -derivedDataPath $(BUILD_DIR) -destination "platform=macOS,arch=$(shell uname -m)"

.PHONY: help core universal test app run snapshots xcode clean

help: ## mostra os comandos
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

core: ## compila o núcleo em Rust e gera a ponte Swift
	scripts/build-core.sh

universal: ## igual a core, para Apple Silicon e Intel
	scripts/build-core.sh --universal

test: ## roda os testes do núcleo
	cd core && cargo test

app: core ## compila o app macOS (Debug)
	$(XCODEBUILD) build -quiet

run: app ## compila e abre o app (ícone na barra de menus)
	@pkill -x Yggi || true
	open $(APP)

snapshots: app ## desenha as telas de cada cenário em PNG (build/snapshots)
	$(APP)/Contents/MacOS/Yggi --snapshots $(BUILD_DIR)/snapshots
	@echo "✓ imagens em $(BUILD_DIR)/snapshots"

xcode: core ## gera a ponte e abre o projeto no Xcode
	open macos/Yggi.xcodeproj

clean: ## apaga tudo que foi gerado
	rm -rf $(BUILD_DIR) core/target macos/YggiCore/.build macos/YggiCore/YggiCoreFFI.xcframework macos/YggiCore/Sources/YggiCore/yggi_core.swift
