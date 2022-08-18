FROM ghcr.io/linuxserver/baseimage-rdesktop-web:focal

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CALIBRE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

ENV \
  CUSTOM_PORT="8080" \
  GUIAUTOSTART="false" \
  HOME="/function"

RUN \
  set -o xtrace && \
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
    speech-dispatcher

RUN \
  echo "**** install calibre ****" && \
  mkdir -p /opt/calibre && \
  if [ -z ${CALIBRE_RELEASE+x} ]; then \
    CALIBRE_RELEASE=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
    | jq -r .tag_name); \
  fi && \
  CALIBRE_VERSION="$(echo ${CALIBRE_RELEASE} | cut -c2-)" && \
  echo CALIBRE VERSION: ${CALIBRE_VERSION} && \
  CALIBRE_URL="https://download.calibre-ebook.com/${CALIBRE_VERSION}/calibre-${CALIBRE_VERSION}-x86_64.txz" && \
  curl -o \
    /tmp/calibre-tarball.txz -L \
    "$CALIBRE_URL" && \
  tar xvf /tmp/calibre-tarball.txz -C \
    /opt/calibre && \
  /opt/calibre/calibre_postinstall && \
  dbus-uuidgen > /etc/machine-id

RUN \
  echo "**** install websocat ****" && \
  WEBSOCAT_RELEASE=$(curl -sX GET "https://api.github.com/repos/vi/websocat/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  curl -o \
    /usr/bin/websocat -fL \
    "https://github.com/vi/websocat/releases/download/${WEBSOCAT_RELEASE}/websocat.x86_64-unknown-linux-musl" && \
  chmod +x /usr/bin/websocat

RUN \
  echo "**** install dedrm tools ****" && \
  curl -sLo \
  "/tmp/DeDRM_tools.zip" \
  "https://github.com/noDRM/DeDRM_tools/releases/download/v10.0.3/DeDRM_tools_10.0.3.zip" && \
  ls -al && \
  unzip -q "/tmp/DeDRM_tools.zip" && \
  ls -al && \
  calibre-customize --add-plugin DeDRM_plugin.zip

RUN echo "**** setup drm key ****"
COPY dedrm.json /tmp/
ARG SERIAL
RUN \
  sed "s/SERIAL/${SERIAL}/" /tmp/dedrm.json \
  > ~/.config/calibre/plugins/dedrm.json

RUN \
  echo "**** install awscli ****" && \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -so "awscliv2.zip" && \
  unzip -q awscliv2.zip

# add config files
COPY root/ /

WORKDIR /
RUN \
  echo "**** install remarkable api tools ****" && \
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

RUN \
  echo "**** cleanup ****" && \
  apt-get clean && \
  rm -rf \
    ~/.cache \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

RUN \
  echo "**** set readable for lambda ****" && \
  chmod -R o+rX .

ENTRYPOINT [ "/usr/bin/python3", "-m", "awslambdaric" ]
CMD [ "app.lambda_handler" ]
# CMD [ "python3", "app.py" ]
