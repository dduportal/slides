FROM node:16-alpine

## Disable hadolint pinning version: always get latest package as Alpine is used
# hadolint ignore=DL3018
RUN apk add --no-cache \
  curl \
  git \
  tini

# Install App's dependencies (dev and runtime)
COPY ./npm-packages /app/npm-packages
# By creating the symlink, the npm operation are kept at the root of /app
# but the operation can still be executed to the package*.json files without ENOENT error
RUN ln -s /app/npm-packages/package.json /app/package.json \
  && ln -s /app/npm-packages/package-lock.json /app/package-lock.json \
  && ln -s /app/npm-packages/.ncurc.yml /app/.ncurc.yml

WORKDIR /app
RUN npm install
## Link some NPM commands installed as dependencies to be available within the PATH
# There muste be 1 and only 1 `npm link` for each command
RUN npm link gulp \
  && npm link npm-check-updates

COPY ./gulp/tasks /app/tasks
COPY ./gulp/gulpfile.js /app/gulpfile.js

VOLUME ["/app"]

# HTTP
EXPOSE 8000

ENTRYPOINT ["/sbin/tini","-g","gulp"]
CMD ["default"]
