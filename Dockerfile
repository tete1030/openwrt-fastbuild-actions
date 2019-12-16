FROM ubuntu:18.04 AS init-env
RUN useradd -ms /bin/bash builder \
  && apt-get -qq update && apt-get -qq install sudo \
  && /bin/bash -c 'echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99_sudo_include_file'
USER builder
WORKDIR /home/builder
VOLUME [ "/home/builder/openwrt" ]
COPY --chown=builder:builder scripts ./scripts
RUN scripts/initenv.sh

FROM init-env AS clone
ARG REPO_URL
ARG REPO_BRANCH
RUN /bin/bash -c "REPO_URL=\"$REPO_URL\" REPO_BRANCH=\"$REPO_BRANCH\" scripts/clone.sh"

FROM clone AS custom
ARG CONFIG_FILE
COPY --chown=builder:builder patches ./patches
COPY --chown=builder:builder ${CONFIG_FILE} ./
RUN /bin/bash -c "CONFIG_FILE=\"$CONFIG_FILE\" scripts/customize.sh"

FROM custom AS download
RUN scripts/download.sh

FROM download AS multithread-compile
RUN scripts/mt_compile.sh

FROM download AS singlethread-compile
RUN scripts/st_compile.sh
