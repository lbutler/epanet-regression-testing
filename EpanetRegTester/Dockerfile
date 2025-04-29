# Use Ubuntu as base image with C++17 support
FROM --platform=linux/amd64 ubuntu:22.04

# Install build essentials and required packages
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the source code and library files
COPY regtester.cpp .
COPY libepanet2.so .
COPY OWAFile/ ./OWAFile/

# Compile the C++ program with proper flags
RUN g++ -std=c++17 regtester.cpp -o runregtester -ldl -L. -lepanet2 -Wl,-rpath,$PWD

# Set the entrypoint to run the regression tests
ENTRYPOINT ["./runregtester", "./OWAFile", "."] 