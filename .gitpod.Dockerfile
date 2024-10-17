FROM gitpod/workspace-full

ENV LUA_VERSION 5.3.4
ENV LUAROCKS_VERSION 2.4.4

# Install lua runtime
RUN cd /workspace && \
  curl -L http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz | tar xzf - && \
  cd /workspace/lua-${LUA_VERSION} && \
  make linux test && \
  sudo make install

# Install luarocks
RUN cd /workspace && \
  curl -L https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz | tar xzf - && \
  cd /workspace/luarocks-${LUAROCKS_VERSION} && \
  ./configure && \
  make build && \
  sudo make install

RUN echo "trigger rebuild 1235"

# Install ao dev-cli
RUN curl -fsSL https://install_ao.g8way.io | bash
RUN echo 'export AO_INSTALL=/home/gitpod/.ao' >> /home/gitpod/.bashrc.d/101-ao && \
  echo 'export PATH="$AO_INSTALL/bin:$PATH"' >> /home/gitpod/.bashrc.d/101-ao
