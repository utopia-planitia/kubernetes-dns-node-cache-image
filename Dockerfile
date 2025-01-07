# renovate: datasource=repology depName=alpine_3_18/iptables versioning=loose
ARG IPTABLES_VERSION=1.8.9-r2
# renovate: datasource=github-releases depName=kubernetes/dns
ARG KUBERNETES_DNS_VERSION=1.23.1


FROM docker.io/library/alpine:3.18.10@sha256:b90c141a9f1d528f87dc2a54f85a3f49d3c42b10fb00cd42e7f19ba4c9071fa8 AS iptables-installer

ARG IPTABLES_VERSION
# ARGs are only available during build-time. we include them as ENVs, too, so they are available in image metadata and at run-time.
ENV IPTABLES_VERSION="${IPTABLES_VERSION:?}"

# install iptables into a separate root directory so it can be copied into a scratch/distroless image easily with all dependencies
RUN set -eux; \
    # copy the os-release file into the new root directory /rootfs
    # because it helps vulnerability scanners to detect and scan the OS packages
    mkdir -p /rootfs/etc; \
    cp /etc/os-release /rootfs/etc/os-release; \
    # install iptables with dependencies into the /rootfs directory
    apk add \
        --initdb \
        --keys-dir /etc/apk/keys \
        --no-cache \
        --repositories-file /etc/apk/repositories \
        --root /rootfs \
        "iptables=${IPTABLES_VERSION:?}" \
        ;

# clean up some directories from /rootfs that are not needed
RUN set -eux; \
    rm -fr \
        /rootfs/dev \
        /rootfs/proc \
        /rootfs/tmp \
        /rootfs/var \
        ;

# change default backend from legacy to nf_tables by changing the symlink from xtables-legacy-multi to xtables-nft-multi
# TODO: find out how to run / install https://github.com/kubernetes-sigs/iptables-wrappers in /rootfs (without a shell and without coreutils) instead of changing the symlinks
RUN set -eux; \
    find /rootfs/sbin -maxdepth 1 -type l -not -name 'iptables-legacy*' -print | \
        while read -r FILE; do \
            if readlink "${FILE:?}" | grep -Fqx xtables-legacy-multi; then \
                ln -fs xtables-nft-multi "${FILE:?}"; \
            fi; \
        done

# smoke test: print the iptables version and check if the output contains the expected number and the expected backend
RUN set -eux; \
    chroot /rootfs iptables --version | \
        tee -a /dev/stderr | \
        grep -F "${IPTABLES_VERSION%%-*}" | \
        grep -Fq nf_tables


FROM docker.io/library/golang:1.23.4-alpine3.21@sha256:6c5c9590f169f77c8046e45c611d3b28fe477789acd8d3762d23d4744de69812 AS node-cache-builder

WORKDIR /src

ARG KUBERNETES_DNS_VERSION
# ARGs are only available during build-time. we include them as ENVs, too, so they are available in image metadata and at run-time.
ENV KUBERNETES_DNS_VERSION="${KUBERNETES_DNS_VERSION:?}"

# download the kubernetes/dns source code
RUN set -eux; \
    wget -O dns.tar.gz -q "https://github.com/kubernetes/dns/archive/refs/tags/${KUBERNETES_DNS_VERSION:?}.tar.gz"; \
    tar xzf dns.tar.gz --strip-components=1

# build a statically-linked and stripped node-cache binary
RUN set -eux; \
    CGO_ENABLED=0 GOOS=linux go build \
        -o /rootfs/node-cache \
        -ldflags "-s -w -X k8s.io/dns/pkg/version.VERSION=${KUBERNETES_DNS_VERSION:?}" \
        cmd/node-cache/main.go

# smoke test: print the node-cache help and check if the output contains the expected version number
RUN set -eux; \
    chroot /rootfs /node-cache --help 2>&1 | \
        tee -a /dev/stderr | \
        grep -Fq "${KUBERNETES_DNS_VERSION:?}"


FROM scratch

# the environment variables are not necessary but they give insight into what is installed in the image (eg. with `docker inspect`)
ARG IPTABLES_VERSION KUBERNETES_DNS_VERSION
# ARGs are only available during build-time. we include them as ENVs, too, so they are available in image metadata and at run-time.
ENV IPTABLES_VERSION="${IPTABLES_VERSION:?}" KUBERNETES_DNS_VERSION="${KUBERNETES_DNS_VERSION:?}"

# copy the artifacts from the previous stages into this final distroless / scratch image
COPY --from=iptables-installer /rootfs /
COPY --from=node-cache-builder /rootfs /

# TODO: figure out how to install / use https://github.com/kubernetes-sigs/iptables-wrappers in a distroless image
#       there has been an attempt but it was abandoned: https://github.com/kubernetes-sigs/iptables-wrappers/pull/5

EXPOSE 53/tcp 53/udp

ENTRYPOINT ["/node-cache"]
