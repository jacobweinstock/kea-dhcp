ARG KEA_VERSION=1.4.0

FROM tcely/isc-kea:dependency-log4cplus AS log4cplus

FROM alpine AS builder

ENV KEA_LIB=/usr/local/include/kea
ENV KEA_INCLUDE=/usr/local/include/kea
ENV KEA_MSG_COMPILER=/usr/local/bin/kea-msg-compiler

ARG KEA_VERSION

COPY --from=log4cplus /usr/local /usr/local/

RUN apk --update upgrade && \
    apk add bash ca-certificates curl && \
    apk add --virtual .build-depends \
        file gnupg g++ make \
        boost-dev bzip2-dev libressl-dev sqlite-dev zlib-dev \
        python3-dev git && \
    curl -RL -O "https://ftp.isc.org/isc/kea/${KEA_VERSION}/kea-${KEA_VERSION}.tar.gz{,.sha512.asc}" && \
    mkdir -v -m 0700 -p /root/.gnupg && \
#    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
#        --verify kea-*.asc kea-*.tar.gz && \
    rm -rf /root/.gnupg *.asc && \
    tar -xpf "kea-${KEA_VERSION}.tar.gz" && \
    rm -f "kea-${KEA_VERSION}.tar.gz" && \
    ( \
        cd "kea-${KEA_VERSION}" && \
        ./configure \
            --enable-shell && \
        make -j 4 && \
        make install-strip \
    ) && \
    # install a hook: https://github.com/zorun/kea-hook-runscript && \
    git clone https://github.com/zorun/kea-hook-runscript.git /usr/local/kea-hook-runscript && \
    cd /usr/local/kea-hook-runscript && \
    make && \
    apk del --purge .build-depends && rm -rf /var/cache/apk/*

FROM alpine
LABEL maintainer="https://keybase.io/tcely"

RUN apk --update upgrade && \
    apk add bash ca-certificates curl less man procps \
        boost bzip2 libressl sqlite zlib \
        python3 && \
    rm -rf /var/cache/apk/*

ENV PAGER less

COPY --from=builder /usr/local /usr/local/

ENTRYPOINT ["/usr/local/sbin/kea-dhcp4"]
CMD ["-c", "/usr/local/etc/kea/kea-dhcp4.conf"]
