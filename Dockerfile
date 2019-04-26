FROM php:7.1.3-apache

RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
        unzip \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libaio1 \
        libjpeg-dev libpq-dev git wget \
	&& rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install -j$(nproc) iconv mcrypt gettext \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install gd mbstring opcache pdo zip

# Install the gmp and mcrypt extensions
RUN apt-get update -y
RUN apt-get install -y libgmp-dev re2c libmhash-dev libmcrypt-dev file
RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/local/include/
RUN docker-php-ext-configure gmp
RUN docker-php-ext-install gmp

RUN docker-php-ext-configure mcrypt
RUN docker-php-ext-install -j$(nproc) mcrypt

# Install imap extension
RUN apt-get install -y openssl
RUN apt-get install -y libc-client-dev
RUN apt-get install -y libkrb5-dev
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-install imap

# Install bz2
RUN apt-get install -y libbz2-dev
RUN docker-php-ext-install bz2

# Install mysql extension
RUN apt-get update && apt-get install -y --force-yes \
    freetds-dev \
 && rm -r /var/lib/apt/lists/* \
 && cp -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/ \
 #&& docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
 && docker-php-ext-install \
    pdo_mysql \
    pdo_dblib \
    pdo_pgsql

# Install Tokenizer
RUN docker-php-ext-install tokenizer

# Install ftp extension
RUN docker-php-ext-install ftp




# APC
RUN pear config-set php_ini /usr/local/etc/php/php.ini
RUN pecl config-set php_ini /usr/local/etc/php/php.ini
#RUN pecl install apc
RUN pecl install apcu

RUN a2enmod rewrite
RUN a2enmod expires
RUN a2enmod mime
RUN a2enmod filter
RUN a2enmod deflate
RUN a2enmod proxy_http
RUN a2enmod headers
RUN a2enmod php7

RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
RUN ln -s /usr/local/bin/composer /usr/bin/composer
#RUN curl -sL https://deb.nodesource.com/setup | bash -
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash
RUN apt-get install -yq nodejs build-essential
#RUN npm install -g phantomjs-prebuilt casperjs

RUN docker-php-ext-install mbstring

# Edit PHP INI
RUN echo "memory_limit = 1G" > /usr/local/etc/php/php.ini
RUN echo "upload_max_filesize = 50M" >> /usr/local/etc/php/php.ini
RUN echo "post_max_size = 50M" >> /usr/local/etc/php/php.ini
RUN echo "max_input_time = 60" >> /usr/local/etc/php/php.ini
RUN echo "file_uploads = On" >> /usr/local/etc/php/php.ini
RUN echo "max_execution_time = 300" >> /usr/local/etc/php/php.ini
RUN echo "LimitRequestBody = 100000000" >> /usr/local/etc/php/php.ini
RUN echo "extension = php_gmp.so" >> /usr/local/etc/php/php.ini

# Clean after install
RUN apt-get autoremove -y && apt-get clean all

# Configuration for Apache
RUN rm -rf /etc/apache2/sites-enabled/000-default.conf
ADD apache/000-default.conf /etc/apache2/sites-available/
RUN ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/
RUN a2enmod rewrite


#COPY docker-php.conf /etc/apache2/conf-enabled/docker-php.conf

RUN printf "log_errors = On \nerror_log = /dev/stderr\n" > /usr/local/etc/php/conf.d/php-logs.ini


# Oracle instantclient
ADD instantclient/instantclient-basiclite-linux.x64-12.2.0.1.0.zip /tmp/
ADD instantclient/instantclient-sdk-linux.x64-12.2.0.1.0.zip /tmp/
ADD instantclient/instantclient-sqlplus-linux.x64-12.2.0.1.0.zip /tmp/

RUN unzip /tmp/instantclient-basiclite-linux.x64-12.2.0.1.0.zip -d /usr/local/
RUN unzip /tmp/instantclient-sdk-linux.x64-12.2.0.1.0.zip -d /usr/local/
RUN unzip /tmp/instantclient-sqlplus-linux.x64-12.2.0.1.0.zip -d /usr/local/

RUN ln -s /usr/local/instantclient_12_2 /usr/local/instantclient
RUN ln -s /usr/local/instantclient/libclntsh.so.12.1 /usr/local/instantclient/libclntsh.so
RUN ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus

RUN echo 'export LD_LIBRARY_PATH="/usr/local/instantclient"' >> /root/.bashrc
RUN echo 'umask 002' >> /root/.bashrc

RUN echo 'instantclient,/usr/local/instantclient' | pecl install oci8
#RUN echo "extension=oci8.so" > /usr/local/etc/php/conf.d/php-oci8.ini

RUN apt-get install nano -y

RUN echo "<?php echo phpinfo(); ?>" > /var/www/html/phpinfo.php
RUN echo "extension=oci8.so" > /usr/local/etc/php/php.ini

RUN chown -R www-data:www-data /var/www/html
ADD ./usuarios_afectados /var/www/html/

# Change working directory
WORKDIR /var/www/html

# Install and update laravel (rebuild into vendor folder)
RUN ldconfig
RUN php -i | grep php.ini
RUN ls /var/www/html
RUN composer update

RUN composer install

#RUN php artisan view:clear
#RUN php artisan route:cache

# Laravel writing rights
RUN chgrp -R www-data /var/www/html/storage
RUN chgrp -R www-data /var/www/html/bootstrap/cache
RUN chmod -R ug+rwx /var/www/html/storage
RUN chmod -R ug+rwx /var/www/html/bootstrap/cache


# Create Laravel folders (mandatory)
RUN mkdir -p /var/www/html/storage/framework
RUN mkdir -p /var/www/html/storage/framework/sessions
RUN mkdir -p /var/www/html/storage/framework/views
RUN mkdir -p /var/www/html/storage/meta
RUN mkdir -p /var/www/html/storage/cache
#RUN mkdir -p /var/www/html/public/uploads

# Change folder permission
RUN chmod -R 0777 /var/www/html/storage/
CMD sudo rm /var/www/html/public/storage

# Custom ini file in php conf folder
#COPY config/custom.ini /usr/local/etc/php/conf.d/

# Running artisan commands
CMD php artisan config:cache
CMD php artisan cache:clear

EXPOSE 80
