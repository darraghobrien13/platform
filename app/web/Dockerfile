# Placeholder image (Phase 4). No dependencies: Node's standard library only.
FROM node:24.21.0-alpine
WORKDIR /app
COPY server.mjs .
ARG APP_VERSION=local
ENV APP_VERSION=$APP_VERSION NODE_ENV=production PORT=8080
USER node
EXPOSE 8080
CMD ["node", "server.mjs"]
