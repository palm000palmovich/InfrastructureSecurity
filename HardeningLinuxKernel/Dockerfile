FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        build-essential strace nano \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash victim && echo "victim:victim" | chpasswd

CMD ["/bin/bash"]
