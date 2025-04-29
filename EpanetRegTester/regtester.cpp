/******************************************************************************
REGTESTER - a regression testing program for the OWA-EPANET Toolkit.

Usage:
  runregtests <test_files_path> <epanet2.dll_path>

<test_files_path> is the directory where a collection of EPANET input files and
their corresponding reference (or benchmark) binary output files reside. This
directory should also include a file named config.txt that contains the absolute
and relative tolerances used for testing on its first line followed by the name
of each test file (without an extension) on each subsequent line.

<epanet2.dll_path> is the directory where the EPANET Toolkit's epanet2.dll
file being tested resides. REGTESTER will run each of the test input files
through this DLL and compare the results obtained against those in the reference
output files to see if they pass the "closeness" test.
*******************************************************************************/
#include <windows.h>
#include <filesystem>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <cmath>
using namespace std;

// Absolute & relative tolerances used for closeness testing
float absTol, relTol;

// Path to test files & epanet2.dll
string testPath;
string dllPath;

// Names used for the report and output files of each test
string rptFile = "test.rpt";
string outFile = "test.out";

// Collection of names of input files to be tested
vector<string> testFiles;

// Information about a failing test
typedef struct {
	int count;      // number of elements failing
	int node;       // index of node with largest difference
	int link;       // index of link with largest difference
	int var;        // index of variable with largest difference
	int period;     // time period at largest difference
	float vTest;    // test value at largest  difference
	float vRef;     // reference value at largest difference
	float maxDiff;  // largest difference between test and reference values
	string ID;      // ID of element with largest difference
} TFailInfo;

// Names of EPANET output variables being compared
const char* NodeVars[] = {"", "Demand", "Head", "Pressure", "Quality" };
const char* LinkVars[] = {"", "Flow", "Velocity", "Head Loss", "Quality", "Status",
                            "Setting", "Reaction Rate", "Friction Factor" };

// Function in the EPANET toolkit that runs a simulation
typedef int (*RunFunc) (const char*, const char*, const char*, void*);
RunFunc runEpanet;

// Properties of EPANET's binary output files
int numNodes, numLinks, numPeriods, startBytePos, reportStart, reportStep;
const int RECORDSIZE = 4;

// Indentation used for reporting test results
size_t indent;

// Function prototypes
int  readConfigFile(string configFile);
int  loadEpanetDLL(HMODULE& hDLL);
void getOutFileProperties(ifstream& ftest);

int  runAllTests();
int  runSingleTest(const string inpFile, const string refOutFile,
	               string& result, TFailInfo& failInfo);
int  compareResults(ifstream& fTest, ifstream& fRef, TFailInfo& failInfo);
bool isClose(float x, float y);

void updateFailureInfo(float vTest, float vRef, int node, int link,
	                   int var, int period, TFailInfo& failInfo);
void findFailureID(ifstream& fTest, TFailInfo& failInfo);
void writeFailureInfo(TFailInfo failInfo);

int main(int argc, char* argv[]) {

	int status = 0;
	HMODULE hDLL = NULL;

	// Check command line arguments
	if (argc < 3) {
		cout << endl << "Usage:" << endl << argv[0] <<
			" <test_files_path>" << " <epanet2.dll_path>" << endl;
		return 1;
	}
	cout << endl <<
		"OWA-EPANET Regression Tests" << endl <<
		"---------------------------" << endl;

	// Read configuration file & load EPANET DLL function
	testPath = argv[1];
	testPath = testPath + "\\";
	dllPath = argv[2];
	status = readConfigFile(testPath + "\\config.txt");
	if (status == 0) status = loadEpanetDLL(hDLL);

	// Run regression tests
	if (status == 0) {
		status = runAllTests();
	}

	// Free resources
	if (hDLL) FreeLibrary(hDLL);
	filesystem::remove(rptFile);
	filesystem::remove(outFile);

	// Set program's return value
	if (status > 0) return 1;
	else return 0;
}

int readConfigFile(string configFile) {

	int  status = 0;
	indent = 0;

	// Open configuration file
	ifstream file(configFile);
	if (file.is_open()) {

		// Read closeness tolerances
		string line;
		getline(file, line);
		stringstream ss(line);
		ss >> absTol >> relTol;
		if (ss.fail()) {
			cout << "Error reading tolerances." << endl;
			status = 1;
		}

		// Save names of test files (with any whitespace stripped off) to testFiles
		else while (getline(file, line)) {
			// This code should remove any whitespace surrounding the file name
			ss.str(line);
			ss >> line;
			testFiles.push_back(line);
			indent = max(indent, line.length());
		}
		indent += 2;
		file.close();
	}

	// Configuration file couldn't be opened
	else {
        cout << endl << "Could not open test configuration file - test terminated." << endl;
        status = 1;
	}
	return status;
}

