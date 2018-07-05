FROM neta540/openssh
LABEL maintainer="neta540@gmail.com"
RUN apk add --no-cache bc
COPY ras.sh /usr/bin/ras
COPY sshd_config /etc/ras/sshd_config
VOLUME [ "/root/keys" ]
CMD [ "/usr/bin/ras" ]