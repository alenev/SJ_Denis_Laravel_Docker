FROM php:8.2-fpm

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    libonig-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libpq-dev \
    supervisor \
    procps \
  && docker-php-ext-install pdo_mysql mbstring zip intl pdo_pgsql pgsql \
  && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Ensure proper permissions for Laravel
RUN chown -R www-data:www-data /var/www/html
RUN mkdir -p /var/www/html/storage/framework/{cache,sessions,views} /var/www/html/bootstrap/cache \
  && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Create supervisor log directory
RUN mkdir -p /var/log/supervisor

# Copy configs
COPY docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf
# Copy supervisor configs
COPY docker/supervisor/conf.d/ /etc/supervisor/conf.d/

# Create supervisor config for PHP-FPM
RUN echo "[program:php-fpm]" > /etc/supervisor/conf.d/php-fpm.conf && \
    echo "command=/usr/local/sbin/php-fpm -F" >> /etc/supervisor/conf.d/php-fpm.conf && \
    echo "autostart=true" >> /etc/supervisor/conf.d/php-fpm.conf && \
    echo "autorestart=true" >> /etc/supervisor/conf.d/php-fpm.conf && \
    echo "stderr_logfile=/var/log/supervisor/php-fpm.err.log" >> /etc/supervisor/conf.d/php-fpm.conf && \
    echo "stdout_logfile=/var/log/supervisor/php-fpm.out.log" >> /etc/supervisor/conf.d/php-fpm.conf && \
    echo "user=root" >> /etc/supervisor/conf.d/php-fpm.conf

# Configure supervisor
RUN echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "logfile=/var/log/supervisor/supervisord.log" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "pidfile=/var/run/supervisord.pid" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "logfile_maxbytes=50MB" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "logfile_backups=10" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "loglevel=info" >> /etc/supervisor/conf.d/supervisord.conf

EXPOSE 9000

# Start supervisor which will start PHP-FPM and the queue worker
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
