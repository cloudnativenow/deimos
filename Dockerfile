FROM openjdk:8-slim 

ARG IMAGE_CREATE_DATE
ARG IMAGE_VERSION
ARG IMAGE_SOURCE_REVISION
ARG DEBIAN_FRONTEND

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

# Prepare Install
RUN mkdir -p /opt && \
    groupadd -g 999 midserver && \
    useradd -r -u 999 -g midserver midserver

# Install Tools
RUN apt-get -q update && apt-get install -qy unzip \
    apt-utils procps wget vim curl iputils-ping jq && \ 
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Environment Variables
ENV INSTANCE_URL "default-url"
ENV MID_USERNAME "default-user"
ENV MID_PASSWORD "default-password"
ENV MID_NAME "default-host"

# Arguments
ARG URL
RUN echo "midserver binary url: ${URL}"
# URL is mandatory
RUN test -n "$URL"

# Install MID Server
RUN wget --progress=bar:force --no-check-certificate \
    ${URL} -O /tmp/mid.deb && \
    apt-get install /tmp/mid.deb && \
    cp /opt/servicenow/mid/agent/config.xml /opt/servicenow/mid/agent/config.xml.orig && \
    rm /opt/servicenow/mid/agent/config.xml && \
    chown -R midserver:midserver /opt/servicenow && \
    chmod -R 775 /opt/servicenow/mid/agent/*.sh && \   
    rm -rf /tmp/*

# Configure Start
ADD ./start.sh /opt
RUN chmod +x /opt/start.sh

# Start Mid
USER midserver
CMD ["/opt/start.sh"]