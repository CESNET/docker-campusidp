ARG DEB_VERSION="bullseye"
ARG PHP_VERSION="7.4"
ARG COMPOSER_VERSION="2"
ARG NODE_VERSION="16"
ARG BOOTSTRAP_VERSION="5.1.3"

FROM mlocati/php-extension-installer AS extension_installer
FROM composer:${COMPOSER_VERSION} AS composer

FROM php:${PHP_VERSION}-fpm-${DEB_VERSION} AS base
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
    install-php-extensions exif gmp imagick intl ldap memcached opcache pdo_mysql pdo_pgsql soap zip

FROM base AS ssp_builder

# https://simplesamlphp.org/docs/stable/simplesamlphp-install-repo
# add composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN apt update -y && \
    apt install -y --no-install-recommends git unzip && \
    mkdir /var/ssp
COPY composer.json /var/ssp/
RUN cd /var/ssp && \
    /usr/bin/composer install --no-dev --no-progress && \
    # adapt for Composer 2
    if [ -d "/var/ssp/modules" ]; then mv /var/ssp/modules/* /var/ssp/vendor/simplesamlphp/simplesamlphp/modules/; fi && \
    mkdir log

# assets (node)
FROM node:${NODE_VERSION}-${DEB_VERSION} AS node_builder
ARG BOOTSTRAP_VERSION

COPY --from=ssp_builder /var/ssp/ /var/ssp/

# compile Bootstrap with custom variables
ADD https://github.com/twbs/bootstrap/archive/v${BOOTSTRAP_VERSION}.zip /tmp/
COPY custom.scss /tmp/
RUN cd /tmp && \
    unzip v${BOOTSTRAP_VERSION}.zip && \
    mv bootstrap-${BOOTSTRAP_VERSION} bootstrap && \
    cd bootstrap && \
    npm ci && \
    npx sass --style expanded --embed-sources --no-error-css /tmp/custom.scss /tmp/bootstrap.css && \
    npx postcss --config build/postcss.config.js --replace /tmp/bootstrap.css && \
    npx cleancss -O1 --format breakWith=lf --with-rebase --source-map --source-map-inline-sources --output /tmp/ --batch --batch-suffix ".min" "/tmp/*.css" && \
    mv /tmp/bootstrap.min.css /var/ssp/vendor/simplesamlphp/simplesamlphp/modules/campusmultiauth/www/resources/bootstrap/css/ && \
    mv /tmp/bootstrap.min.css.map /var/ssp/vendor/simplesamlphp/simplesamlphp/modules/campusmultiauth/www/resources/bootstrap/css/

# SSP assets
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
