# docker-campusidp

Docker image with complete campus IdP, including [SimpleSAMLphp](https://simplesamlphp.org/), [module campusmultiauth](https://github.com/cesnet/simplesamlphp-module-campusmultiauth) and [module campususerpass](https://github.com/cesnet/simplesamlphp-module-campususerpass).

The image is based on the [official PHP docker image](https://hub.docker.com/_/php) with [PHP-FPM](https://php-fpm.org/).

## Build

[Install Docker engine](https://docs.docker.com/engine/install/), then run:

```sh
docker build -t campusidp:latest .
```

You can use build args to override versions of some dependencies:

```sh
docker build \
	--build-arg DEB_VERSION="bullseye" \
	--build-arg PHP_VERSION="7.4" \
	--build-arg COMPOSER_VERSION="2" \
	--build-arg NODE_VERSION="16" \
	--build-arg BOOTSTRAP_VERSION="5.1.3" \
	-t campusidp:latest \
	.
```

## Usage

This image provides FastCGI interface at port 9000. You need to use a web server to handle HTTPS and the FastCGI protocol (e.g. [Apache](https://cwiki.apache.org/confluence/display/httpd/PHP-FPM) or [nginx](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/) as a reverse proxy).

Here is an example `docker-compose.yml`:

```yaml
version: '3'
services:
  campusidp:
    image: campusidp:latest
    container_name: campusidp
    restart: always
  reverseproxy:
    image: nginx:latest
    container_name: reverseproxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
```

## Configuration

To provide configuration files, mount folders or files into the SimpleSAMLphp installation directory, which is `/var/ssp/vendor/simplesamlphp/simplesamlphp/`. You should probably mount these folders:

* /var/ssp/vendor/simplesamlphp/simplesamlphp/config/
* /var/ssp/vendor/simplesamlphp/simplesamlphp/metadata/

## Customize Bootstrap

This image overrides Bootstrap in the campusmultiauth module with a custom version, which excludes some unused parts of Bootstrap and may include color customizations and other enhancements.

To change colors or add custom SCSS/CSS, modify `custom.scss` in this repository and rebuild.

You may adjust these variables to change colors:
* `$primary`: header, preferred submit button
* `$secondary`: non-preferred submit button, footer
* `$dark`: preferred components text and borders
* `$text-muted`: secondary components text and borders
* `$body`: body background
* `$light`: centered box background
* `$danger`: error messages

## Usage without docker

If you want to install campus IdP without using docker, follow the bash commands in the Dockerfile and setup PHP and a web server appropriately.
