# Using Debian-based image because v8js (php)
# See also https://hub.docker.com/r/gytist/php-fpm-v8js/dockerfile
FROM php:7.3-fpm

# Do not use latest here! See
# see available versions here: https://omahaproxy.appspot.com/
ARG V8_VERSION=7.5.288.30
# path to chromium tools (python scripts etc)
# ENV PATH /tmp/depot_tools:$PATH

# See https://github.com/phpv8/v8js/issues/397 for flags
RUN apt-get update  \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git subversion make g++ python2.7 curl  wget bzip2 xz-utils pkg-config  \
        build-essential libmemcached-dev zlib1g-dev imagemagick libmcrypt-dev \
        libpq-dev libsqlite3-dev libjpeg-dev libpng-dev libxslt-dev libexif-dev \
        libxml2-dev libpq-dev libsqlite3-dev libzip-dev

RUN ln -s /usr/bin/python2.7 /usr/bin/python

# Install PHP "gd" extension
RUN docker-php-ext-configure gd --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd

# Install PHP "mysqli" extension – http://php.net/manual/pl/book.mysqli.php
RUN docker-php-ext-install mysqli
RUN docker-php-ext-enable mysqli

# Install PHP "pdo" extension with "mysql", "pgsql", "sqlite" drivers – http://php.net/manual/pl/book.pdo.php
RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install pdo pdo_mysql pgsql pdo_pgsql pdo_sqlite

# Install mbstring
RUN docker-php-ext-install mbstring

# Install PHP "xsl" extension – http://php.net/manual/en/book.xsl.php
RUN docker-php-ext-install xsl
RUN docker-php-ext-enable xsl

# Install PHP "exif" extension – http://php.net/manual/en/book.exif.php
RUN docker-php-ext-install exif

# Install PHP "opcache" extension – http://php.net/manual/en/book.opcache.php
RUN docker-php-ext-install opcache
RUN docker-php-ext-enable opcache

# Install PHP "zip" extension – http://php.net/manual/en/book.zip.php
RUN docker-php-ext-install zip

# Install mcrypt
RUN pecl install mcrypt \
    && docker-php-ext-enable mcrypt

# Install soap
RUN docker-php-ext-install soap
RUN docker-php-ext-enable soap

# Install memcache extension
RUN cd /tmp \
    && git clone https://github.com/websupport-sk/pecl-memcache.git \
    && cd pecl-memcache \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -Rf pecl-memcache \
    && docker-php-ext-enable memcache

# Install memcached extension
RUN git clone https://github.com/php-memcached-dev/php-memcached /usr/src/php/ext/memcached \
    && docker-php-ext-configure /usr/src/php/ext/memcached --disable-memcached-sasl \
    && docker-php-ext-install /usr/src/php/ext/memcached \
    && rm -rf /usr/src/php/ext/memcached

# Install V8JS
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /tmp/depot_tools \
    && export PATH="$PATH:/tmp/depot_tools"  \
    \
    && cd /usr/local/src \
    && fetch v8 \
    && cd v8 \
    && git checkout ${V8_VERSION} \
    && gclient sync \
    \
    &&  cd /usr/local/src/v8 \
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false \
    && ninja -C out.gn/x64.release/ && \
    \
    mkdir -p /usr/local/lib && \
    cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /usr/local/lib && \
    cp -R include/* /usr/local/include/ \
    \
    && git clone https://github.com/phpv8/v8js.git /usr/local/src/v8js \
    && cd /usr/local/src/v8js \
    && phpize \
    && ./configure --with-v8js=/usr/loca/lib/v8 \
    && export NO_INTERACTION=1 \
    && make all -j4 \
    && make test install \
    \
    && echo extension=v8js.so > /usr/local/etc/php/conf.d/v8js.ini

# Cleanup the image
RUN cd /tmp \
    && rm -rf /tmp/depot_tools /usr/local/src/v8 /usr/local/src/v8js \
    && apt-get remove -y git subversion make g++ python2.7 wget bzip2 xz-utils pkg-config \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
