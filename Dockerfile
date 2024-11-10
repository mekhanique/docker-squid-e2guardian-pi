FROM raspbian/stretch
MAINTAINER Stephen Widup \< s w i d u p \@ h o t m a i l . c o m \>

ENV SQUID_USER=squid
ENV SQUID_DIR /usr/local/squid
ENV SQUID_MAJOR 6
ENV SQUID_MINOR 1
ENV SQUID_PATCH 2
ARG BUILD_DATE
# e2guardian version
ENV VERSION 5.5.6
ENV OS debian

RUN apt-get update && \
    apt-get -qq -y install openssl libssl-dev build-essential wget curl net-tools dnsutils tcpdump dnsmasq && \
    apt-get clean

RUN wget http://www.squid-cache.org/Versions/v${SQUID_MAJOR}/${SQUID_MAJOR}.${SQUID_MINOR}/squid-${SQUID_MAJOR}.${SQUID_MINOR}.${SQUID_PATCH}.tar.gz && \
    tar xzvf squid-${SQUID_MAJOR}.${SQUID_MINOR}.${SQUID_PATCH}.tar.gz && \
    cd squid-${SQUID_MAJOR}.${SQUID_MINOR}.${SQUID_PATCH} && \
    ./configure --prefix=$SQUID_DIR --enable-ssl --with-openssl --enable-ssl-crtd --with-large-files --enable-auth --enable-icap-client && \
    make -j4 && \
    make install

RUN mkdir -p $SQUID_DIR/var/lib
RUN mkdir -p $SQUID_DIR/ssl
RUN $SQUID_DIR/libexec/ssl_crtd -c -s $SQUID_DIR/var/lib/ssl_db
RUN mkdir -p $SQUID_DIR/var/cache
RUN useradd $SQUID_USER -U -b $SQUID_DIR
RUN chown -R ${SQUID_USER}:${SQUID_USER} $SQUID_DIR
RUN echo "#====added config===" >> $SQUID_DIR/etc/squid.conf
RUN echo "cache_effective_user $SQUID_USER" >> $SQUID_DIR/etc/squid.conf
RUN echo "cache_effective_group $SQUID_USER" >> $SQUID_DIR/etc/squid.conf
RUN echo "always_direct allow all" >> $SQUID_DIR/etc/squid.conf
RUN echo "icap_service_failure_limit -1" >> $SQUID_DIR/etc/squid.conf
RUN echo "ssl_bump server-first all" >> $SQUID_DIR/etc/squid.conf
RUN echo "sslproxy_cert_error allow all" >> $SQUID_DIR/etc/squid.conf
RUN echo "sslproxy_flags DONT_VERIFY_PEER" >> $SQUID_DIR/etc/squid.conf
RUN sed "/^http_port 3128$/d" -i $SQUID_DIR/etc/squid.conf
RUN sed "s/^http_access allow localnet$/http_access allow all/" -i $SQUID_DIR/etc/squid.conf
RUN echo "http_port 3128 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=4MB cert=$SQUID_DIR/ssl/bluestar.crt key=$SQUID_DIR/ssl/bluestar.pem" >> $SQUID_DIR/etc/squid.conf
RUN cat $SQUID_DIR/etc/squid.conf | grep added\ config -A1000 #fflush()

LABEL commit.docker-squid-e2guardian-rpi=$COMMIT build_date.docker-squid-e2guardian-rpi=$BUILD_DATE
RUN apt update \
&& apt install --no-install-recommends --no-install-suggests -y curl unzip base-files automake base-passwd \
bash coreutils dash debianutils diffutils dpkg e2fsprogs findutils grep gzip hostname ncurses-base \
libevent-pthreads-* libevent-dev ncurses-bin perl-base sed login sysvinit-utils tar bsdutils \
mount util-linux libc6-dev libc-dev gcc g++ make dpkg-dev autotools-dev debhelper dh-autoreconf dpatch \
libclamav-dev libpcre3-dev zlib1g-dev pkg-config libssl libssl-dev libtommath1 libevent-pthreads \
libevent-core iptables


# Start e2guardian
RUN cd /tmp && wget https://codeload.github.com/e2guardian/e2guardian/zip/v$VERSION \
&& unzip v$VERSION

RUN cd /tmp/e2guardian-$VERSION && ./autogen.sh && ./configure  '--prefix=/usr' '--enable-clamd=yes' '--enable-icap=yes' '--with-proxyuser=e2guardian' '--with-proxygroup=e2guardian' \
'--sysconfdir=/etc' '--localstatedir=/var' '--enable-icap=yes' '--enable-commandline=yes' '--enable-email=yes' \
'--enable-ntlm=yes' '--mandir=${prefix}/share/man' '--infodir=${prefix}/share/info' \
'--enable-pcre=yes' '--enable-sslmitm=yes'
RUN cd /tmp/e2guardian-$VERSION && make \
&& mkdir /etc/e2guardian && cp src/e2guardian /usr/sbin/ && mkdir /var/log/e2guardian \
&& mkdir -p /usr/share/e2guardian/languages && cp -Rf data/languages /usr/share/e2guardian/ && cp data/*.gif /usr/share/e2guardian/ && cp data/*swf /usr/share/e2guardian/ \
&& cp -Rf configs/* /etc/e2guardian/ \
&& adduser --no-create-home --system e2guardian \
&& addgroup --system e2guardian \
&& chmod 750 -Rf /etc/e2guardian && chmod 750 -Rf /usr/share/e2guardian && chown -Rf e2guardian /etc/e2guardian /usr/share/e2guardian /var/log/e2guardian \
&& find /etc/e2guardian -type f -name .in -delete \
&& find /usr/share/e2guardian -type f -name .in -delete \
# ROOT mode if needed ...
# && sed -i "s/#daemonuser = 'e2guardian'/daemonuser = 'root'/g" /etc/e2guardian/e2guardian.conf \
# && sed -i "s/#daemongroup = 'e2guardian'/daemongroup = 'root'/g" /etc/e2guardian/e2guardian.conf \
&& sed -i "s/#dockermode = off/dockermode = on/g" /etc/e2guardian/e2guardian.conf \
&& apt remove -y --allow-remove-essential --purge curl unzip sed libevent-dev libc6-dev libc-dev g++ make dpkg-dev autotools-dev debhelper dh-autoreconf dpatch libclamav-dev libpcre3-dev zlib1g-dev libssl-dev \
&& rm -rf /var/lib/apt/lists/* && rm -Rf /tmp/*

COPY e2guardian.conf /etc/e2guardian/e2guardian.conf

EXPOSE 3128
# For transparent proxy we are using the following ports
EXPOSE 3130
EXPOSE 3131

ADD ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
