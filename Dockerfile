FROM nightseas/cuda-torch
MAINTAINER "Álvaro Barbero Jiménez, https://github.com/albarji"

# Install system dependencies
RUN set -ex && \
	apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
	libprotobuf-dev \
	protobuf-compiler \
	wget \
	imagemagick \
	&& rm -rf /var/lib/apt/lists/*

# Install loadcaffe and other torch dependencies
RUN luarocks install loadcaffe && \
    luarocks install autograd

# Clone style-swap app
WORKDIR /
RUN set -ex && \
	wget --no-check-certificate https://github.com/rtqichen/style-swap/archive/master.tar.gz && \
	tar -xvzf master.tar.gz && \
    mv style-swap-master style-swap && \
	rm master.tar.gz

# Download precomputed VGG network weights
WORKDIR style-swap/models
RUN bash download_models.sh

# Add precomputed inverse network model
ADD model/dec-tconv-sigmoid.t7 dec-tconv-sigmoid.t7

# Prepare folder as workplace for mounting images
RUN mkdir /images

WORKDIR /style-swap
ADD entrypoint.sh /style-swap/entrypoint.sh
ENTRYPOINT ["bash", "entrypoint.sh"]
