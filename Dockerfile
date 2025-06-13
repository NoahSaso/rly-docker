# Use go image
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build-env

RUN apk add --update --no-cache curl make git libc-dev bash gcc linux-headers eudev-dev

ARG TARGETARCH
ARG BUILDARCH
ARG RELAYER_VERSION=v2.6.0

# Install musl cross compiler
RUN if [ "${TARGETARCH}" = "arm64" ] && [ "${BUILDARCH}" != "arm64" ]; then \
      wget -c https://musl.cc/aarch64-linux-musl-cross.tgz -O - | tar -xzvv --strip-components 1 -C /usr; \
    elif [ "${TARGETARCH}" = "amd64" ] && [ "${BUILDARCH}" != "amd64" ]; then \
      wget -c https://musl.cc/x86_64-linux-musl-cross.tgz -O - | tar -xzvv --strip-components 1 -C /usr; \
    fi

RUN if [ -d "/go/bin/linux_${TARGETARCH}" ]; then mv /go/bin/linux_${TARGETARCH}/* /go/bin/; fi

# Clone and install relayer
RUN git clone --branch ${RELAYER_VERSION} https://github.com/cosmos/relayer.git
RUN cd relayer && \
    if [ "${TARGETARCH}" = "arm64" ] && [ "${BUILDARCH}" != "arm64" ]; then \
      export CC=aarch64-linux-musl-gcc CXX=aarch64-linux-musl-g++;\
    elif [ "${TARGETARCH}" = "amd64" ] && [ "${BUILDARCH}" != "amd64" ]; then \
      export CC=x86_64-linux-musl-gcc CXX=x86_64-linux-musl-g++; \
    fi; \
    GOOS=linux GOARCH=$TARGETARCH CGO_ENABLED=1 LDFLAGS='-linkmode external -extldflags "-static"' make install

# Initialize rly config
RUN rly config init

# Use minimal busybox from infra-toolkit image for final scratch image
FROM ghcr.io/strangelove-ventures/infra-toolkit:v0.0.6 AS busybox-min

# Create a non-root user for security
RUN adduser --disabled-password --gecos "" relayer

# Use ln and rm from full featured busybox for assembling final image
FROM busybox:1.34.1-musl AS busybox-full

# Build final image from scratch
FROM scratch

WORKDIR /bin

# Install ln (for making hard links) and rm (for cleanup) from full busybox
# image. Also install basename and cut for the entrypoint script.
COPY --from=busybox-full /bin/ln /bin/rm /bin/basename /bin/cut ./

# Install minimal busybox image as shell binary (will create hardlinks for the rest of the binaries to this data)
COPY --from=busybox-min /busybox/busybox /bin/sh

# Add hard links for read-only utils, then remove ln and rm
# Will then only have one copy of the busybox minimal binary file with all utils pointing to the same underlying inode
RUN ln sh pwd && \
    ln sh ls && \
    ln sh cat && \
    ln sh less && \
    ln sh grep && \
    ln sh sleep && \
    ln sh env && \
    ln sh tar && \
    ln sh tee && \
    ln sh du

# Install binaries
COPY --from=build-env /go/bin/rly /bin/bash /bin/

# Install trusted CA certificates
COPY --from=busybox-min /etc/ssl/cert.pem /etc/ssl/cert.pem

# Install relayer user
COPY --from=busybox-min /etc/passwd /etc/passwd
COPY --from=busybox-min --chown=relayer:relayer /home/relayer /home/relayer
COPY --from=build-env --chown=relayer:relayer /root/.relayer /home/relayer/.relayer

WORKDIR /home/relayer
USER relayer

# Copy the entrypoint script
COPY --chmod=755 docker-entrypoint.sh /home/relayer/docker-entrypoint.sh

# Clear the entrypoint so we can run relayer commands on a running container
ENTRYPOINT []

# Set default command that runs the entrypoint script
CMD ["/home/relayer/docker-entrypoint.sh"]
