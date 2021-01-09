# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



# Common entry point to run JAPL's tests
#
# - Assumes "japl" binary in ../src/japl built with all debugging off
# - Goes through all tests in (/tests/)
# - Runs all tests in (/tests/)japl/ and checks their output (marked by `//output:{output}`)
# 

# Imports nim tests as well
import multibyte, os, strformat, times, re


# Exceptions for tests that represent not-yet implemented behaviour
const exceptions = ["all.jpl"]


proc compileExpectedOutput(path: string): string =
    for line in path.lines():
        if line =~ re"^.*//output:(.*)$":
            result &= matches[0] & "\n"


proc deepComp(left, right: string): tuple[same: bool, place: int] =
    result.same = true
    if left.high() != right.high():
        result.same = false
    for i in countup(0, left.high()):
        result.place = i
        if i > right.high():
            # already false because of the len check at the beginning
            # already correct place because it's updated every i
            return
        if left[i] != right[i]:
            result.same = false
            return


# Quick logging levels using procs

proc log(file: File, msg: string, toFile: bool = true) =
    ## Logs to stdout and to the log file unless
    ## toFile == false
    if toFile:
        file.writeLine(&"[LOG - {$getTime()}] {msg}")
    echo &"[LOG - {$getTime()}] {msg}"


proc detail(file: File, msg: string) =
    ## Logs only to the log file
    file.writeLine(&"[DETAIL - {$getTime()}] {msg}")


proc main(testsDir: string, japlExec: string, testResultsFile: File): tuple[numOfTests: int, successTests: int, failedTests: int, skippedTests: int] =
    var numOfTests = 0
    var successTests = 0
    var failedTests = 0
    var skippedTests = 0
    try:
        for file in walkDir(testsDir):
            block singleTest:
                for exc in exceptions:
                    if exc == file.path.extractFilename:
                        detail(testResultsFile, &"Skipping '{file.path}'")
                        numOfTests += 1
                        skippedTests += 1
                        break singleTest
                if file.path.dirExists():
                    detail(testResultsFile, "Descending into '" & file.path & "'")
                    var subTestResult = main(file.path, japlExec, testResultsFile)
                    numOfTests += subTestResult.numOfTests
                    successTests += subTestResult.successTests
                    failedTests += subTestResult.failedTests
                    skippedTests += subTestResult.skippedTests
                    break singleTest
                detail(testResultsFile, &"Running test '{file.path}'")
                if fileExists("testoutput.txt"):
                    removeFile("testoutput.txt") # in case this crashed
                let retCode = execShellCmd(&"{japlExec} {file.path} >> testoutput.txt")
                numOfTests += 1
                if retCode != 0:
                    failedTests += 1
                    log(testResultsFile, &"Test '{file.path}' has crashed!")
                else:
                    successTests += 1
                    let expectedOutput = compileExpectedOutput(file.path).replace(re"(\n*)$", "")
                    let realOutputFile = open("testoutput.txt", fmRead)
                    let realOutput = realOutputFile.readAll().replace(re"([\n\r]*)$", "")
                    realOutputFile.close()
                    removeFile("testoutput.txt")
                    let comparison = deepComp(expectedOutput, realOutput)
                    if comparison.same:
                        log(testResultsFile, &"Test '{file.path}' was successful")
                    else:
                        detail(testResultsFile, &"Expected output:\n{expectedOutput}\n")
                        detail(testResultsFile, &"Received output:\n{realOutput}\n")
                        detail(testResultsFile, &"Mismatch at pos {comparison.place}")
                        if comparison.place > expectedOutput.high() or 
                            comparison.place > realOutput.high():
                            detail(testResultsFile, &"Length mismatch")
                        else:
                            detail(testResultsFile, &"Expected is '{expectedOutput[comparison.place]}' while received '{realOutput[comparison.place]}'")
                        log(testResultsFile, &"Test '{file.path}' failed")
        result = (numOfTests: numOfTests, successTests: successTests, failedTests: failedTests, skippedTests: skippedTests)
    except IOError:
        stderr.write(&"Fatal IO error encountered while running tests -> {getCurrentExceptionMsg()}")


when isMainModule:
    let testResultsFile = open("testresults.txt", fmWrite)
    log(testResultsFile, "Running Nim tests")
    # Nim tests
    detail(testResultsFile, "Running testMultiByte")
    testMultiByte()
    # JAPL tests
    log(testResultsFile, "Running JAPL tests")
    var testsDir = "tests" / "japl"
    var japlExec = "src" / "japl"
    var currentDir = getCurrentDir()
    # Supports running from both the project root and the tests dir itself
    if currentDir.lastPathPart() == "tests":
        testsDir = "japl"
        japlExec = ".." / japlExec
    log(testResultsFile, &"Looking for JAPL tests in {testsDir}")
    log(testResultsFile, &"Looking for JAPL executable at {japlExec}")
    if not fileExists(japlExec):
        log(testResultsFile, "JAPL executable not found")
        quit(1)
    if not dirExists(testsDir):
        log(testResultsFile, "Tests dir not found")
        quit(1)
    let testResult = main(testsDir, japlExec, testResultsFile)
    log(testResultsFile, &"Found {testResult.numOfTests} tests: {testResult.successTests} were successful, {testResult.failedTests} failed and {testResult.skippedTests} were skipped.")
    log(testResultsFile, "Check 'testresults.txt' for details", toFile=false)   
    testResultsfile.close()

