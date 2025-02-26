FROM php:8.1-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo pdo_mysql zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Download and extract WordPress
WORKDIR /var/www/html
RUN curl -O https://wordpress.org/latest.tar.gz \
    && tar -xzf latest.tar.gz \
    && rm latest.tar.gz \
    && mv wordpress/* . \
    && rmdir wordpress

# Set correct permissions
RUN chown -R www-data:www-data /var/www/html

# Create wp-config from the sample
RUN cp wp-config-sample.php wp-config.php

# Configure WordPress to use environment variables
RUN sed -i "s/define( 'DB_NAME', '.*' );/define( 'DB_NAME', getenv('WORDPRESS_DB_NAME') );/" wp-config.php && \
    sed -i "s/define( 'DB_USER', '.*' );/define( 'DB_USER', getenv('WORDPRESS_DB_USER') );/" wp-config.php && \
    sed -i "s/define( 'DB_PASSWORD', '.*' );/define( 'DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') );/" wp-config.php && \
    sed -i "s/define( 'DB_HOST', '.*' );/define( 'DB_HOST', getenv('WORDPRESS_DB_HOST') );/" wp-config.php

# Add unique authentication keys and salts
RUN curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

# Expose port 80
EXPOSE 80

# Use the default production configuration
RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini

# Set up a health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
