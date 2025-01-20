FROM node:12-buster AS wwwstage

ARG KASMWEB_RELEASE="46412d23aff1f45dffa83fafb04a683282c8db58"

RUN \
  echo "**** build clientside ****" && \
  export QT_QPA_PLATFORM=offscreen && \
  export QT_QPA_FONTDIR=/usr/share/fonts && \
  mkdir /src && \
  cd /src && \
  wget https://github.com/kasmtech/noVNC/tarball/${KASMWEB_RELEASE} -O - \
  | tar  --strip-components=1 -xz && \
  npm install && \
  npm run-script build

RUN \
  echo "**** organize output ****" && \
  mkdir /build-out && \
  cd /src && \
  rm -rf node_modules/ && \
  cp -R ./* /build-out/ && \
  cd /build-out && \
  rm *.md && \
  rm AUTHORS && \
  cp index.html vnc.html && \
  mkdir Downloads


FROM alpine:latest as buildstage

COPY --from=wwwstage /build-out /www

ARG KASMVNC_RELEASE="e04731870baebd2784983fb48197a2416c7d3519"
COPY --from=wwwstage /build-out /www
RUN \
  echo "**** install build deps ****" && \
  apk add \
  alpine-release \
  alpine-sdk \
  autoconf \
  automake \
  bash \
  ca-certificates \
  cmake \
  coreutils \
  curl \
  eudev-dev \
  font-cursor-misc \
  font-misc-misc \
  font-util-dev \
  git \
  grep \
  jq \
  libdrm-dev \
  libepoxy-dev \
  libjpeg-turbo-dev \
  libjpeg-turbo-static \
  libpciaccess-dev \
  libtool \
  libwebp-dev \
  libx11-dev \
  libxau-dev \
  libxcb-dev \
  libxcursor-dev \
  libxcvt-dev \
  libxdmcp-dev \
  libxext-dev \
  libxfont2-dev \
  libxkbfile-dev \
  libxrandr-dev \
  libxshmfence-dev \
  libxtst-dev \
  mesa-dev \
  mesa-dri-gallium \
  meson \
  nettle-dev \
  openssl-dev \
  pixman-dev \
  procps \
  shadow \
  tar \
  tzdata \
  wayland-dev \
  wayland-protocols \
  xcb-util-dev \
  xcb-util-image-dev \
  xcb-util-keysyms-dev \
  xcb-util-renderutil-dev \
  xcb-util-wm-dev \
  xinit \
  xkbcomp \
  xkbcomp-dev \
  xkeyboard-config \
  xorgproto \
  xorg-server-common \
  xorg-server-dev \
  xtrans

RUN \
  echo "**** build libjpeg-turbo ****" && \
  mkdir /jpeg-turbo && \
  JPEG_TURBO_RELEASE=$(curl -sX GET "https://api.github.com/repos/libjpeg-turbo/libjpeg-turbo/releases/latest" \
  | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  curl -o \
  /tmp/jpeg-turbo.tar.gz -L \
  "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/${JPEG_TURBO_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/jpeg-turbo.tar.gz -C \
  /jpeg-turbo/ --strip-components=1 && \
  cd /jpeg-turbo && \
  MAKEFLAGS=-j`nproc` \
  CFLAGS="-fpic" \
  cmake -DCMAKE_INSTALL_PREFIX=/usr/local -G"Unix Makefiles" && \
  make && \
  make install

RUN \
  echo "**** build kasmvnc ****" && \
  git clone https://github.com/kasmtech/KasmVNC.git src && \
  cd /src && \
  git checkout -f ${KASMVNC_release} && \
  sed -i \
  -e '/find_package(FLTK/s@^@#@' \
  -e '/add_subdirectory(tests/s@^@#@' \
  CMakeLists.txt && \
  cmake \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DBUILD_VIEWER:BOOL=OFF \
  -DENABLE_GNUTLS:BOOL=OFF \
  . && \
  make -j4 && \
  echo "**** build xorg ****" && \
  XORG_VER="21.1.14" && \
  wget --no-check-certificate \
  -O /tmp/xorg-server-${XORG_VER}.tar.gz \
  "https://www.x.org/archive/individual/xserver/xorg-server-${XORG_VER}.tar.gz" && \
  tar --strip-components=1 \
  -C unix/xserver \
  -xf /tmp/xorg-server-${XORG_VER}.tar.gz && \
  cd unix/xserver && \
  patch -Np1 -i ../xserver21.patch && \
  patch -s -p0 < ../CVE-2022-2320-v1.20.patch && \
  autoreconf -i && \
  ./configure \
  --disable-config-hal \
  --disable-config-udev \
  --disable-dmx \
  --disable-dri \
  --disable-dri2 \
  --disable-kdrive \
  --disable-static \
  --disable-xephyr \
  --disable-xinerama \
  --disable-xnest \
  --disable-xorg \
  --disable-xvfb \
  --disable-xwayland \
  --disable-xwin \
  --enable-dri3 \
  --enable-glx \
  --prefix=/opt/kasmweb \
  --with-default-font-path="/usr/share/fonts/X11/misc,/usr/share/fonts/X11/cyrillic,/usr/share/fonts/X11/100dpi/:unscaled,/usr/share/fonts/X11/75dpi/:unscaled,/usr/share/fonts/X11/Type1,/usr/share/fonts/X11/100dpi,/usr/share/fonts/X11/75dpi,built-ins" \
  --without-dtrace \
  --with-sha1=libcrypto \
  --with-xkb-bin-directory=/usr/bin \
  --with-xkb-output=/var/lib/xkb \
  --with-xkb-path=/usr/share/X11/xkb && \
  find . -name "Makefile" -exec sed -i 's/-Werror=array-bounds//g' {} \; && \
  make -j4

RUN \
  echo "**** generate final output ****" && \
  cd /src && \
  mkdir -p xorg.build/bin && \
  cd xorg.build/bin/ && \
  ln -s /src/unix/xserver/hw/vnc/Xvnc Xvnc && \
  cd .. && \
  mkdir -p man/man1 && \
  touch man/man1/Xserver.1 && \
  cp /src/unix/xserver/hw/vnc/Xvnc.man man/man1/Xvnc.1 && \
  mkdir lib && \
  cd lib && \
  ln -s /usr/lib/xorg/modules/dri dri && \
  cd /src && \
  mkdir -p builder/www && \
  cp -ax /www/* builder/www/ && \
  make servertarball && \
  mkdir /build-out && \
  tar xzf \
  kasmvnc-Linux*.tar.gz \
  -C /build-out/

# nodejs builder
FROM ghcr.io/linuxserver/baseimage-alpine:3.21 AS nodebuilder
ARG KCLIENT_RELEASE
RUN \
  echo "**** install build deps ****" && \
  apk add --no-cache \
  alpine-sdk \
  curl \
  cmake \
  g++ \
  gcc \
  make \
  nodejs \
  npm \
  pulseaudio-dev \
  python3
RUN \
  echo "**** grab source ****" && \
  mkdir -p /kclient && \
  if [ -z ${KCLIENT_RELEASE+x} ]; then \
  KCLIENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/kclient/releases/latest" \
  | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
  /tmp/kclient.tar.gz -L \
  "https://github.com/linuxserver/kclient/archive/${KCLIENT_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/kclient.tar.gz -C \
  /kclient/ --strip-components=1
RUN \
  echo "**** install node modules ****" && \
  cd /kclient && \
  npm install && \
  rm -f package-lock.json

FROM alpine:latest


ARG S6_OVERLAY_VERSION=3.2.0.3
# https://github.com/just-containers/s6-overlay
# set version for s6 overlay 
ARG S6_OVERLAY_VERSION="3.2.0.2"
ARG S6_OVERLAY_ARCH="x86_64"

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && unlink //usr/bin/with-contenv
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

ARG KASMBINS_RELEASE="1.15.0"

ENV DISPLAY=:1 \
  PERL5LIB=/usr/local/bin \
  OMP_WAIT_POLICY=PASSIVE \
  GOMP_SPINCOUNT=0 \
  HOME=/config \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_VERBOSITY=1

COPY --from=nodebuilder /kclient /kclient
COPY --from=buildstage /build-out/ /

RUN \
  echo "**** install deps ****" && \
  apk add --no-cache \
  bash \
  ca-certificates \
  cups \
  cups-client \
  dbus-x11 \
  docker \
  docker-cli-compose \
  dunst \
  ffmpeg \
  font-noto \
  font-noto-emoji \
  fuse-overlayfs \
  gcompat \
  intel-media-driver \
  iproute2-minimal \
  lang \
  libgcc \
  libgomp \
  libjpeg-turbo \
  libnotify \
  libstdc++ \
  libwebp \
  libxfont2 \
  libxshmfence \
  mcookie \
  mesa \
  mesa-dri-gallium \
  mesa-gbm \
  mesa-gl \
  mesa-va-gallium \
  mesa-vulkan-ati \
  mesa-vulkan-intel \
  mesa-vulkan-layers \
  mesa-vulkan-swrast \
  nginx \
  nodejs \
  openbox \
  openssh-client \
  openssl \
  pciutils-libs \
  perl \
  perl-datetime \
  perl-hash-merge-simple \
  perl-list-moreutils \
  perl-switch \
  perl-try-tiny \
  perl-yaml-tiny \
  pixman \
  pulseaudio \
  pulseaudio-utils \
  py3-xdg \
  python3 \
  setxkbmap \
  sudo \
  tar \
  vulkan-tools \
  xauth \
  xf86-video-amdgpu \
  xf86-video-ati \
  xf86-video-intel \
  xf86-video-nouveau \
  xf86-video-qxl \
  xkbcomp \
  xkeyboard-config \
  xterm

RUN echo "**** create abc user and make our folders ****" && \
  adduser -u 911 -D -h /config -s /bin/false abc && \
  addgroup abc users && \
  mkdir -p \
  /app \
  /config \
  /defaults \
  /lsiopy && \
  echo "**** cleanup ****" && \
  rm -rf \
  /tmp/*

RUN apk add curl

RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
  cups-pdf && \
  echo "**** printer config ****" && \
  sed -i \
  "s:^#Out.*:Out /home/kasm-user/PDF:" \
  /etc/cups/cups-pdf.conf && \
  sed -i \
  's/^SystemGroup .*/SystemGroup lpadmin root/' \
  /etc/cups/cups-files.conf && \
  echo "**** filesystem setup ****" && \
  ln -s /usr/local/share/kasmvnc /usr/share/kasmvnc && \
  ln -s /usr/local/etc/kasmvnc /etc/kasmvnc && \
  ln -s /usr/local/lib/kasmvnc /usr/lib/kasmvncserver && \
  echo "**** openbox tweaks ****" && \
  sed -i \
  -e 's/NLIMC/NLMC/g' \
  -e 's|</applications>|  <application class="*"><maximized>yes</maximized></application>\n</applications>|' \
  -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
  /etc/xdg/openbox/rc.xml && \
  echo "**** user perms ****" && \
  echo "abc:abc" | chpasswd && \
  echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel && \
  adduser abc wheel && \
  echo "**** kasm support ****" && \
  addgroup 'kasm-user' && \
  adduser \
  -u 1000 -G kasm-user\
  -D -h /home/kasm-user \
  -s /bin/bash kasm-user && \
  echo "kasm-user:kasm" | chpasswd && \
  adduser kasm-user wheel && \
  mkdir -p /home/kasm-user && \
  chown 1000:1000 /home/kasm-user && \
  mkdir -p /var/run/pulse && \
  chown 1000:root /var/run/pulse && \
  mkdir -p /kasmbins && \
  curl -s https://kasm-ci.s3.amazonaws.com/kasmbins-amd64-${KASMBINS_RELEASE}.tar.gz \
  | tar xzvf - -C /kasmbins/ && \
  chmod +x /kasmbins/* && \
  chown -R 1000:1000 /kasmbins && \
  chown 1000:1000 /usr/share/kasmvnc/www/Downloads && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
  | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  rm -rf \
  /tmp/*

RUN \
  echo "**** add icon ****" && \
  curl -o \
  /kclient/public/icon.png \
  https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/webtop-logo.png && \
  echo "**** install packages ****" && \
  apk add --no-cache \
  chromium \
  obconf-qt \
  st \
  util-linux-misc && \
  echo "**** application tweaks ****" && \
  ln -s \
  /usr/bin/st \
  /usr/bin/x-terminal-emulator && \
  echo "**** cleanup ****" && \
  rm -rf \
  /config/.cache \
  /tmp/*

RUN apk add --no-cache \
  alpine-release \
  bash \
  ca-certificates \
  catatonit \
  coreutils \
  curl \
  findutils \
  jq \
  netcat-openbsd \
  procps-ng \
  shadow \
  tzdata
ENV PULSE_RUNTIME_PATH=/defaults

# add local files
COPY /baseimage-alpine-root /
COPY /baseimage-kasmvnc-root /tmp/root
COPY lsiown /usr/bin/lsiown
COPY with-contenv /usr/bin/with-contenv
COPY package-install /etc/s6-overlay/s6-rc.d/init-mods-package-install/run
RUN cp -r /tmp/root/* / && \
  mkdir -p ~/.config/openbox

# ports and volumes
EXPOSE 3000 3001
VOLUME /config

ENTRYPOINT ["/init"]
