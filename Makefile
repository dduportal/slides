CURRENT_UID = $(shell id -u):$(shell id -g)
DIST_DIR ?= $(CURDIR)/dist

REPOSITORY_URL = https://github.com/dduportal/slides
PRESENTATION_URL = https://dduportal.github.io/slides/master

export PRESENTATION_URL CURRENT_UID REPOSITORY_URL

## Docker Buildkit is enabled for faster build and caching of images
DOCKER_BUILDKIT ?= 1
COMPOSE_DOCKER_CLI_BUILD ?= 1
export DOCKER_BUILDKIT COMPOSE_DOCKER_CLI_BUILD

all: clean build verify

# Generate documents inside a container, all *.adoc in parallel
build: clean $(DIST_DIR) ## Generate documents
	@docker-compose up \
		--build \
		--force-recreate \
		--exit-code-from build \
	build

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

verify: ## Verifies the generateed HTML
	@docker run --rm \
		-v $(DIST_DIR):/dist \
		--user $(CURRENT_UID) \
		18fgsa/html-proofer \
			--check-html \
			--http-status-ignore "999" \
			--url-ignore "/localhost:/,/127.0.0.1:/,/$(PRESENTATION_URL)/,/github.com\/$(REPOSITORY_OWNER)\/slides\/tree/" \
			/dist/index.html

serve: clean $(DIST_DIR) prepare qrcode ## Starts a local web server to serve the slides (localhost:8000) 
	@docker-compose up --build --force-recreate serve

shell: $(DIST_DIR) prepare ## Starts the server and opens a shell into it
	@CURRENT_UID=0 docker-compose run --entrypoint=sh --rm serve

dependencies-lock-update: $(DIST_DIR) prepare ## Updates the npm dependencies
	@CURRENT_UID=0 docker-compose run --entrypoint=npm --rm serve install --package-lock

dependencies-update: $(DIST_DIR) prepare ## Updates the dependencies
	@CURRENT_UID=0 docker-compose run --entrypoint=ncu --workdir=/app/npm-packages --rm serve -u
	@make -C $(CURDIR) dependencies-lock-update

$(DIST_DIR)/index.html: build

pdf: $(DIST_DIR)/index.html ## Generate a PDF version of the slides
	@docker run --rm -t \
		-v $(DIST_DIR):/slides \
		--user $(CURRENT_UID) \
		--read-only=true \
		--tmpfs=/tmp \
		astefanutti/decktape:3.4.1 \
		/slides/index.html \
		/slides/slides.pdf \
		--size='2048x1536' \
		--pause 0

clean: ## Clean the docker environment and the output directory
	@docker-compose down -v --remove-orphans
	@rm -rf $(DIST_DIR)

qrcode: ## Generate the QRcode
	@docker-compose run --entrypoint=/app/node_modules/.bin/qrcode --rm serve -t png -o /app/content/media/qrcode.png $(PRESENTATION_URL)

help: ## Display this help screen
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: all build verify serve qrcode pdf prepare dependencies-update dependencies-lock-update
