# EPANET Regression Testing with Docker

## Purpose

This project provides a **Dockerized regression testing environment for EPANET**, ensuring that updates to the software do not introduce unintended changes. By containerizing the testing process, users can run **regression tests** and **custom/private test suites** without needing to manually install dependencies or configure their system.

## Quick Start

### **1️⃣ Build the Docker Image**

To set up the test environment, build the Docker image:

```sh
docker build -t epanet-regtest .
```

### **2️⃣ Run Regression Tests**

To execute the EPANET regression tests inside the container:

```sh
docker run --rm epanet-regtest
```

By default, this:

- **Builds EPANET v2.2 (reference)** and the latest version (SUT).
- **Runs both builds** through the regression test suite.
- **Compares outputs** to detect differences.

### **3️⃣ Run a Private Test Library**

If you have your own test cases stored in a directory, mount them and run:

```sh
docker run --rm -v /path/to/private/tests:/custom_tests epanet-regtest
```

- Replace `/path/to/private/tests` with the actual path to your test directory.
- The container will detect the custom tests (if `DO_CUSTOM_TEST=true`) and run them using `nrtest`.

---

## **Breakdown of the Process**

This section details how the system works and the role of each component.

### **🔹 Step 1: Build Two Versions of EPANET**

- **Files involved:** `Dockerfile`, `entrypoint.sh`
- **What happens:**
  1. **Clone EPANET twice**:
     - `REF_TAG` (default `v2.2`) → `/epanet/ref`
     - `SUT_TAG` (default `master`) → `/epanet/sut`
  2. **Compile both versions** with unit tests enabled (`-DBUILD_TESTS=ON`).
  3. **Run unit tests** using `ctest` to verify functionality.
  4. **If unit tests fail, execution stops**, preventing invalid builds from running regression tests.

### **🔹 Step 2: Download Regression Test Suite**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. The script determines the latest release tag of the `epanet-example-networks` repository.
  2. The latest test files are downloaded and extracted to `$TEST_HOME`.
  3. The extracted folder is **renamed** so the test suite is always available at a **consistent path**:
     ```
     mv epanet-example-networks-<tag>/epanet-tests "$TEST_HOME/tests"
     ```

### **🔹 Step 3: Configure nrtest**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. Two **nrtest JSON configuration files** (`apps/epanet-ref.json` and `apps/epanet-sut.json`) are generated, specifying:
     - The executable path for each build
     - Platform details
  2. This tells `nrtest` how to execute both versions of EPANET.

### **🔹 Step 4: Run Regression Tests (Standard Suite)**

- **Files involved:** `entrypoint.sh`
- **Controlled by:** `DO_STANDARD_TEST` environment variable
- **What happens:**
  1. If `DO_STANDARD_TEST=true` (the default), all `.json` test definitions in `$TEST_HOME/tests` are detected.
  2. `nrtest execute` runs EPANET on these test cases:
     - **Reference build output** → `benchmark/epanet-ref`
     - **SUT build output** → `benchmark/epanet-sut`
  3. `nrtest compare` checks for differences between the two versions.

### **🔹 Step 5: Run Private Tests (Optional)**

- **Files involved:** `entrypoint.sh`
- **Controlled by:** `DO_CUSTOM_TEST` environment variable
- **What happens:**
  1. If `DO_CUSTOM_TEST=true` and a directory is mounted at `/custom_tests`, the script detects it.
  2. `nrtest` is executed on the custom test cases.
  3. Results are saved under `benchmark/custom_sut`.

---

## **File Overview**

### **📌 Dockerfile**

Defines the container environment:

- **Base image**: `ubuntu:22.04`
- Installs dependencies (Git, CMake, Boost libraries, Python, `nrtest`, etc.).
- Copies `entrypoint.sh` to handle execution logic and sets it as the default entrypoint.

### **📌 entrypoint.sh**

Controls the full test lifecycle:

1. **Builds two EPANET versions** (`REF_TAG` and `SUT_TAG`).
2. **Runs unit tests** before proceeding to regression testing.
3. **Downloads test cases** (if `DO_STANDARD_TEST=true`).
4. **Runs `nrtest`** for standard and/or private test suites (based on the `DO_STANDARD_TEST` and `DO_CUSTOM_TEST` flags).

### **📌 Regression Test Suite (`epanet-example-networks`)**

Contains:

- `.json` test definitions.
- `.inp` input files for EPANET.
- Expected output reference files (if needed).

---

## **Extending the System**

### **Modifying Tests**

- You can manually edit test `.json` files in the `tests/` directory to add or modify test cases.
- If using a private test suite, simply mount your folder with `-v`.

### **Testing Different EPANET Versions**

- Modify `REF_TAG` and `SUT_TAG` to compare **any two versions** of EPANET.
- Example: Compare `v2.2` to a feature branch:

```sh
docker run --rm -e REF_TAG="v2.2" -e SUT_TAG="feature-branch" epanet-regtest
```

---

### **Summary of Key Commands**

| Action                                    | Command                                                                                                          |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Build the image                           | `docker build -t epanet-regtest .`                                                                               |
| Run with default comparison (SUT vs v2.2) | `docker run --rm epanet-regtest`                                                                                 |
| Run with specific SUT & REF tags          | `docker run --rm -e REF_TAG="v2.2" -e SUT_TAG="mybranch" epanet-regtest`                                         |
| Skip standard tests (only run custom)     | `docker run --rm -e DO_STANDARD_TEST=false -e DO_CUSTOM_TEST=true -v /path/on/host:/custom_tests epanet-regtest` |
| Run both standard & custom tests          | `docker run --rm -e DO_STANDARD_TEST=true -e DO_CUSTOM_TEST=true -v /path/on/host:/custom_tests epanet-regtest`  |
| Open interactive shell                    | `docker run -it --entrypoint /bin/bash epanet-regtest`                                                           |
| Run entrypoint manually inside shell      | `/entrypoint.sh`                                                                                                 |
| Force rebuild                             | `docker build --no-cache -t epanet-regtest .`                                                                    |

---

## **Final Notes**

This setup ensures that **EPANET regression testing is automated, reliable, and reproducible**. By comparing against a **freshly built v2.2 reference**, any changes in the software can be detected immediately.

Simply **build the image, run the tests, and analyze the results!** 🚀
