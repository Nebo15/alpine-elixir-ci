FROM nebo15/alpine-elixir:1.9.2-otp22.1.3
MAINTAINER Nebo#15 support@nebo15.com

# Important! Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2019-10-13

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8
ENV PATH=${PATH}:/usr/bin

RUN apk add --no-cache --update --virtual .elixir-ci \
      git \
      make \
      xvfb \
      sudo \
      bash \
      openssh-client \
      tar \
      gzip \
      parallel \
      net-tools \
      unzip \
      zip \
      bzip2 \
      gnupg \
      curl \
      wget \
      jq \
      docker \
      nodejs \
      yarn \
      gconf \
      chromium \
      chromium-chromedriver \
      libc-dev \
      gcc \
      postgresql-client

# Smoke tests
RUN jq --version
RUN chromedriver --version
RUN node --version
RUN yarn -v

# Install docker-compose
# https://docs.docker.com/compose/install/

RUN set -x && \
    apk add --no-cache -t .deps ca-certificates curl && \
    # Install glibc on Alpine (required by docker-compose) from
    # https://github.com/sgerrand/alpine-pkg-glibc
    # See also https://github.com/gliderlabs/docker-alpine/issues/11
    GLIBC_VERSION='2.30-r0' && \
    curl -Lo /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    curl -Lo glibc.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-$GLIBC_VERSION.apk && \
    curl -Lo glibc-bin.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-bin-$GLIBC_VERSION.apk && \
    apk update && \
    apk add glibc.apk glibc-bin.apk && \
    rm -rf /var/cache/apk/* && \
    rm glibc.apk glibc-bin.apk && \
    \
    # Clean-up
    apk del .deps && \
    DOCKER_COMPOSE_URL=https://github.com$(curl -L https://github.com/docker/compose/releases/latest | grep -Eo 'href="[^"]+docker-compose-Linux-x86_64' | sed 's/^href="//' | head -1) && \
    curl -Lo /usr/local/bin/docker-compose $DOCKER_COMPOSE_URL && \
    chmod a+rx /usr/local/bin/docker-compose && \
    docker-compose version

# start xvfb automatically to avoid needing to express in circle.yml
ENV DISPLAY :99
RUN printf '#!/bin/sh\nXvfb :99 -screen 0 1280x1024x24 &\nexec "$@"\n' > /tmp/entrypoint \
  && chmod +x /tmp/entrypoint \
        && sudo mv /tmp/entrypoint /docker-entrypoint.sh

# Circleci user
RUN addgroup -g 3434 circleci \
  && adduser -D -u 3434 -G circleci -h /home/circleci -s /bin/bash circleci \
  && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# Ensure that the build agent doesn't override the entrypoint
LABEL com.circleci.preserve-entrypoint=true

EXPOSE 9222

USER circleci

ENV HOME=/home/circleci
WORKDIR /home/circleci

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/bin/sh"]
