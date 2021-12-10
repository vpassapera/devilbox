FROM devilbox/php-fpm:8.0-work-0.127 AS ext-amqp
ENV EXT_AMQP_VERSION=master

RUN docker-php-source extract \
    && apt-get update \
    && apt-get install -qq -y librabbitmq-dev \
    && git clone --branch $EXT_AMQP_VERSION --depth 1 https://github.com/php-amqp/php-amqp.git /usr/src/php/ext/amqp \
    && cd /usr/src/php/ext/amqp && git submodule update --init \
    && docker-php-ext-install amqp

RUN ls -al /usr/local/lib/php/extensions/

FROM devilbox/php-fpm:8.0-work-0.125
COPY --from=ext-amqp /usr/local/etc/php/conf.d/docker-php-ext-amqp.ini /usr/local/etc/php/conf.d/docker-php-ext-amqp.ini
COPY --from=ext-amqp /usr/local/lib/php/extensions/no-debug-non-zts-20200930/amqp.so /usr/local/lib/php/extensions/no-debug-non-zts-20200930/amqp.so

RUN apt-get update \
    && apt-get install -qq -y librabbitmq-dev

