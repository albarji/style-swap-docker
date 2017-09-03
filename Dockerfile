FROM kaixhin/cuda-torch
MAINTAINER "Álvaro Barbero Jiménez, https://github.com/albarji"

# Install system dependencies
RUN set -ex && \
	apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
	libprotobuf-dev \
	protobuf-compiler \
	wget \
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

# Download precomputed network weights
WORKDIR style-swap/models
RUN bash download_models.sh

# Add adain-style to path
ENV PATH /style-swap:$PATH
#ENV LUA_PATH /adain-style/?;$LUA_PATH
RUN echo 'export LUA_PATH="/style-swap/?.lua;/style-swap/lib/?.lua;${LUA_PATH}"' >> ~/.bashrc
#ENV LUA_CPATH /adain-style/?;$LUA_CPATH
RUN echo 'export LUA_CPATH="/style-swap/?.lua;/style-swap/lib/?.lua;${LUA_CPATH}"' >> ~/.bashrc

# Prepare folder as workplace for mounting images
#WORKDIR /images
WORKDIR /style-swap

#ENTRYPOINT ["th", "/adain-style/test.lua"]
#ENTRYPOINT ["th", "test.lua"]
ENTRYPOINT ["th", "/style-swap/style-swap.lua"]

##############TODO: from neural-style

# Declare volume for storing network weights
#VOLUME ["/neural-style/models"]

# Copy wrapper scripts
#COPY ["/scripts/variants.sh", "/scripts/neural-style.sh", "/neural-style/"]

# Prepare folder for mounting images and workplaces
#WORKDIR /images
#VOLUME ["/images"]

#ENTRYPOINT ["neural-style.sh"]
#CMD ["-backend", "cudnn", "-cudnn_autotune"]

