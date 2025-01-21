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


FROM ubuntu:noble AS buildstage

ARG KASMVNC_RELEASE="e04731870baebd2784983fb48197a2416c7d3519"

COPY --from=wwwstage /build-out /www

RUN sed -i 's|deb|deb deb-src|g' /etc/apt/sources.list.d/ubuntu.sources

ENV DEBIAN_FRONTEND=noninteractive
RUN \
  echo "**** install build deps ****" && \
  apt-get update && \
  apt-get build-dep -y \
  libxfont-dev \
  xorg-server && \
  apt-get install -y \
  autoconf \
  automake \
  cmake \
  git \
  grep \
  kbd \
  libavcodec-dev \
  libdrm-dev \
  libepoxy-dev \
  libgbm-dev \
  libgif-dev \
  libgnutls28-dev \
  libgnutls28-dev \
  libjpeg-dev \
  libjpeg-turbo8-dev \
  libpciaccess-dev \
  libpng-dev \
  libssl-dev \
  libtiff-dev \
  libtool \
  libwebp-dev \
  libx11-dev \
  libxau-dev \
  libxcursor-dev \
  libxcursor-dev \
  libxcvt-dev \
  libxdmcp-dev \
  libxext-dev \
  libxkbfile-dev \
  libxrandr-dev \
  libxrandr-dev \
  libxshmfence-dev \
  libxtst-dev \
  meson \
  nettle-dev \
  tar \
  wget \
  wayland-protocols \
  x11-apps \
  x11-common \
  x11-utils \
  x11-xkb-utils \
  x11-xserver-utils \
  xauth \
  xdg-utils \
  xfonts-base \
  xinit \
  xkb-data \
  xserver-xorg-dev

