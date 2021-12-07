# syntax=docker/dockerfile:experimental
FROM node:16-bullseye-slim as builder_base

WORKDIR /app

COPY package*.json yarn.lock ./


FROM builder_base as builder_development

ENV NODE_ENV development

RUN \
  # This is for the yarn cache. We have to use different caches otherwise both
  # this and the production stage will use the same cache and clobber each
  # other if they are run in parallel.
  --mount=type=cache,id=builder_development_yarn,target=/usr/local/share/.cache/yarn \
  # This is to keep the node_modules dir around between builds otherwise yarn
  # has to do a fresh install + build whenever the lock file changes.
  --mount=type=cache,id=builder_development_node_modules,target=/app/node_modules \
  # Defaults to installing all (prod + dev) packages.
  yarn --no-progress && \
  # The node_modules dir ceases to exist after the build so unless it's copied
  # off it can't be copied into the below stages.
  cp -r /app/node_modules /app/node_modules.sav


# This is used for both staging and production builds so we can't solely rely
# on the NODE_ENV env var.
# FROM builder_base as builder_production
# 
# ENV NODE_ENV production
# 
# RUN \
#   --mount=type=cache,id=builder_production_yarn,target=/usr/local/share/.cache/yarn \
#   --mount=type=cache,id=builder_production_node_modules,target=/app/node_modules \
#   yarn --prod --no-progress && \
#   cp -r /app/node_modules /app/node_modules.sav


FROM node:16-bullseye-slim as base

ARG UID=2000

ARG USER=apiuser

RUN useradd -m --uid ${UID} --shell /bin/bash ${USER}

ENV PATH /app/node_modules/.bin:$PATH


# FROM base as test_watch
# 
# ENV NODE_ENV test
# 
# WORKDIR /app
# 
# USER ${USER}
# 
# # tsc outputs all files on each compilation but let's just watch *.test.js
# # files specifically anyway.
# CMD ["nodemon", "--delay", "1", "--watch", "/app/build", "-e", "js", "--exec", "tap --no-check-coverage build/test/**/*.test.js"]


# FROM base as tsc_watch
# 
# ENV NODE_ENV development
# 
# WORKDIR /app
# 
# USER ${USER}
# 
# # Not using tsc's actual watch command here because it clears the screen.
# # CMD ["nodemon", "--watch", "/app/src/server", "--watch", "/app/src/test", "-e", "ts,js", "--exec", "tsc -p tsconfig.development.json"]
# CMD ["tsc", "-w", "--preserveWatchOutput", "-p", "tsconfig.development.json"]


FROM base as development

# Needed for the Nest watch command.
RUN set -eux; \
  apt-get update && \
  apt-get install -y \
  procps && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV NODE_ENV development

USER ${USER}

CMD [ "yarn", "run", "start:dev" ]


# FROM base as webpack_build
# 
# # For this stage, this can be either production or staging.
# ARG NODE_ENV=production
# 
# ENV NODE_ENV ${NODE_ENV}
# 
# ENV PATH /app/node_modules/.bin:$PATH
# 
# WORKDIR /app
# 
# # This stage only needs to read this stuff. No sense in copying it into the
# # image. This saves quite a bit of disk space.
# RUN \
#   --mount=type=bind,source=/app/node_modules.sav,target=node_modules,from=builder_development \
#   --mount=type=bind,source=package.json,target=package.json \
#   --mount=type=bind,source=lib,target=lib \
#   --mount=type=bind,source=public/img,target=public/img \
#   --mount=type=bind,source=src/client,target=src/client \
#   --mount=type=bind,source=src/shared,target=src/shared \
#   --mount=type=bind,source=webpack.config.js,target=webpack.config.js \
#   webpack
# 
# 
# FROM base as tsc_production
# 
# ENV NODE_ENV production
# 
# USER ${USER}
# 
# WORKDIR /app
# 
# RUN \
#   --mount=type=bind,source=/app/node_modules.sav,target=node_modules,from=builder_development \
#   --mount=type=bind,source=package.json,target=package.json \
#   --mount=type=bind,source=src,target=src \
#   --mount=type=bind,source=tsconfig.base.json,target=tsconfig.base.json \
#   --mount=type=bind,source=tsconfig.production.json,target=tsconfig.production.json \
#   tsc -p tsconfig.production.json && \
#   # Have to save off the files for later copy.
#   cp -a build/ build.sav/
# 
# 
# FROM base as test
# 
# ENV NODE_ENV test
# 
# WORKDIR /app
# 
# RUN mkdir webpack_stats && echo {} > webpack_stats/webpack_stats.json
# 
# USER ngapps
# 
# RUN \
#   --mount=type=bind,source=/app/build.sav,target=build,from=tsc_production \
#   --mount=type=bind,source=/app/node_modules.sav,target=node_modules,from=builder_development \
#   --mount=type=bind,source=lib,target=lib \
#   --mount=type=bind,source=package.json,target=package.json \
#   --mount=type=bind,source=src,target=src \
#   --mount=type=bind,source=tsconfig.base.json,target=tsconfig.base.json \
#   --mount=type=bind,source=tsconfig.production.json,target=tsconfig.production.json \
#   ts-standard -vp tsconfig.production.json src && \
#   tap --no-cov build/test/**/*.js && \
#   rm -rf /app/.nyc_output
# 
# 
# FROM base as production
# 
# EXPOSE 9000
# 
# WORKDIR /app
# 
# COPY --from=webpack_build /app/public/build/images public/build/images
# 
# COPY --from=builder_production /app/node_modules.sav node_modules
# 
# # Needed for the app itself.
# COPY package.json .
# 
# COPY lib lib
# 
# COPY public/alerts public/alerts
# 
# COPY public/favicons public/favicons
# 
# COPY public/img public/img
# 
# COPY public/launch-screens public/launch-screens
# 
# COPY public/loops public/loops
# 
# COPY public/music public/music
# 
# COPY public/pwa public/pwa
# 
# COPY public/soundfx public/soundfx
# 
# COPY src/client/img/icons/favicon-ng.ico src/client/img/icons/favicon-ng.ico
# 
# COPY --from=tsc_production /app/build/server build/server
# 
# COPY --from=tsc_production /app/build/shared build/shared
# 
# COPY manifests manifests
# 
# COPY templates templates
# 
# COPY views-chat views-chat
# 
# COPY views-radio views-radio
# 
# COPY --from=webpack_build /app/public/build/css public/build/css
# 
# COPY --from=webpack_build /app/public/build/js public/build/js
# 
# COPY --from=webpack_build /app/public/build/service-worker.js \
#   public/build/service-worker.js
# 
# COPY --from=webpack_build /app/webpack_stats/webpack_stats.json \
#   webpack_stats/webpack_stats.json
# 
# RUN ln -s /app/public/build/service-worker.js /app/public/service-worker.js
# 
# # Either staging or production.
# ARG NODE_ENV=production
# 
# ENV NODE_ENV ${NODE_ENV}
# 
# USER ${USER}
# 
# CMD ["node", "build/server/app.js"]
# 