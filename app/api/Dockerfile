# Placeholder image (Phase 4). No dependencies: Node's standard library only.
FROM node:24.21.0-alpine
# Patch OS packages, and remove package managers the app never uses at runtime
# (npm/yarn/corepack bring their own vulnerable dependencies; less in the
# image = less to attack, and the Trivy gate stays green).
RUN apk upgrade --no-cache \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /opt/yarn* \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg
WORKDIR /app
COPY server.mjs .
ARG APP_VERSION=local
ENV APP_VERSION=$APP_VERSION NODE_ENV=production PORT=8080
USER node
EXPOSE 8080
CMD ["node", "server.mjs"]
