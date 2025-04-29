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

runregtests OWAFiles .

(don't forget the period).

