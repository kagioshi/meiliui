# syntax=docker/dockerfile:1
########################################
# 1) Build Meili and fetch the UI
########################################
ARG MEILI_VERSION=v0.28.0
FROM getmeili/meilisearch:${MEILI_VERSION} AS meili

FROM node:20-alpine AS ui-builder
WORKDIR /app
# Pull the official Meili Dashboard (replace with the latest release tag)
ARG DASHBOARD_VERSION=v0.3.0
RUN apk add --no-cache git \
 && git clone --depth 1 --branch ${DASHBOARD_VERSION} https://github.com/meilisearch/Meilisearch-Dashboard.git . \
 && yarn install --frozen-lockfile \
 && yarn build

########################################
# 2) Final image: serve Meili + UI via Nginx
########################################
FROM nginx:alpine
LABEL maintainer=kagioshi

# Copy Meili binary
COPY --from=meili /bin/meilisearch /bin/meilisearch

# Copy built UI to Nginx
COPY --from=ui-builder /app/dist /usr/share/nginx/html

# Copy optional custom Meili config
COPY meilisearch-config.toml /etc/meilisearch/config.toml

# Expose HTTP and Meili API ports
EXPOSE 80 7700

# Run both Nginx (for UI) and Meili:
#   - Nginx serves the UI on port 80  
#   - Meili listens on 0.0.0.0:7700
CMD ["sh", "-c", "\
    nginx && \
    meilisearch --config-file /etc/meilisearch/config.toml \
"]
