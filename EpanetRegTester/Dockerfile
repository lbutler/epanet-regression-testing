#----------------------------------------------------------------------
# Stage 1: Build EPANET Library and Executable from a specific version
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
        # Configure CMake - Build shared library and executable
        cmake .. -DBUILD_SHARED_LIBS=ON && \
        echo "INFO: Building EPANET library and executable..." && \
        # Build everything (including runepanet executable and the library)
        make -j$(nproc)
    
    #----------------------------------------------------------------------
    # Stage 2: Final Image with Tester and EPANET Tools
    #----------------------------------------------------------------------
    FROM ubuntu:22.04
    
    # Install runtime dependencies (build-essential needed for g++)
    RUN apt-get update && apt-get install -y \
        build-essential \
        g++ \
        make \
        bash \
        # libc-bin provides ldconfig
        libc-bin \
        && rm -rf /var/lib/apt/lists/*
    
    # Set working directory (primarily for the regtester)
    WORKDIR /app
    
    # --- CORRECTED LIBRARY COPY ---
    # Copy the compiled EPANET library from the builder stage to a standard location
    COPY --from=builder /epanet_build/src/build/lib/libepanet2.so /usr/local/lib/libepanet2.so
    COPY --from=builder /epanet_build/src/build/lib/libepanet2.so ./libepanet2.so
    # --- END CORRECTION ---
    
    # Copy the compiled runepanet executable from the builder stage to a standard location
    COPY --from=builder /epanet_build/src/build/bin/runepanet /usr/local/bin/runepanet
    
    # Update the dynamic linker cache to recognize the new library (good practice)
    RUN ldconfig
    
    # Copy the C++ source code and test data files (needed for testing mode)
    COPY regtester.cpp .
    COPY OWAFile/ ./OWAFile/
    
    # Compile the C++ program, linking against the library
    # The linker will now find libepanet2.so in the standard path (/usr/local/lib)
    # so -L. is not strictly needed for libepanet2, but keep -Wl,-rpath,'$ORIGIN'
    # if runregtester might load other libs from /app in the future.
    # Alternatively, since libepanet2.so is now in a standard path, we might not
    # need rpath for it anymore either, but let's keep it for now.
    RUN g++ -std=c++17 regtester.cpp -o runregtester -ldl -lepanet2 -Wl,-rpath,'$ORIGIN'
    
    # Default entrypoint (for running regression tests)
    ENTRYPOINT ["./runregtester", "./OWAFile", "."]
    
    # Note: The reference generation will override this entrypoint
    