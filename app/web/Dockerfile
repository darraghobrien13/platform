# Build context: app/ (the npm workspace root).
FROM node:24.21.0-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
COPY shared/package.json shared/
COPY api/package.json api/
COPY web/package.json web/
RUN npm ci --no-audit --no-fund
COPY tsconfig.base.json ./
COPY shared shared
COPY api api
COPY web web
RUN npm run build -w web

FROM node:24.21.0-alpine
RUN apk upgrade --no-cache \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /opt/yarn* \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg
WORKDIR /app
COPY --from=build /src/web/dist ./dist
ARG APP_VERSION=local
ENV APP_VERSION=$APP_VERSION NODE_ENV=production PORT=8080
USER node
EXPOSE 8080
CMD ["node", "--enable-source-maps", "dist/server.js"]
