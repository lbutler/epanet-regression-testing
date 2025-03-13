# EPANET Regression Testing with Docker

## Purpose

This project provides a **Dockerized regression testing environment for EPANET**, ensuring that updates to the software do not introduce unintended changes. By containerizing the testing process, users can run **official regression tests** and **custom/private test suites** without needing to manually install dependencies or configure their system.

## Quick Start

### **1️⃣ Build the Docker Image**

To set up the test environment, build the Docker image:

```sh
docker build -t epanet-regtest .
```

### **2️⃣ Run the Official Test Suite**

To execute the official EPANET regression tests inside the container:

```sh
docker run --rm epanet-regtest
```

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

### **🔹 Step 1: Build EPANET with Unit Tests**

- **Files involved:** `Dockerfile`, `entrypoint.sh`
- **What happens:**
  1. **Clone EPANET**: The Docker container checks if EPANET is already present; if not, it clones the latest version.
  2. **Compile EPANET with unit tests enabled** (`-DBUILD_TESTS=ON`).
  3. **Run EPANET unit tests** using `ctest` to verify functionality.
  4. **If unit tests fail, execution stops**, preventing invalid builds from running regression tests.

### **🔹 Step 2: Download Official Test Suite**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. The script determines the latest release tag of the official `epanet-example-networks` repository.
  2. The latest test files are downloaded and extracted.
  3. A symbolic link is created (`tests -> epanet-example-networks-<tag>/epanet-tests`) so the test suite is always available at a consistent path.

### **🔹 Step 3: Configure nrtest**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. A JSON configuration file (`apps/epanet-local.json`) is generated, specifying:
     - The executable path
     - Platform details
     - Any necessary setup scripts
  2. This configuration file tells `nrtest` how to execute EPANET.

### **🔹 Step 4: Run Regression Tests**

- **Files involved:** `entrypoint.sh`
- **What happens:**
  1. All `.json` test definitions in `tests/*/*.json` are detected using `ls -1`.
  2. `nrtest execute` runs EPANET against these test cases.
  3. If a reference benchmark exists, `nrtest compare` checks if results match expected outputs.
  4. Results are stored in the `benchmark/` directory inside the container.

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

- Builds EPANET with unit tests enabled.
- Runs **EPANET unit tests** before proceeding to regression testing.
- Downloads test cases.
- Runs `nrtest` for official and private test suites.

### **📌 Official Test Suite (`epanet-example-networks`)**

Contains:

- `.json` test definitions.
- `.inp` input files for EPANET.
- Expected output reference files.

---

## **Extending the System**

### **Modifying Tests**

- You can manually edit test `.json` files in the `tests/` directory to add or modify test cases.
- If using a private test suite, simply mount your folder with `-v`.

### **Using a Different EPANET Version**

- Modify `EPANET_REPO` in `entrypoint.sh` to test a different version.

---

## **Final Notes**

With this setup, anyone can **quickly verify EPANET's behavior** across multiple test cases, without worrying about installation or system dependencies. Simply **build the image, run tests, and analyze results!** 🚀
