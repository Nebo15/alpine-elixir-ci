FROM nebo15/alpine-elixir:1.13.2-otp23.3.4.10

# Important! Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2022-01-15

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8
ENV PATH=${PATH}:/usr/bin

RUN apk add --no-cache --update-cache --virtual .elixir-ci  \
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
      libc-dev \
      gcc \
      g++ \
      postgresql-client \
      git-crypt \
      python3 \
      netcat-openbsd \ 
      graphicsmagick \
      msttcorefonts-installer fontconfig
      
RUN apk add --no-cache --update-cache --virtual .acceptance-ci \
    chromium chromium-chromedriver

RUN update-ms-fonts && \
    fc-cache -f
      
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
    GLIBC_VERSION='2.34-r0' && \
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
    chmod a+rx /usr/local/bin/docker-compose

# Install gcloud

RUN export CLOUDSDK_INSTALL_DIR=/usr/local/gcloud && \
    curl -sSL https://sdk.cloud.google.com | bash
ENV PATH ${PATH}:/usr/local/gcloud/google-cloud-sdk/bin:/usr/bin:

# Install kubectl

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Install Helm

ENV HELM_VERSION=3.2.1
RUN curl -L https://get.helm.sh/"helm-v${HELM_VERSION}-linux-amd64.tar.gz" |tar xvz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64 && \
    apk del curl && \
    rm -f /var/cache/apk/*

# Install Terraform

RUN git clone https://github.com/tfutils/tfenv.git "${HOME}/.tfenv" && \
    ln -s ${HOME}/.tfenv/bin/* /usr/local/bin && \
    tfenv install 1.0.6

# Install ktl

RUN git clone https://github.com/nebo15/k8s-utils.git "${HOME}/.k8s-utils" && \
    ln -s ${HOME}/.k8s-utils/ktl.sh /usr/local/bin/ktl

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
