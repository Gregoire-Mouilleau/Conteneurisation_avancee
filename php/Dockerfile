FROM php:8.2-apache

# Extensions PDO MySQL
RUN docker-php-ext-install pdo pdo_mysql

# Droits d'écriture sur uploads
RUN mkdir -p /var/www/html/uploads && chmod 777 /var/www/html/uploads

# Copie des sources
COPY www/ /var/www/html/

# Droits d'écriture sur uploads après copie
RUN chmod -R 777 /var/www/html/uploads
