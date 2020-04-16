FROM php:7.4-fpm-alpine3.10

LABEL Maintainer Pinky Kitten <hientt53@gmail.com>

# Setup Working Dir
WORKDIR /var/www

# Add Repositories
RUN rm -f /etc/apk/repositories &&\
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.10/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.10/community" >> /etc/apk/repositories

# Add Build Dependencies
RUN apk add --no-cache --virtual .build-deps \ 
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libxml2-dev \
    bzip2-dev \
    tzdata

# Add Production Dependencies
RUN apk add --update --no-cache \
    jpegoptim \
    pngquant \
    optipng \
    supervisor \
    icu-dev \
    freetype-dev \ 
    libzip-dev \
    nginx  

# Configure & Install Extension
RUN docker-php-ext-configure \
    opcache --enable-opcache && \
    docker-php-ext-configure \
    gd --with-freetype --with-jpeg && \
    docker-php-ext-install \
    opcache \
    mysqli \
    pdo_mysql \
    sockets \
    intl \
    gd \
    bz2 \
    pcntl \
    bcmath \
    zip

# Add Composer
RUN curl -s https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

# Add source code
COPY ./ /var/www
RUN composer install
RUN chown -R www-data:www-data /var/www && chmod  -R 777 ./storage/logs

COPY ./.deploy/opcache.ini $PHP_INI_DIR/conf.d/
COPY ./.deploy/php.ini $PHP_INI_DIR/conf.d/
COPY ./.deploy/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# Setup Crond and Supervisor by default
RUN echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/root && mkdir /etc/supervisor.d
COPY ./.deploy/supervisord.ini /etc/supervisor.d/master.ini
COPY ./.deploy/nginx.conf /etc/nginx/conf.d/default.conf

# Config time zone
RUN cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime

# Remove Build Dependencies
RUN apk del -f .build-deps

CMD ["/usr/bin/supervisord"]
