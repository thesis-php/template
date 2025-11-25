-include .env.local

SHELL ?= /bin/bash
PHP_VERSION ?= 8.3
DOCKER ?= docker
IMAGE ?= ghcr.io/thesis-php/php:$(PHP_VERSION)
RUN_VOLUME ?= --volume .:/app:cached
RUN_USER ?= --user $(shell id -u):$(shell id -g)
RUN ?= $(DOCKER) run $(RUN_USER) $(RUN_VOLUME) --rm --tty $(IMAGE)
COMPOSER ?= $(RUN) composer

##
## Docker
## -----

terminal: ## Start a terminal
	$(DOCKER) run $(RUN_USER) $(RUN_VOLUME) --rm --tty --interactive $(IMAGE) bash
.PHONY: terminal

run: ## Run a command, e.g. `make run CMD=pwd`
	$(RUN) $(CMD)
.PHONY: run

##
## Composer
## -----

var:
	mkdir var

vendor: composer.json composer.lock
	$(COMPOSER) install

i: install
install: vendor ## Install Composer dependencies
.PHONY: i install

u: update
update: ## Update Composer dependencies
	$(COMPOSER) update
.PHONY: u update

##
## Tools
## -----

fixcs: ## Fix code style
	$(RUN) php-cs-fixer fix --diff --verbose
.PHONY: fixcs

phpstan: ## Analyze with PHPStan
	$(RUN) phpstan analyze
.PHONY: phpstan

rector: ## Process code with Rector
	$(RUN) rector process
.PHONY: rector

test: ## Run PHPUnit tests
	$(RUN) vendor/bin/phpunit
.PHONY: test

analyse-deps: ## Fix code style
	$(RUN) composer-dependency-analyser
.PHONY: analyse-deps

# todo infection
# todo composer validate & normalize
# todo check

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
