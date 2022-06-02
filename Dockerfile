ARG DEB_VERSION="bullseye"
ARG PHP_VERSION="7.4"
ARG COMPOSER_VERSION="2"
ARG NODE_VERSION="16"

FROM mlocati/php-extension-installer AS extension_installer
FROM composer:${COMPOSER_VERSION} as composer

FROM php:${PHP_VERSION}-fpm-${DEB_VERSION} as base
LABEL authors="Dominik Baranek <baranek@ics.muni.cz>,Pavel Brousek <brousek@ics.muni.cz>"
LABEL maintainer="Dominik Baranek <baranek@ics.muni.cz>,Pavel Brousek <brousek@ics.muni.cz>"

ARG DEBIAN_FRONTEND=noninteractive
ARG SSP_VERSION
ARG DEB_VERSION
ARG NODE_VERSION
ARG COMPOSER_VERSION

# use production php.ini
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# install PHP extensions and their dependencies
COPY --from=extension_installer /usr/bin/install-php-extensions /usr/bin/
RUN apt-get update -y && \
    install-php-extensions exif gmp imagick intl ldap memcached opcache pdo_mysql pdo_pgsql zip

FROM base AS ssp_builder
# https://simplesamlphp.org/docs/stable/simplesamlphp-install-repo
# add composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN apt update -y \
    && apt install -y --no-install-recommends git \
    && mkdir /var/ssp
COPY composer.json /var/ssp/
RUN cd /var/ssp \
    && /usr/bin/composer install --no-dev --no-progress \
    # adapt for Composer 2
    && if [ -d "/var/ssp/modules" ]; then mv /var/ssp/modules/* /var/ssp/vendor/simplesamlphp/simplesamlphp/modules/; fi \
    && mkdir log

# assets (node)
FROM node:${NODE_VERSION}-${DEB_VERSION} as node_builder
COPY --from=ssp_builder /var/ssp/ /var/ssp/
RUN cd /var/ssp/vendor/simplesamlphp/simplesamlphp && \
    npm install --no-dev --no-fund --no-package-lock && \
    npm run build

# copy built SimpleSAMLphp to production environment
FROM base

COPY --from=node_builder /var/ssp /var/ssp/

RUN ln -s /var/ssp/vendor/simplesamlphp/simplesamlphp /var/simplesamlphp

# final bits

EXPOSE 9000

WORKDIR /var/simplesamlphp/www
