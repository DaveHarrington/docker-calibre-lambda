FROM ghcr.io/linuxserver/baseimage-rdesktop-web:focal

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CALIBRE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

ENV \
  CUSTOM_PORT="8080" \
  GUIAUTOSTART="true" \
  HOME="/config"

RUN \
  echo "**** install runtime packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    dbus \
    fcitx-rime \
    fonts-wqy-microhei \
    jq \
    libnss3 \
    libopengl0 \
    libqpdf26 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    poppler-utils \
    python3 \
    python3-xdg \
    ttf-wqy-zenhei \
    unzip \
    wget \
    xz-utils && \
  apt-get install -y \
    speech-dispatcher && \
  echo "**** install calibre ****" && \
  mkdir -p \
    /opt/calibre && \
  if [ -z ${CALIBRE_RELEASE+x} ]; then \
    CALIBRE_RELEASE=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
    | jq -r .tag_name); \
  fi && \
  CALIBRE_VERSION="$(echo ${CALIBRE_RELEASE} | cut -c2-)" && \
  CALIBRE_URL="https://download.calibre-ebook.com/${CALIBRE_VERSION}/calibre-${CALIBRE_VERSION}-x86_64.txz" && \
  curl -o \
    /tmp/calibre-tarball.txz -L \
    "$CALIBRE_URL" && \
  tar xvf /tmp/calibre-tarball.txz -C \
    /opt/calibre && \
  /opt/calibre/calibre_postinstall && \
  dbus-uuidgen > /etc/machine-id && \
  echo "**** grab websocat ****" && \
  WEBSOCAT_RELEASE=$(curl -sX GET "https://api.github.com/repos/vi/websocat/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  curl -o \
    /usr/bin/websocat -fL \
    "https://github.com/vi/websocat/releases/download/${WEBSOCAT_RELEASE}/websocat.x86_64-unknown-linux-musl" && \
  chmod +x /usr/bin/websocat && \
  echo "**** cleanup ****" && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

RUN \
  curl -sLo \
  "/tmp/DeDRM_tools_7.2.1.zip" \
  "https://github.com/apprenticeharper/DeDRM_tools/releases/download/v7.2.1/DeDRM_tools_7.2.1.zip" && \
  unzip -q "/tmp/DeDRM_tools_7.2.1.zip" && \
  calibre-customize --add-plugin DeDRM_plugin.zip

ARG SERIAL
RUN sed -i "s/\"serials\": \[\]/\"serials\": \[\"${SERIAL}\"\]/" ~/.config/calibre/plugins/dedrm.json

RUN \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -so "awscliv2.zip" && \
  unzip -q awscliv2.zip

# add config files
COPY root/ /

WORKDIR /
RUN \
  curl -sLo \
    "rmapi-linuxx86-64.tar.gz" \
    "https://github.com/juruen/rmapi/releases/download/v0.0.20/rmapi-linuxx86-64.tar.gz" && \
  tar zxf rmapi-linuxx86-64.tar.gz && \
  cp rmapi /usr/local/bin && \
  mkdir -p /tmp/cache/rmapi

COPY rmapi-cache-tree /tmp/cache/rmapi/.tree

RUN apt-get update && \
  apt-get install -y \
  g++ \
  make \
  cmake \
  unzip \
  libcurl4-openssl-dev \
  python3-pip

ARG FUNCTION_DIR="/function"
RUN mkdir -p ${FUNCTION_DIR}
WORKDIR ${FUNCTION_DIR}

COPY app/requirements.txt .
RUN pip3 install -r requirements.txt

COPY app/* .

ENTRYPOINT [ "/usr/bin/python3", "-m", "awslambdaric" ]
CMD [ "app.lambda_handler" ]