RUN apt install curl && \
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
  XORG_VER="21.1.12" && \
  wget --no-check-certificate \
  -O /tmp/xorg-server-${XORG_VER}.tar.gz \
  "https://x.org/archive/individual/xserver/xorg-server-${XORG_VER}.tar.gz" && \
  tar --strip-components=1 \
  -C unix/xserver \
  -xf /tmp/xorg-server-${XORG_VER}.tar.gz && \
  cd unix/xserver && \
  patch -Np1 -i ../xserver21.patch && \
  patch -s -p0 < ../CVE-2022-2320-v1.20.patch && \
  autoreconf -i && \
  ./configure --prefix=/opt/kasmweb \
  --with-xkb-path=/usr/share/X11/xkb \
  --with-xkb-output=/var/lib/xkb \
  --with-xkb-bin-directory=/usr/bin \
  --with-default-font-path="/usr/share/fonts/X11/misc,/usr/share/fonts/X11/cyrillic,/usr/share/fonts/X11/100dpi/:unscaled,/usr/share/fonts/X11/75dpi/:unscaled,/usr/share/fonts/X11/Type1,/usr/share/fonts/X11/100dpi,/usr/share/fonts/X11/75dpi,built-ins" \
  --with-sha1=libcrypto \
  --without-dtrace --disable-dri \
  --disable-static \
  --disable-xinerama \
  --disable-xvfb \
  --disable-xnest \
  --disable-xorg \
  --disable-dmx \
  --disable-xwin \
  --disable-xephyr \
  --disable-kdrive \
  --disable-config-hal \
  --disable-config-udev \
  --disable-dri2 \
  --enable-glx \
  --disable-xwayland \
  --enable-dri3 && \
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
  ln -s /usr/lib/x86_64-linux-gnu/dri dri && \
  cd /src && \
  mkdir -p builder/www && \
  cp -ax /www/* builder/www/ && \
  cp builder/www/index.html builder/www/vnc.html && \
  make servertarball && \
  mkdir /build-out && \
  tar xzf \
  kasmvnc-Linux*.tar.gz \
  -C /build-out/ && \
  rm -Rf /build-out/usr/local/man

# nodejs builder
FROM ubuntu:noble AS nodebuilder
ARG KCLIENT_RELEASE
RUN \
  echo "**** install build deps ****" && \
  apt-get update && \
  apt-get install -y \
  g++ \
  gcc \
  libpam0g-dev \
  libpulse-dev \
  make \
  nodejs \
  npm \
  curl

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

FROM ubuntu:noble


ARG S6_OVERLAY_VERSION=3.2.0.3
# https://github.com/just-containers/s6-overlay
# set version for s6 overlay 
ARG S6_OVERLAY_VERSION="3.2.0.2"
ARG S6_OVERLAY_ARCH="x86_64"

RUN apt update && apt install -y xz-utils

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
  LANGUAGE="en_US.UTF-8" \
  LANG="en_US.UTF-8" \
  PERL5LIB=/usr/local/bin \
  OMP_WAIT_POLICY=PASSIVE \
  GOMP_SPINCOUNT=0 \
  HOME=/config \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_VERBOSITY=1

COPY --from=nodebuilder /kclient /kclient
COPY --from=buildstage /build-out/ /


RUN \
  echo "**** Ripped from Ubuntu Docker Logic ****" && \
  set -xe && \
  echo '#!/bin/sh' \
  > /usr/sbin/policy-rc.d && \
  echo 'exit 101' \
  >> /usr/sbin/policy-rc.d && \
  chmod +x \
  /usr/sbin/policy-rc.d && \
  dpkg-divert --local --rename --add /sbin/initctl && \
  cp -a \
  /usr/sbin/policy-rc.d \
  /sbin/initctl && \
  sed -i \
  's/^exit.*/exit 0/' \
  /sbin/initctl && \
  echo 'force-unsafe-io' \
  > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup && \
  echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
  > /etc/apt/apt.conf.d/docker-clean && \
  echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
  >> /etc/apt/apt.conf.d/docker-clean && \
  echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' \
  >> /etc/apt/apt.conf.d/docker-clean && \
  echo 'Acquire::Languages "none";' \
  > /etc/apt/apt.conf.d/docker-no-languages && \
  echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' \
  > /etc/apt/apt.conf.d/docker-gzip-indexes && \
  echo 'Apt::AutoRemove::SuggestsImportant "false";' \
  > /etc/apt/apt.conf.d/docker-autoremove-suggests && \
  mkdir -p /run/systemd && \
  echo "**** install apt-utils and locales ****" && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y \
  apt-utils \
  locales && \
  echo "**** install packages ****" && \
  apt-get install -y \
  catatonit \
  cron \
  curl \
  gnupg \
  jq \
  netcat-openbsd \
  systemd-standalone-sysusers \
  tzdata && \
  echo "**** generate locale ****" && \
  locale-gen en_US.UTF-8 && \
  echo "**** create abc user and make our folders ****" && \
  useradd -u 911 -U -d /config -s /bin/false abc && \
  usermod -G users abc && \
  mkdir -p \
  /app \
  /config \
  /defaults \
  /lsiopy && \
  echo "**** cleanup ****" && \
  userdel ubuntu && \
  apt-get autoremove && \
  apt-get clean && \
  rm -rf \
  /tmp/* \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  /var/log/*


RUN \
  echo "**** enable locales ****" && \
  sed -i \
  '/locale/d' \
  /etc/dpkg/dpkg.cfg.d/excludes && \
  echo "**** install deps ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
  ca-certificates \
  cups \
  cups-client \
  cups-pdf \
  dbus-x11 \
  dunst \
  ffmpeg \
  file \
  fonts-noto-color-emoji \
  fonts-noto-core \
  fuse-overlayfs \
  intel-media-va-driver \
  kbd \
  libdatetime-perl \
  libfontenc1 \
  libfreetype6 \
  libgbm1 \
  libgcrypt20 \
  libgl1-mesa-dri \
  libglu1-mesa \
  libgnutls30 \
  libgomp1 \
  libhash-merge-simple-perl \
  libjpeg-turbo8 \
  libnotify-bin \
  liblist-moreutils-perl \
  libp11-kit0 \
  libpam0g \
  libpixman-1-0 \
  libscalar-list-utils-perl \
  libswitch-perl \
  libtasn1-6 \
  libtry-tiny-perl \
  libvulkan1 \
  libwebp7 \
  libx11-6 \
  libxau6 \
  libxcb1 \
  libxcursor1 \
  libxdmcp6 \
  libxext6 \
  libxfixes3 \
  libxfont2 \
  libxinerama1 \
  libxshmfence1 \
  libxtst6 \
  libyaml-tiny-perl \
  locales-all \
  mesa-va-drivers \
  mesa-vulkan-drivers \
  nginx \
  nodejs \
  openbox \
  openssh-client \
  openssl \
  pciutils \
  perl \
  procps \
  pulseaudio \
  pulseaudio-utils \
  python3 \
  software-properties-common \
  ssl-cert \
  sudo \
  tar \
  util-linux \
  vulkan-tools \
  x11-apps \
  x11-common \
  x11-utils \
  x11-xkb-utils \
  x11-xserver-utils \
  xauth \
  xdg-utils \
  xfonts-base \
  xkb-data \
  xserver-common \
  xserver-xorg-core \
  xserver-xorg-video-amdgpu \
  xserver-xorg-video-ati \
  xserver-xorg-video-intel \
  xserver-xorg-video-nouveau \
  xserver-xorg-video-qxl \
  xterm \
  xutils \
  zlib1g

RUN apt install curl unzip -y

RUN echo "**** printer config ****" && \
  sed -i -r \
  -e "s:^(Out\s).*:\1/home/kasm-user/PDF:" \
  /etc/cups/cups-pdf.conf && \
  echo "**** filesystem setup ****" && \
  ln -s /usr/local/share/kasmvnc /usr/share/kasmvnc && \
  ln -s /usr/local/etc/kasmvnc /etc/kasmvnc && \
  ln -s /usr/local/lib/kasmvnc /usr/lib/kasmvncserver && \
  echo "**** openbox tweaks ****" && \
  sed -i \
  -e 's/NLIMC/NLMC/g' \
  -e '/debian-menu/d' \
  -e 's|</applications>|  <application class="*"><maximized>yes</maximized></application>\n</applications>|' \
  -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
  /etc/xdg/openbox/rc.xml && \
  echo "**** user perms ****" && \
  sed -e 's/%sudo	ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' \
  -i /etc/sudoers && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  usermod -aG sudo abc && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
  | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
  | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
  echo "**** kasm support ****" && \
  useradd \
  -u 1000 -U \
  -d /home/kasm-user \
  -s /bin/bash kasm-user && \
  echo "kasm-user:kasm" | chpasswd && \
  usermod -aG sudo kasm-user && \
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
  mkdir -p /dockerstartup && \
  echo 'hosts: files dns' > /etc/nsswitch.conf && \
  echo "**** locales ****" && \
  for LOCALE in $(curl -sL https://raw.githubusercontent.com/thelamer/lang-stash/master/langs); do \
  echo generating $LOCALE.UTF-8..; \
  localedef -i $LOCALE -f UTF-8 $LOCALE.UTF-8; \
  done && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
  | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  /tmp/*

RUN \
  echo "**** add icon ****" && \
  curl -o \
  /kclient/public/icon.png \
  https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/webtop-logo.png && \
  echo "**** install packages ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
  obconf \
  stterm && \
  echo "**** application tweaks ****" && \
  update-alternatives --set \
  x-terminal-emulator \
  /usr/bin/st && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
  /config/.cache \
  /config/.launchpadlib \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  /tmp/*

ENV PULSE_RUNTIME_PATH=/defaults

# add local files
COPY /baseimage-root /
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
