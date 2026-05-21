FROM traffmonetizer/cli_v2:latest AS cli

FROM alpine:3.15

RUN apk add --no-cache \
    ca-certificates \
    curl \
    tini \
    busybox-extras

COPY --from=cli /usr/local/bin/cli /usr/local/bin/cli.real
COPY --chmod=0755 entrypoint.sh /usr/local/bin/cli

WORKDIR /usr/local/bin/

EXPOSE 2410

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/cli"]
# Thêm dòng CMD này vào cuối
CMD ["start", "accept", "--token", "tbOBkhRHWXCl8NHzr+/GF5qHDrWRo43PFU1XzPe+GGM="]
