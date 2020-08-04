CURRENT_UID = $(shell id -u):$(shell id -g)
DIST_DIR ?= $(CURDIR)/dist
REPOSITORY_NAME ?= slides
REPOSITORY_OWNER ?= dduportal
REPOSITORY_BASE_URL ?= https://github.com/$(REPOSITORY_OWNER)/$(REPOSITORY_NAME)

REPOSITORY_URL = $(REPOSITORY_BASE_URL)
PRESENTATION_URL = https://$(REPOSITORY_OWNER).github.io/$(REPOSITORY_NAME)

ifdef TRAVIS_TAG
REPOSITORY_URL = $(REPOSITORY_BASE_URL)/tree/$(TRAVIS_TAG)
PRESENTATION_URL = https://$(REPOSITORY_OWNER).github.io/$(REPOSITORY_NAME)/$(TRAVIS_TAG)
else
ifdef TRAVIS_BRANCH
ifneq ($(TRAVIS_BRANCH), main)
REPOSITORY_URL = $(REPOSITORY_BASE_URL)/tree/$(TRAVIS_BRANCH)
PRESENTATION_URL = https://$(REPOSITORY_OWNER).github.io/$(REPOSITORY_NAME)/$(TRAVIS_BRANCH)
endif
endif
endif
export PRESENTATION_URL CURRENT_UID REPOSITORY_URL REPOSITORY_BASE_URL

all: clean build verify

# Generate documents inside a container, all *.adoc in parallel
build: clean $(DIST_DIR)
	@docker-compose up \
		--build \
		--force-recreate \
		--exit-code-from build \
	build

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

verify:
	@echo "Verify disabled"

serve: clean
	@docker-compose up --build --force-recreate serve

shell:
	@docker-compose up --build --force-recreate -d wait
	@docker-compose exec --user root wait sh

$(DIST_DIR)/index.html: build

pdf: $(DIST_DIR)/index.html
	@docker run --rm -t \
		-v $(DIST_DIR):/slides \
		--user $(CURRENT_UID) \
		astefanutti/decktape:2.9 \
		/slides/index.html \
		/slides/slides.pdf \
		--size='2048x1536'

deploy: pdf
	@bash $(CURDIR)/scripts/travis-gh-deploy.sh

clean:
	@docker-compose down -v --remove-orphans
	@rm -rf $(DIST_DIR)

qrcode:
	@docker-compose up --build --force-recreate qrcode

.PHONY: all build verify serve deploy qrcode pdf
