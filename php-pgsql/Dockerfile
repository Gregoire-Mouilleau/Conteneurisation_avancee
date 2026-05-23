FROM php:8.2-apache

# Extensions PDO PostgreSQL
RUN apt-get update && apt-get install -y libpq-dev \
    && docker-php-ext-install pdo pdo_pgsql \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Droits d'écriture sur uploads
RUN mkdir -p /var/www/html/uploads && chmod 777 /var/www/html/uploads

# Copie des sources
COPY www/ /var/www/html/

RUN chmod -R 777 /var/www/html/uploads
