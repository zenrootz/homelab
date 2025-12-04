# Dockerfile for Qwen Multimodal Agent using pre-built binaries
FROM registry.fedoraproject.org/fedora:latest

# Install runtime dependencies
RUN dnf install -y \
    rocm-opencl \
    rocm-smi \
    clblast \
    python3 \
    python3-pip \
    curl \
    jq \
    && dnf clean all

# Copy pre-built binaries from host
COPY llama.cpp/build/bin/llama-server /usr/local/bin/
COPY llama.cpp/build/bin/libllama.so* /usr/local/lib/
COPY llama.cpp/build/bin/libggml*.so* /usr/local/lib/
COPY llama.cpp/build/bin/libmtmd.so* /usr/local/lib/

# Update library path
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Create model directory
RUN mkdir -p /models

# Set working directory
WORKDIR /app

# Default command
CMD ["/usr/local/bin/llama-server"]