int loadEpanetDLL(HMODULE& hDLL) {

	// Get a pointer to the EPANET toolkit library DLL
	string filename = dllPath + "\\epanet2.dll";
	hDLL = LoadLibraryA(filename.c_str());
	if (hDLL == NULL) {
		cout << endl << "Could not load EPANET DLL - test terminated." << endl;
		return 1;
	}

	// Get address of the ENepanet function in the library
	runEpanet = (RunFunc)GetProcAddress(hDLL, "ENepanet");
	if (runEpanet == NULL) {
		cout << endl <<
			"Could not load function from epanet2.dll - test terminated." << endl;
		return 1;
	}
	return 0;
}

int runAllTests() {

	TFailInfo failInfo;
	string result;
	int status = 0;
	int testCount = 0;
	int failCount = 0;

    // For each test file
	for (const string& testFile : testFiles) {

		// Initialize failure information
		failInfo.count = 0;
		failInfo.node = -1;
		failInfo.link = -1;
		failInfo.maxDiff = 0;

		// Create input and output file names for testing
		string inpFile = testPath + testFile + ".inp";
		string refOutFile = testPath + testFile + ".out";

		// Check that files exist
		if (!filesystem::exists(inpFile) || !filesystem::exists(refOutFile)) {
			result = "file does not exist.";
		}

		// Files exist so run test
		else {
		    testCount++;
			status = runSingleTest(inpFile, refOutFile, result, failInfo);
		}

		// Write results
		cout << left << setw(indent) << testFile+": " << result << endl;
		if (failInfo.count > 0) {
			failCount++;
			status = 1;
			writeFailureInfo(failInfo);
		}
	}
	cout << endl << to_string(testCount) << " files were tested with " <<
		to_string(testCount - failCount) << " passing and " <<
		to_string(failCount) << " failing." << endl;
	return status;
}

int runSingleTest(const string inpFile, const string refOutFile,
	              string& result, TFailInfo& failInfo) {

	// Run the input file through the EPANET version being tested
	int status = runEpanet(inpFile.c_str(), rptFile.c_str(), outFile.c_str(), NULL);

	// Check that EPANET ran successfully
	if (status > 100) {
		result = "EPANET run failed with status code " + to_string(status);
		return 1;
	}

	// Check that test & reference output files have same size
	if (filesystem::file_size(outFile) != filesystem::file_size(refOutFile)) {
		result = "Test and reference results files have different sizes.";
		return 1;
	}

	// Open the two output files & retrieve their properties
	ifstream fTest(outFile, ios::binary);
	if (fTest.is_open() == false) {
		result = "Could not open test output file.";
		return 1;
	}
	ifstream fRef(refOutFile, ios::binary);
	if (fRef.is_open() == false) {
		result = "Could not open reference output file.";
		fTest.close();
		return 1;
	}
	getOutFileProperties(fTest);

	// Compare contents of test and reference binary files
	status = compareResults(fTest, fRef, failInfo);
	if (status == 0) result = "passed";
	else result = "FAILED";
	fTest.close();
	fRef.close();
	return status;
}

void getOutFileProperties(ifstream& fTest) {

	// Retrieve number of elements in the EPANET file being tested
	int numTanks, numPumps;
	fTest.seekg(2 * RECORDSIZE, ios::beg);
	fTest.read(reinterpret_cast<char*>(&numNodes), sizeof(numNodes));
	fTest.read(reinterpret_cast<char*>(&numTanks), sizeof(numTanks));
	fTest.read(reinterpret_cast<char*>(&numLinks), sizeof(numLinks));
	fTest.read(reinterpret_cast<char*>(&numPumps), sizeof(numPumps));

	// Retrieve report times
	fTest.seekg(6 * RECORDSIZE, ios::cur);
	fTest.read(reinterpret_cast<char*>(&reportStart), sizeof(reportStart));
	fTest.read(reinterpret_cast<char*>(&reportStep), sizeof(reportStep));

	// Retrieve number of time periods simulated (3 records before end of file)
	fTest.seekg(-3 * RECORDSIZE, ios::end);
	fTest.read(reinterpret_cast<char*>(&numPeriods), sizeof(numPeriods));

	// Find position in file where computed results begin
	startBytePos = 884 + 36 * numNodes + 52 * numLinks + 8 * numTanks + 28 * numPumps + 4;
}

