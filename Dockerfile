FROM php:8.2-apache

# gd is what gives WordPress an image editor. Without it there are no
# intermediate sizes, no srcset and no WebP: every upload is served at its full
# original size. --with-webp is the half that lets uploads be converted rather
# than only accepted.
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev libjpeg-dev libwebp-dev libfreetype6-dev libonig-dev libxml2-dev curl less mariadb-client \
  && docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
  && docker-php-ext-install gd mysqli pdo pdo_mysql zip

RUN a2enmod rewrite headers
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# WP-CLI
RUN curl -o /usr/local/bin/wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar     && chmod +x /usr/local/bin/wp

COPY .user.ini /usr/local/etc/php/conf.d/uploads.ini

WORKDIR /var/www/html

# Node for building themes
ENV NODE_VERSION=22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -     && apt-get install -y nodejs
