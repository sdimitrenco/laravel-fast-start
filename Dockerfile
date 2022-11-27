FROM php:8.1-fpm as base
USER root

# Copy composer.lock and composer.json
COPY composer.json /var/www/

# Set working directory
WORKDIR /var/www


FROM base as applications
# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    libpq5 \
    libpq-dev \
    libzip-dev \
    poppler-utils \
    libxml2-dev \
    gosu \
    supervisor
#procps #for process testing

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

FROM applications as extensions
# Install extensions
RUN docker-php-ext-install pdo_mysql zip exif pcntl soap
RUN docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd
RUN pecl install -o -f redis \
&&  rm -rf /tmp/pear \
&&  docker-php-ext-enable redis
RUN pecl install -o -f xdebug \
&& docker-php-ext-enable xdebug \
&&  docker-php-ext-enable redis soap

FROM extensions as composer
# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

FROM composer AS createuser
# Add user for laravel application
RUN groupadd --force -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

FROM createuser as final

ARG COMPOSER_OAUTH_KEY

# Copy existing application directory contents
RUN chown www:www ../www

COPY . /var/www

# Copy existing application directory permissions
COPY --chown=www:www . /var/www

USER root
COPY php/local.ini /usr/local/etc/php/conf.d/local.ini
COPY php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Expose port 9000 and start php-fpm server
EXPOSE 9000

