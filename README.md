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
- **Runs both builds through the regression test suite.**
- **Compares outputs** to detect differences.

### **3️⃣ Run a Private Test Library**

If you have your own test cases stored in a directory, mount them and run:

```sh
docker run --rm -v /path/to/private/tests:/custom_tests epanet-regtest
```

- Replace `/path/to/private/tests` with the actual path to your test directory.
- The container will detect the custom tests and run them using `nrtest`.

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
  2. The latest test files are downloaded and extracted.
  3. A symbolic link is created (`tests -> epanet-example-networks-<tag>/epanet-tests`) so the test suite is always available at a consistent path.

### **🔹 Step 3: Configure nrtest**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. Two **nrtest JSON configuration files** (`apps/epanet-ref.json` and `apps/epanet-sut.json`) are generated, specifying:
     - The executable path for each build
     - Platform details
  2. This tells `nrtest` how to execute both versions of EPANET.

### **🔹 Step 4: Run Regression Tests**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. All `.json` test definitions in `tests/*/*.json` are detected.
  2. `nrtest execute` runs EPANET on the test cases:
     - **Reference build output** → `benchmark/epanet-ref`
     - **SUT build output** → `benchmark/epanet-sut`
  3. `nrtest compare` checks for differences between the two versions.

### **🔹 Step 5: Run Private Tests (Optional)**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. If a directory is mounted at `/custom_tests`, the script detects it.
  2. `nrtest` is executed on the custom test cases.
  3. Results are saved under `benchmark/custom_<build_id>`.

---

## **File Overview**

### **📌 Dockerfile**

Defines the container environment:

- Installs dependencies (CMake, Boost, Python, `nrtest`, etc.).
- Copies `entrypoint.sh` to handle execution logic.

### **📌 entrypoint.sh**

Controls the full test lifecycle:

- Builds **two** EPANET versions (`REF_TAG` and `SUT_TAG`).
- Runs **unit tests** before proceeding to regression testing.
- Downloads test cases.
- Runs `nrtest` for standard and private test suites.

### **📌 Regression Test Suite (`epanet-example-networks`)**

Contains:

- `.json` test definitions.
- `.inp` input files for EPANET.
- Expected output reference files.

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

| Action                                    | Command                                                                                                         |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Build the image                           | `docker build -t epanet-docker .`                                                                               |
| Run with default comparison (SUT vs v2.2) | `docker run --rm epanet-docker`                                                                                 |
| Run with specific SUT & REF tags          | `docker run --rm -e REF_TAG="v2.2" -e SUT_TAG="mybranch" epanet-docker`                                         |
| Skip standard tests (only run custom)     | `docker run --rm -e DO_STANDARD_TEST=false -e DO_CUSTOM_TEST=true -v /path/on/host:/custom_tests epanet-docker` |
| Run both standard & custom tests          | `docker run --rm -e DO_STANDARD_TEST=true -e DO_CUSTOM_TEST=true -v /path/on/host:/custom_tests epanet-docker`  |
| Open interactive shell                    | `docker run -it --entrypoint /bin/bash epanet-docker`                                                           |
| Run entrypoint manually inside shell      | `/entrypoint.sh`                                                                                                |
| Force rebuild                             | `docker build --no-cache -t epanet-docker .`                                                                    |

---

## **Final Notes**

This setup ensures that **EPANET regression testing is automated, reliable, and reproducible**. By comparing against a **freshly built v2.2 reference**, any changes in the software can be detected immediately.

Simply **build the image, run the tests, and analyze the results!** 🚀
