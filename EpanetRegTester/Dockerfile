#----------------------------------------------------------------------
# Stage 1: Build EPANET Library from a specific version
#----------------------------------------------------------------------
    FROM ubuntu:22.04 AS builder

    # Install build dependencies for EPANET
    RUN apt-get update && apt-get install -y \
        git \
        cmake \
        build-essential \
        make \
        && rm -rf /var/lib/apt/lists/*
    
    # Argument to specify the EPANET version (commit, tag, or branch)
    ARG EPANET_VERSION="master"
    ENV EPANET_VERSION=${EPANET_VERSION}
    
    # Set working directory for EPANET source
    WORKDIR /epanet_build
    
    # Clone EPANET repository
    RUN git clone https://github.com/OpenWaterAnalytics/EPANET.git src
    
    # Checkout the specified version and build
    RUN cd src && \
        echo "INFO: Checking out EPANET version: ${EPANET_VERSION}" && \
        # Fetch the specific ref just in case it's a commit not locally known
        (git fetch origin "${EPANET_VERSION}" || echo "INFO: Fetch failed, assuming branch/tag already known.") && \
        git checkout "${EPANET_VERSION}" && \
        echo "INFO: Configuring EPANET build..." && \
        mkdir build && \
        cd build && \
        # Configure CMake - Assuming default builds shared library needed
        cmake .. && \
        echo "INFO: Building EPANET library..." && \
        # Build only the epanet2 target (library) for efficiency
        make epanet2 -j$(nproc)
    
    #----------------------------------------------------------------------
    # Stage 2: Build and Run the Regression Tester
    #----------------------------------------------------------------------
    FROM ubuntu:22.04
    
    # Install runtime dependencies (build-essential needed for g++)
    RUN apt-get update && apt-get install -y \
        build-essential \
        g++ \
        make \
        && rm -rf /var/lib/apt/lists/*
    
    # Set working directory
    WORKDIR /app
    
    # Copy the compiled EPANET library from the builder stage
    COPY --from=builder /epanet_build/src/build/lib/libepanet2.so .
    
    # Copy the C++ source code and test data files
    COPY regtester.cpp .
    COPY OWAFile/ ./OWAFile/
    
    # Compile the C++ program, linking against the copied library
    # -L. tells the linker to look in the current directory for libraries
    # -Wl,-rpath,$PWD embeds the current path into the executable so it finds the .so at runtime
    RUN g++ -std=c++17 regtester.cpp -o runregtester -ldl -L. -lepanet2 -Wl,-rpath,'$ORIGIN'
    
    # Set the entrypoint to run the regression tests
    ENTRYPOINT ["./runregtester", "./OWAFile", "."]