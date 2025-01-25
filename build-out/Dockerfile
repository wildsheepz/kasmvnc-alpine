FROM ubuntu:noble as wwwstage

ARG KASMWEB_RELEASE="46412d23aff1f45dffa83fafb04a683282c8db58"

ARG NODE_VERSION=v12.22.12

COPY ./neutralize-binary-clipboard-freeze.patch /tmp

RUN apt update -qqq && apt install bzip2 xz-utils tar curl wget git -y && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    export QT_QPA_PLATFORM=offscreen && \
    export QT_QPA_FONTDIR=/usr/share/fonts && \
    (mkdir /tmp/src && \
    cd /tmp/src && \
    wget https://github.com/kasmtech/noVNC/tarball/${KASMWEB_RELEASE} -O - \
    | tar  --strip-components=1 -xz && \
    git apply /tmp/neutralize-binary-clipboard-freeze.patch && \
    nvm use ${NODE_VERSION} && \
    npm install && \
    npm run-script build)

RUN \
    mkdir -p /tmp/www && \
    rm -rf /tmp/src/node_modules && \
    cp -R /tmp/src/* /tmp/www/ && \
    rm /tmp/www/*.md && \
    rm /tmp/www/AUTHORS && \
    cp /tmp/www/index.html /tmp/www/vnc.html && \
    mkdir -p /tmp/www/Downloads
    

FROM ubuntu:noble
ARG KASMVNC_RELEASE="46412d23aff1f45dffa83fafb04a683282c8db58"

#RUN grep -E 'ubuntu.com' /etc/apt/sources.list | grep -v 'deb-src' | sed 's|deb|deb-src|g' >> /etc/apt/sources.list
RUN sed -i 's|deb|deb deb-src|g' /etc/apt/sources.list.d/ubuntu.sources

COPY --from=wwwstage /tmp/www /www

RUN \
    echo "**** install build deps ****" && \
    apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && apt-get build-dep -y \
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

RUN apt install curl -y && \
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

ARG XORG_VER="21.1.12"

RUN \
    echo "**** build kasmvnc ****" && \
    git -c http.sslVerify=false clone https://github.com/kasmtech/KasmVNC.git src && \
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
    wget https://x.org/archive/individual/xserver/xorg-server-${XORG_VER}.tar.gz -O /tmp/xorg-server-${XORG_VER}.tar.gz && \
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