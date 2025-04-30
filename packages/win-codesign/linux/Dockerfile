FROM --platform=linux/x86_64 buildpack-deps:bionic-curl

RUN apt-get -qq update && apt-get -qq upgrade && apt-get install -qq cmake python3-pip  libssl-dev libcurl4-openssl-dev zlib1g-dev python3 libssl-dev libcurl4-openssl-dev libgsf-1-dev autoconf build-essential unzip libtool

RUN curl -L https://github.com/mtrojnar/osslsigncode/archive/refs/tags/2.9.zip -o f.zip
RUN unzip f.zip && rm f.zip

# RUN cd osslsigncode-2.9 && ./autogen.sh && ./configure --prefix=/usr/local && make && make install
RUN curl -L https://github.com/Kitware/CMake/releases/download/v4.0.1/cmake-4.0.1-linux-x86_64.sh -o f.sh

RUN mkdir /opt/cmake && sh f.sh --skip-license --include-subdir --prefix=/opt/cmake
RUN ln -s /opt/cmake/cmake-4.0.1-linux-x86_64/bin/cmake /usr/local/bin/cmake

RUN cd osslsigncode-2.9 && mkdir build && cd build && cmake -S .. && cmake --build .

CMD cp /osslsigncode-2.9/build/osslsigncode /files/osslsigncode