int compareResults(ifstream& fTest, ifstream& fRef, TFailInfo& failInfo) {

	float vTest, vRef;  // value of a test result and its corresponding reference value
	int numNodeVars = 4;  // see NodeVars[]
	int numLinkVars = 8;  // see LinkVars[]

	// Position output files to where simulation results begin
	fTest.seekg(startBytePos);
	fRef.seekg(startBytePos);

	// For each time period
	for (int t = 1; t <= numPeriods; t++) {

		// For each Node variable
		for (int i = 1; i <= numNodeVars; i++) {

			// For each Node
			for (int j = 1; j <= numNodes; j++) {
				fTest.read(reinterpret_cast<char*>(&vTest), sizeof(vTest));
				fRef.read(reinterpret_cast<char*>(&vRef), sizeof(vRef));
				if (!isClose(vTest, vRef))
					updateFailureInfo(vTest, vRef, j, -1, i, t, failInfo);
			}
		}

		// For each Link variable
		for (int i = 1; i <= numLinkVars; i++) {

			// For each Link
			for (int j = 1; j <= numLinks; j++) {
				fTest.read(reinterpret_cast<char*>(&vTest), sizeof(vTest));
				fRef.read(reinterpret_cast<char*>(&vRef), sizeof(vRef));
				if (!isClose(vTest, vRef))
					updateFailureInfo(vTest, vRef, -1, j, i, t, failInfo);
			}
		}
	}
	if (failInfo.count > 0) {
		findFailureID(fTest, failInfo);
		return 1;
	}
	return 0;
}

bool isClose(float x, float y) {

	return fabs(x - y) <= absTol + relTol * fabs(y);
}

void updateFailureInfo(float vTest, float vRef, int node, int link, int var,
	                   int period, TFailInfo& failInfo) {

	float diff = fabs(vTest - vRef);
	failInfo.count++;
	if (diff > failInfo.maxDiff) {
		failInfo.maxDiff = diff;
		failInfo.node = node;
		failInfo.link = link;
		failInfo.var = var;
		failInfo.period = period;
		failInfo.vTest = vTest;
		failInfo.vRef = vRef;
	}
}

void findFailureID(ifstream& fTest, TFailInfo& failInfo) {

	char id[32];       // size of EPANET element ID's
	int offset = 884;  // byte offset into ftest where element ID's begin
	failInfo.ID = "";

	// Find position in file where failing element ID appears
	if (failInfo.node > 0)
		offset = offset + ((failInfo.node - 1) * 32);
	else if (failInfo.link > 0)
		offset = offset + (numNodes * 32) + ((failInfo.link - 1) * 32);
	else return;

	// Read the ID from the file
	fTest.seekg(offset, ios::beg);
	fTest.read(id, sizeof(id));
	string s(id);
	failInfo.ID = s;
}

string getFailureTime(int period) {

	int seconds = reportStart + (period - 1) * reportStep;
	int hours = seconds / 3600;
	int minutes = (seconds - 3600 * hours) / 60;
	seconds = seconds - 3600 * hours - 60 * minutes;
	stringstream ss;
	ss << to_string(hours) << ":" << setw(2) << setfill('0') << to_string(minutes) <<
		":" << setw(2) << setfill('0') << to_string(seconds);
	return ss.str();
}

void writeFailureInfo(TFailInfo failInfo) {

	cout << setw(indent) << " " << "There were " << to_string(failInfo.count) <<
		" results failing." << endl;
	cout << setw(indent) << " " << "Largest difference occurred for ";
	if (failInfo.node >= 0)
		cout << "Node " << failInfo.ID << " " << NodeVars[failInfo.var];
	else
		cout << "Link " << failInfo.ID << " " << LinkVars[failInfo.var];
	cout << " at time " << getFailureTime(failInfo.period) << " hrs" << endl;
	cout << setw(indent) << " " << "SUT value: " << to_string(failInfo.vTest) << endl;
	cout << setw(indent) << " " << "Ref value: " << to_string(failInfo.vRef) << endl;
}
