include .env
-include .env.local

SHELL ?= /bin/bash
DOCKER ?= docker
DOCKER_COMPOSE ?= $(DOCKER) compose
INSIDE_CONTAINER ?= $(shell test -f /.dockerenv && echo 1)

RUN ?= $(if $(INSIDE_CONTAINER),,$(DOCKER_COMPOSE) run --rm php)
COMPOSER ?= $(RUN) composer

##
## Project
## -----

var:
	mkdir var

vendor: composer.json
	if [ -f vendor/.lowest ]; then $(MAKE) install-lowest; else $(MAKE) install-highest; fi

i: install-highest
install-highest: ## Install Composer dependencies
	$(COMPOSER) update
	@rm -f vendor/.lowest
.PHONY: i install-highest

install-lowest: ## Install Composer dependencies
	$(COMPOSER) update --prefer-lowest --prefer-stable
	@touch vendor/.lowest
.PHONY: install-lowest

run: ## Run a command inside the Docker container, e.g. `make run CMD=pwd`
	$(RUN) $(CMD)
.PHONY: run

terminal: var ## Start a terminal inside the Docker container
	@$(if $(INSIDE_CONTAINER),echo 'Already inside docker container.'; exit 1,)
	$(DOCKER_COMPOSE) run --rm php bash
.PHONY: terminal

##
## Tools
## -----

lint: var ## Check code style
	$(RUN) php-cs-fixer fix --diff --verbose --dry-run
	$(RUN) rector process --dry-run
.PHONY: lint

fixcs: var ## Fix code style
	$(RUN) php-cs-fixer fix --diff --verbose
	$(RUN) rector process
.PHONY: fixcs

phpstan: var vendor ## Analyze with PHPStan
	$(RUN) phpstan analyze
.PHONY: phpstan

test: var vendor ## Run tests
	$(RUN) vendor/bin/phpunit
.PHONY: test

infect: var vendor ## Run mutation tests
	$(RUN) infection --show-mutations
.PHONY: infect

composer-validate: ## Validate composer.json
	$(COMPOSER) validate
	$(COMPOSER) normalize --diff --dry-run
.PHONY: composer-validate

composer-normalize: ## Normalize composer.json
	$(COMPOSER) normalize --diff
.PHONY: composer-normalize

deps-analyze: vendor ## Analyze project dependencies
	$(RUN) composer-dependency-analyser
.PHONY: deps-analyze

check: lint phpstan test composer-validate deps-analyze ## Run all project checks

# -----------------------

help:
	@awk ' \
		BEGIN {RS=""; FS="\n"} \
		function printCommand(line) { \
			split(line, command, ":.*?## "); \
        	printf "\033[32m%-28s\033[0m %s\n", command[1], command[2]; \
        } \
		/^[0-9a-zA-Z_-]+: [0-9a-zA-Z_-]+\n[0-9a-zA-Z_-]+: .*?##.*$$/ { \
			split($$1, alias, ": "); \
			sub(alias[2] ":", alias[2] " (" alias[1] "):", $$2); \
			printCommand($$2); \
			next; \
		} \
		$$1 ~ /^[0-9a-zA-Z_-]+: .*?##/ { \
			printCommand($$1); \
			next; \
		} \
		/^##(\n##.*)+$$/ { \
			gsub("## ?", "\033[33m", $$0); \
			print $$0; \
			next; \
		} \
	' $(MAKEFILE_LIST) && printf "\033[0m"
.PHONY: help
.DEFAULT_GOAL := help
