FROM amd64/debian:buster-slim
MAINTAINER "gary@bowers1.com"

RUN mkdir -p /usr/share/man/man1 && \
    mkdir -p /data

RUN DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get install -y \
            gnupg \
            bind9 \
            dnsutils && \
    rm -rf /vr/lib/apt/lists/* && \
    mkdir -p /var/log/named && \
    touch /var/log/named/querylog

EXPOSE 53/tcp 53/udp

VOLUME ["/data"]
ENTRYPOINT ["/usr/sbin/named", "-c", "/etc/bind/named.conf", "-d", "9", "-f", "-g"]
