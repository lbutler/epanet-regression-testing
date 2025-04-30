This archive contains a Regression Testing app for OWA-EPANET.

runregtests.exe is the command line executable that runs the regression tests.
It requires two arguments:
- the directory where the EPANET test input files reside along with their
  binary output files that were generated using the most current official release.
- the directory where the test version of the epanet2.dll resides.

OWAFiles contains the latest set of benchmark files that OWA-EPANET uses for testing
along with a config.txt file that regression tester requires.

epanet2.dll is the latest dev version of the EPANET 2.3 toolkit library.

regtester.cpp is the source code (C++17) for the tester.

To run a regression test using these files, issue the following command in a
console window:

runregtests OWAFile .

(don't forget the period).

Linux Compilation Instructions:
----------------------------
1. Ensure you have the required build tools installed:
   sudo apt-get update
   sudo apt-get install build-essential g++ make

2. Compile the program:
   g++ -std=c++17 regtester.cpp -o runregtester -ldl -L. -lepanet2 -Wl,-rpath,$PWD

3. Run the tests:
   ./runregtester OWAFile .


Note: Make sure you have the appropriate EPANET library (libepanet2.so) in the current directory.

Mac Compilation Instructions:
--------------------------
1. Ensure you have the required build tools installed:
   - Install Xcode Command Line Tools if not already installed:
     xcode-select --install

2. Compile the program:
   g++ -std=c++17 regtester.cpp -o regtester -ldl

3. Run the tests:
   ./regtester ./OWAFile .

Note: Make sure you have the appropriate EPANET library (libepanet2.dylib) in the current directory.

Docker Usage:
------------
1. Build the Docker image:
   docker build --platform linux/amd64 -t epanet-regtester .

2. Run the tests:
   docker run epanet-regtester

Note: The Docker build requires the --platform flag when building on Apple Silicon (M1/M2) Macs.

