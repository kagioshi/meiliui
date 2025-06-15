# syntax=docker/dockerfile:1

########################################
# 1) Build MeiliSearch (upstream image)
########################################
ARG MEILI_VERSION=v0.28.0
FROM getmeili/meilisearch:${MEILI_VERSION} AS meili

########################################
# 2) Build the Meili Dashboard UI
########################################
FROM node:20-alpine AS ui-builder
WORKDIR /app

# Choose the Dashboard release you want
ARG DASHBOARD_VERSION=v0.3.0

# Install curl & tar, fetch the release archive, strip the top-level folder
RUN apk add --no-cache curl tar \
 && npm install --global yarn \
 && curl -sL "https://github.com/meilisearch/Meilisearch-Dashboard/archive/refs/tags/${DASHBOARD_VERSION}.tar.gz" \
    | tar xz --strip-components=1

# Install deps and build
RUN yarn install --frozen-lockfile \
 && yarn build

########################################
# 3) Final image: Nginx serves UI + MeiliSearch
########################################
FROM nginx:alpine
LABEL maintainer="kagioshi"

# 3a) Copy the MeiliSearch binary from the meili stage
COPY --from=meili /bin/meilisearch /bin/meilisearch

# 3b) Copy the built Dashboard UI into Nginx's html root
COPY --from=ui-builder /app/dist /usr/share/nginx/html

# 3c) (Optional) Copy your custom TOML if you have one;
#      else remove these two lines and let env vars drive Meili.
COPY meilisearch-config.toml /etc/meilisearch/config.toml

# Expose ports: 80 for UI, 7700 for the API
EXPOSE 80 7700

# 3d) Entrypoint: start Nginx (serves UI) then MeiliSearch
CMD ["sh", "-c", "\
    nginx && \
    /bin/meilisearch \
      --config-file /etc/meilisearch/config.toml \
"]
