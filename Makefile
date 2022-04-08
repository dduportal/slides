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
build: clean $(DIST_DIR)
	@docker-compose up \
		--build \
		--force-recreate \
		--exit-code-from build \
	build

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

verify:
	@docker run --rm \
		-v $(DIST_DIR):/dist \
		--user $(CURRENT_UID) \
		18fgsa/html-proofer \
			--check-html \
			--http-status-ignore "999" \
			--url-ignore "/localhost:/,/127.0.0.1:/,/$(PRESENTATION_URL)/,/github.com\/$(REPOSITORY_OWNER)\/slides\/tree/" \
			/dist/index.html

serve: clean $(DIST_DIR) prepare qrcode
	@docker-compose up --build --force-recreate serve

shell: $(DIST_DIR) prepare
	@CURRENT_UID=0 docker-compose run --entrypoint=sh --rm serve

dependencies-lock-update: $(DIST_DIR) prepare
	@CURRENT_UID=0 docker-compose run --entrypoint=npm --rm serve install --package-lock

dependencies-update: $(DIST_DIR) prepare
	@CURRENT_UID=0 docker-compose run --entrypoint=ncu --workdir=/app/npm-packages --rm serve -u
	@make -C $(CURDIR) dependencies-lock-update

$(DIST_DIR)/index.html: build

pdf: $(DIST_DIR)/index.html
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

clean:
	@docker-compose down -v --remove-orphans
	@rm -rf $(DIST_DIR)

qrcode:
	@docker-compose run --entrypoint=/app/node_modules/.bin/qrcode --rm serve -t png -o /app/content/media/qrcode.png $(PRESENTATION_URL)

.PHONY: all build verify serve qrcode pdf prepare dependencies-update dependencies-lock-update
