FROM dotriver/alpine-s6


ENV ADMIN_PASS=admin \
    CONFIG_PASS=config \
    DOMAIN=example.org \
    LOG_LEVEL=256 \
    REAPPLY_PLUGIN_SCHEMAS=TRUE \
    SCHEMA2LDIF_VERSION=1.3 \
    FD_ADMIN=fd-admin \
    FD_PASS=admin \
    FD_VERSION=1.3 \
    SMARTY_VERSION=3.1.33 \
    SMARTYGETTEXT_VERSION=1.6.1 \
    INSTANCE=exemple \
    SMTP_HOST=localhost \
    SMTP_PORT=587 \
    SMTP_AUTH=on \
    SMTP_TLS=on \
    SMTP_USER=username \
    SMTP_PASS=password \
    SMTP_FROM=admin@exemple.org 

# maybe not php fpm but php cgi ( we will save a service )

RUN set -x \
    && apk add --no-cache \
    wget \
    curl \
    nginx \
    php7 \
    php7-fpm \
    php-gettext \
    php7-imagick \
    php7-imap \
    php7-xml \
    php7-cli \
    php7-curl \
    php7-session \
    php7-gd \
    php7-ldap \
    php7-mbstring \
    php7-recode \
    php7-json \
    php7-iconv \ 
    gettext \
    gettext-lang \
    perl-digest-sha1 \
    perl-config-inifiles \
    perl-datetime \
    perl-ldap \
    perl-mime-base64 \
    perl-crypt-cbc \
    perl-file-copy-recursive \
    perl-io-socket-ssl \
    perl-json \
    perl-net-ldap \
    perl-path-class \
    perl-term-readkey \
    perl-xml-twig \
    && ln -s /usr/bin/perl /usr/local/bin/perl  \
    && mkdir -p /run/nginx/ \
    && rm -R /var/www/* \
    && chown nginx:nginx /var/www/ /run/nginx/


RUN set -x \
    && apk add --no-cache --virtual build-deps coreutils build-base make perl-dev \
    && curl -L http://cpanmin.us -o /usr/bin/cpanm \
    && chmod +x /usr/bin/cpanm \
    && cpanm -n \
    App::Daemon \
    Archive::Extract \
    HTTP::Daemon \
    JSON::Any \
    JSON::RPC \
    Log::Handler \
    Mail::Sendmail \
    Module::Pluggable \
    POE \
    POE::Component::Schedule \
    POE::Component::Server::SimpleHTTP \
    POE::Component::Server::JSONRPC \
    POE::Component::Pool::Thread \
    POE::Component::SSLify \
    XML::SAX::Expat \
    && cp -R /usr/local/share/perl5/site_perl/* /usr/share/perl5/vendor_perl/ \
    && apk del build-deps coreutils build-base make perl-dev 

## Install Smarty3
RUN set -x \
    && mkdir -p /usr/src/smarty /usr/src/smarty-gettext /usr/share/php/smarty3 \
    && curl https://codeload.github.com/smarty-php/smarty/tar.gz/v${SMARTY_VERSION} | tar xvfz - --strip 1 -C /usr/src/smarty \
    && cp -r /usr/src/smarty/libs/* /usr/share/php/smarty3 \
    && ln -s /usr/share/php/smarty3/Smarty.class.php /usr/share/php/smarty3/smarty.class.php \
    && curl https://codeload.github.com/smarty-gettext/smarty-gettext/tar.gz/${SMARTYGETTEXT_VERSION} | tar xvfz - --strip 1 -C /usr/src/smarty-gettext \
    && mkdir -p /usr/share/php/smarty3/plugins \
    && cp -R /usr/src/smarty-gettext/block.t.php /usr/share/php/smarty3/plugins/ \
    && cp -R /usr/src/smarty-gettext/tsmarty2c.php /usr/sbin \
    && chmod 750 /usr/sbin/tsmarty2c.php

## Install Schema2LDIF
RUN set -x \
    && export URL=https://gitlab.fusiondirectory.org/fusiondirectory/schema2ldif/-/archive/${SCHEMA2LDIF_VERSION}/schema2ldif-${SCHEMA2LDIF_VERSION}.tar.gz \
    && curl $URL | tar xvfz - --strip 1 -C /usr \
    && rm -rf /usr/CHANGELOG \
    && rm -rf /usr/LICENSE



# Install SLAPD
RUN set -x \
    && apk --no-cache add perl bash openldap openldap-clients openldap-back-mdb openldap-overlay-memberof openldap-overlay-refint  \
    && rm -R /var/lib/openldap /etc/openldap/*.*
    


## Install FusionDirectory
RUN set -x \
    && mkdir -p /usr/src/fusiondirectory /usr/src/fusiondirectory-plugins \
    && export URL=https://gitlab.fusiondirectory.org/fusiondirectory/fd/-/archive/fusiondirectory-${FD_VERSION}/fd-fusiondirectory-${FD_VERSION}.tar.gz \
    && curl $URL  | tar xvfz - --strip 1 -C /usr/src/fusiondirectory \
    && export URL=https://gitlab.fusiondirectory.org/fusiondirectory/fd-plugins/-/archive/fusiondirectory-${FD_VERSION}/fd-plugins-fusiondirectory-${FD_VERSION}.tar.gz \
    && curl $URL | tar xvfz - --strip 1 -C /usr/src/fusiondirectory-plugins \
    && mkdir -p /etc/openldap/schema/fusiondirectory \
    && rm -rf /usr/src/fusiondirectory/contrib/openldap/rfc2307bis.schema \
    && cp /usr/src/fusiondirectory/contrib/bin/* /usr/sbin \
    && cp -R /usr/src/fusiondirectory/contrib/openldap/*.schema /etc/openldap/schema/fusiondirectory \
    && cp -R /usr/src/fusiondirectory-plugins/*/contrib/openldap/*.schema /etc/openldap/schema/fusiondirectory \
    && sed -i "s|/etc/ldap/|/etc/openldap/|g" /usr/sbin/*  \
    && sed -i "s|/etc/ldap/|/etc/openldap/|g" /usr/bin/ldap-schema-manager  \
    && sed -i "s,ldapi:///',ldapi://%2Frun%2Fopenldap%2Fldapi.sock',g" /usr/bin/ldap-schema-manager \
    && chmod +x /usr/sbin/*

## Install FusionDirectory
RUN set -x \
    && mkdir -p /usr/src/javascript \
    && cd /usr/src/javascript \
    && curl -O http://ajax.googleapis.com/ajax/libs/prototype/1.7.1.0/prototype.js \
    && curl -O http://script.aculo.us/dist/scriptaculous-js-1.9.0.zip \
    && unzip -d . scriptaculous-js-1.9.0.zip \
    && cp -R prototype.js /usr/src/fusiondirectory/html/include \
    && cp -R scriptaculous-js-1.9.0/src/scriptaculous.js /usr/src/fusiondirectory/html/include \
    && cp -R scriptaculous-js-1.9.0/src/builder.js /usr/src/fusiondirectory/html/include \
    && cp -R scriptaculous-js-1.9.0/src/controls.js /usr/src/fusiondirectory/html/include \
    && cp -R scriptaculous-js-1.9.0/src/dragdrop.js /usr/src/fusiondirectory/html/include \
    && cp -R scriptaculous-js-1.9.0/src/effects.js /usr/src/fusiondirectory/html/include \
    && cp -R /usr/src/fusiondirectory/contrib/smarty/plugins/* /usr/share/php/smarty3/plugins/ \
    && mkdir -p /var/spool/fusiondirectory/ \
    && mkdir -p /var/cache/fusiondirectory/ \
    && mkdir -p /var/cache/fusiondirectory/fai \
    && mkdir -p /var/cache/fusiondirectory/include \
    && mkdir -p /var/cache/fusiondirectory/locale \
    && mkdir -p /var/cache/fusiondirectory/template \
    && mkdir -p /var/cache/fusiondirectory/tmp \
    && mkdir -p /etc/fusiondirectory \
    && mkdir /var/www/fusiondirectory -p \
    && cp -R /usr/src/fusiondirectory/contrib/fusiondirectory.conf /var/cache/fusiondirectory/template/fusiondirectory.conf \
    && cp -R /usr/src/fusiondirectory /var/www/ \
    && rm -R /var/www/fusiondirectory/.g* \
    && sed -i "s/mail_body))/mail_body, NULL, NULL, 'html'))/g" /var/www/fusiondirectory/html/class_passwordRecovery.inc \
    && fusiondirectory-setup --set-fd_smarty_dir="/usr/share/php/smarty3/Smarty.class.php" --write-vars \
    && touch /etc/debian_version \
    && yes Yes | fusiondirectory-setup --check-directories --update-cache \
    && rm -rf /usr/src/fusiondirectory


RUN set -x \
    && apk --no-cache add msmtp \
    && ln -sf /usr/bin/msmtp /usr/sbin/sendmail

RUN set -x \
    && rm /etc/nginx/conf.d/*

ADD conf/ /

RUN set -x \
    && chmod +x /etc/cont-init.d/ -R \
    && chmod +x /etc/periodic/ -R  \
    && chmod +x /etc/s6/services/ -R 