FROM openjdk:8-slim 

ARG IMAGE_CREATE_DATE
ARG IMAGE_VERSION
ARG IMAGE_SOURCE_REVISION
ARG URL

# Metadata as defined in OCI image spec annotations - https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.title="Deimos" \
org.opencontainers.image.description="ServiceNow (MID) Java Service for Kubernetes" \
org.opencontainers.image.created=$IMAGE_CREATE_DATE \
org.opencontainers.image.version=$IMAGE_VERSION \
org.opencontainers.image.authors="Anthony Angelo" \
org.opencontainers.image.url="https://github.com/pangealab/deimos/" \
org.opencontainers.image.documentation="https://github.com/pangealab/deimos/README.md" \
org.opencontainers.image.vendor="Anthony Angelo" \
org.opencontainers.image.licenses="MIT" \
org.opencontainers.image.source="https://github.com/pangealab/deimos.git" \
org.opencontainers.image.revision=$IMAGE_SOURCE_REVISION

# Install Tools
RUN apt-get -y update && apt-get install -qqy \
    wget unzip \
    && rm -rf /var/lib/apt/lists/*

# Install MID Server
RUN wget --progress=bar:force --no-check-certificate \
    ${URL} -O /tmp/mid.zip && \
    unzip -d /opt /tmp/mid.zip && \
    chmod -R 755 /opt/agent && \
    mv /opt/agent/config.xml /opt/. && \
    rm -rf /tmp/*