# openclaw-skills Makefile
# Orchestration layer for SwiftPM-based skill packages.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# ── Skill → Package mapping ────────────────────────────────────────────────────
# Add new skills here: SKILL_<name> = package_dir:binary_name
SKILL_notion-task-skill := ntask:ntask

# Derived lists
SKILLS := notion-task-skill
PACKAGES := ntask

# Skill binary map for shell iteration (skill:binary)
SKILL_BINARIES := notion-task-skill:ntask

# ── Paths ───────────────────────────────────────────────────────────────────────
REPO_ROOT := $(shell pwd)
PACKAGES_DIR := $(REPO_ROOT)/packages
SKILLS_DIR := $(REPO_ROOT)/skills

# ── Build ───────────────────────────────────────────────────────────────────────

.PHONY: build
build: check-swift ## Build a single skill (usage: make build SKILL=notion-task-skill)
ifndef SKILL
	$(error SKILL is required. Usage: make build SKILL=notion-task-skill)
endif
	$(eval MAPPING := $(SKILL_$(SKILL)))
	$(eval PKG := $(word 1,$(subst :, ,$(MAPPING))))
	$(eval BIN := $(word 2,$(subst :, ,$(MAPPING))))
	@if [ -z "$(PKG)" ]; then echo "ERROR: Unknown skill '$(SKILL)'"; exit 1; fi
	@echo "Building $(PKG) (release)..."
	@swift build -c release --package-path $(PACKAGES_DIR)/$(PKG)
	@mkdir -p $(SKILLS_DIR)/$(SKILL)/bin
	@cp $(PACKAGES_DIR)/$(PKG)/.build/release/$(BIN) $(SKILLS_DIR)/$(SKILL)/bin/$(BIN)
	@chmod +x $(SKILLS_DIR)/$(SKILL)/bin/$(BIN)
	@echo "✅ Installed $(BIN) → skills/$(SKILL)/bin/$(BIN)"

.PHONY: build-all
build-all: check-swift ## Build all skills
	@for skill in $(SKILLS); do \
		$(MAKE) --no-print-directory build SKILL=$$skill || exit 1; \
	done
	@echo "✅ All skills built"

# ── Test ────────────────────────────────────────────────────────────────────────

.PHONY: test
test: check-swift ## Run all package tests
	@for pkg in $(PACKAGES); do \
		echo "━━━ Testing $$pkg ━━━"; \
		swift test --package-path $(PACKAGES_DIR)/$$pkg || exit 1; \
		echo ""; \
	done

.PHONY: test-pkg
test-pkg: check-swift ## Run tests for one package (usage: make test-pkg PKG=ntask)
ifndef PKG
	$(error PKG is required. Usage: make test-pkg PKG=ntask)
endif
	swift test --package-path $(PACKAGES_DIR)/$(PKG)

# ── Guard ───────────────────────────────────────────────────────────────────────

.PHONY: check-swift
check-swift:
	@command -v swift >/dev/null 2>&1 || { echo "❌ swift not found. Install Swift 6.1+ from https://swift.org/install"; exit 1; }

# ── Doctor ──────────────────────────────────────────────────────────────────────

.PHONY: doctor
doctor: ## Verify development environment
	@ERRORS=0; \
	echo "Checking development environment..."; \
	echo ""; \
	echo "Tools:"; \
	if command -v swift >/dev/null 2>&1; then \
		echo "  ✅ swift $$(swift --version 2>&1 | head -1)"; \
	else \
		echo "  ❌ swift not found (install from https://swift.org/install)"; \
		ERRORS=$$((ERRORS + 1)); \
	fi; \
	if command -v make >/dev/null 2>&1; then \
		echo "  ✅ make found"; \
	else \
		echo "  ❌ make not found"; \
		ERRORS=$$((ERRORS + 1)); \
	fi; \
	echo ""; \
	echo "Optional tools:"; \
	if command -v notion >/dev/null 2>&1; then \
		echo "  ✅ notion found ($$(notion --version 2>/dev/null || echo 'unknown'))"; \
	else \
		echo "  ⚠️  notion not found (needed at runtime, not for building)"; \
	fi; \
	echo ""; \
	echo "Repository structure:"; \
	if [ -d "$(SKILLS_DIR)" ]; then echo "  ✅ skills/ exists"; else echo "  ❌ skills/ missing"; ERRORS=$$((ERRORS + 1)); fi; \
	if [ -d "$(PACKAGES_DIR)" ]; then echo "  ✅ packages/ exists"; else echo "  ❌ packages/ missing"; ERRORS=$$((ERRORS + 1)); fi; \
	echo ""; \
	echo "Skill binaries:"; \
	for entry in $(SKILL_BINARIES); do \
		skill=$$(echo "$$entry" | cut -d: -f1); \
		bin=$$(echo "$$entry" | cut -d: -f2); \
		if [ -x "$(SKILLS_DIR)/$$skill/bin/$$bin" ]; then \
			echo "  ✅ $$skill → bin/$$bin (built)"; \
		else \
			echo "  ⚠️  $$skill → bin/$$bin (not built — run make build-all)"; \
		fi; \
	done; \
	echo ""; \
	if [ $$ERRORS -eq 0 ]; then \
		echo "✅ Doctor complete"; \
	else \
		echo "❌ Found $$ERRORS issue(s)"; \
		exit 1; \
	fi

# ── Install ─────────────────────────────────────────────────────────────────────

.PHONY: install
install: build-all ## Install skills into a workspace (usage: make install WORKSPACE=/path [MODE=symlink|copy])
ifndef WORKSPACE
	$(error WORKSPACE is required. Usage: make install WORKSPACE=/path/to/workspace)
endif
	$(eval MODE ?= copy)
	@mkdir -p $(WORKSPACE)/skills
	@for skill in $(SKILLS); do \
		src=$(SKILLS_DIR)/$$skill; \
		dst=$(WORKSPACE)/skills/$$skill; \
		if [ ! -f "$$src/SKILL.md" ]; then continue; fi; \
		if [ "$(MODE)" = "symlink" ]; then \
			rm -rf "$$dst"; \
			ln -s "$$src" "$$dst"; \
			echo "  🔗 $$skill → symlinked"; \
		else \
			rm -rf "$$dst"; \
			cp -R "$$src" "$$dst"; \
			echo "  📦 $$skill → copied"; \
		fi; \
	done
	@echo "✅ Skills installed into $(WORKSPACE)/skills (mode: $(MODE))"

# ── Clean ───────────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Remove all build artifacts
	@for pkg in $(PACKAGES); do \
		echo "Cleaning $$pkg..."; \
		rm -rf $(PACKAGES_DIR)/$$pkg/.build; \
	done
	@for skill in $(SKILLS); do \
		rm -f $(SKILLS_DIR)/$$skill/bin/*; \
	done
	@echo "✅ Clean"

# ── Help ────────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@echo "openclaw-skills — build & manage agent skills"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Skills: $(SKILLS)"
	@echo "Packages: $(PACKAGES)"
