FROM adminer:latest

USER root

# Install dependencies required for Oracle Instant Client and Alpine compatibility
RUN apk --no-cache add libaio libnsl libc6-compat curl autoconf m4 file gcc make g++ && \
    ln -s /lib/libc.so.6 /usr/lib/libresolv.so.2 || true

# Set up Oracle environment
ENV ORACLE_BASE=/usr/local/oracle \
    ORACLE_HOME=/usr/local/oracle/instantclient_21_7 \
    LD_LIBRARY_PATH=/usr/local/oracle/instantclient_21_7:/lib64 \
    TNS_ADMIN=/usr/local/oracle/instantclient_21_7/network/admin \
    AUTOCONF=/usr/bin/autoconf

# Copy pre-bundled packages (zero network downloads required during docker build)
COPY basic_lite.zip /tmp/
COPY oci8.so /usr/local/lib/php/extensions/no-debug-non-zts-20240924/oci8.so

# Unpack Oracle client libraries, enable oci8 extension, and register library search paths
RUN mkdir -p /usr/local/oracle && \
    unzip -q -d /usr/local/oracle /tmp/basic_lite.zip && \
    rm -f /tmp/basic_lite.zip && \
    docker-php-ext-enable oci8 && \
    echo '/lib:/usr/local/lib:/usr/lib:/usr/local/oracle/instantclient_21_7' > /etc/ld-musl-x86_64.path

USER adminer
