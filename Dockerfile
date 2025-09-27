FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev libonig-dev libxml2-dev curl less mariadb-client \
  && docker-php-ext-install mysqli pdo pdo_mysql zip

RUN a2enmod rewrite
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# WP-CLI
RUN curl -o /usr/local/bin/wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar     && chmod +x /usr/local/bin/wp

WORKDIR /var/www/html

# Node for building themes
ENV NODE_VERSION=22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -     && apt-get install -y nodejs
