# Dockerfile for TexLive and Tectonic installation
# based on https://github.com/pandoc/dockerfiles
ARG BUILDPLATFORM
ARG MICROMAMBA_VERSION=latest
ARG ENVIRONMENT_FILE=env.yaml.lock
ARG BASE_IMAGE=mambaorg/micromamba
# Output path for TeX
ARG TEXMFOUTPUT=/mnt/output
# TeXLive version to install (leave empty to use the latest version).
ARG texlive_version=
# TeXLive mirror URL (leave empty to use the default mirror).
ARG texlive_mirror_url=

# Stage 1: Patched version of Micromamba / Debian
FROM --platform=${BUILDPLATFORM} ${BASE_IMAGE}:${MICROMAMBA_VERSION} as micromamba_patched
ARG MICROMAMBA_VERSION
ARG ENVIRONMENT_FILE
# Install security updates if base image is not yet patched
# Inspired by https://pythonspeed.com/articles/security-updates-in-docker/
# We need to switch back to the original bash shell for all standard stuff,
# since Micromamba has its own shell script for all mamba-related stuff
# TODO: Check
# SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
RUN apt-get update && apt-get -y upgrade && rm -rf /var/lib/apt/lists/*
# Back to the micromamba shell
# SHELL ["/usr/local/bin/_dockerfile_shell.sh"]
USER $MAMBA_USER
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]

# Stage 2: Tectonic as a baseline LaTeX system
# There is currently no binary for arm64 on m1, see
# https://github.com/tectonic-typesetting/tectonic/issues/1102
# But we can install from conda-forge
# https://github.com/conda-forge/tectonic-feedstock
FROM micromamba_patched as aih_tectonic
ARG ENVIRONMENT_FILE
# WORKDIR /usr/aih/
USER $MAMBA_USER
RUN echo --chown=${MAMBA_USER}:${MAMBA_USER} ${ENVIRONMENT_FILE}
COPY --chown=${MAMBA_USER}:${MAMBA_USER} ${ENVIRONMENT_FILE} /tmp/env.yaml
# Install packages
# 'tectonic' must be listed in env.yaml
RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes
# Back to the micromamba shell
# SHELL ["/usr/local/bin/_dockerfile_shell.sh"]
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]

# Stage 3: LaTeX
FROM aih_tectonic as aih_texlive
ARG TEXMFOUTPUT
# Install necessary dependencies as root
# These packages should be available for ARM64
# Based on the pandoc-latex and pandoc-extra stages from
# https://raw.githubusercontent.com/pandoc/dockerfiles/master/ubuntu/Dockerfile
# We need to switch back to the original bash shell for all standard stuff,
# since Micromamba has its own shell script for all mamba-related stuff
# TODO: Check
# SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root 
# NOTE: to maintainers, please keep this listing alphabetical.
# TODO: Removed   && DEBIAN_FRONTEND=noninteractive \
RUN apt-get --no-allow-insecure-repositories update &&\
    apt-get install -y \
        curl \
        fontconfig \
        gnupg \
        gzip \
        libfontconfig1 \
        libfreetype6 \
        perl \
        tar \
        unzip \
        wget \
        xzdec \
        xz-utils \     
    && rm -rf /var/lib/apt/lists/*
# TeXLive binaries location
ARG texlive_bin="/opt/texlive/texdir/bin"
RUN echo DEBUG: "$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')"
RUN TEXLIVE_ARCH="$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')" && \
    mkdir -p ${texlive_bin} && \
    ln -sf "${texlive_bin}/${TEXLIVE_ARCH}" "${texlive_bin}/default"
# Modify PATH environment variable, prepending TexLive bin directory
ENV PATH="${texlive_bin}/default:${PATH}"
WORKDIR /root
COPY dockerfiles/common/latex/texlive.profile /root/texlive.profile
COPY dockerfiles/common/latex/install-texlive.sh /root/install-texlive.sh
COPY dockerfiles/common/latex/packages.txt /root/packages.txt
# TeXLive version to install (leave empty to use the latest version).
ARG texlive_version=
# TeXLive mirror URL (leave empty to use the default mirror).
ARG texlive_mirror_url=
RUN ( [ -z "$texlive_version"    ] || printf '-t\n%s\n"' "$texlive_version" \
    ; [ -z "$texlive_mirror_url" ] || printf '-m\n%s\n' "$texlive_mirror_url" \
    ) | xargs /root/install-texlive.sh \
  && sed -e 's/ *#.*$//' -e '/^ *$/d' /root/packages.txt | \
     xargs tlmgr install \
  && rm -f /root/texlive.profile \
           /root/install-texlive.sh \
           /root/packages.txt \
  && TERM=dumb luaotfload-tool --update \
  && chmod -R o+w /opt/texlive/texdir/texmf-var
# We directly install the TeX packages from pandoc-extra
COPY dockerfiles/common/extra/packages.txt /root/extra_packages.txt
RUN sed -e 's/ *#.*$//' -e '/^ *$/d' /root/extra_packages.txt | \
   xargs tlmgr install \
   && rm -f /root/extra_packages.txt
# Any project-specific packages could be added in a similar fashion
WORKDIR /usr/aih/data/src
USER $MAMBA_USER
# ENV PATH="${texlive_bin}/default:${PATH}"
# TODO: Check if we need to add TeX Live to the non-root user's PATH
ARG MAMBA_DOCKERFILE_ACTIVATE=1
# Set TeX output directory
ENV TEXMFOUTPUT=${TEXMFOUTPUT}
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]