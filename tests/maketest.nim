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


# Test creation tool, use mainly for exceptions

import os
import strformat
import re
import strutils


const tempCodeFile = ".tempcode_drEHdZuwNYLqsQaMDMqeNRtmqoqXBXfnCfeqEcmcUYJToBVQkF.jpl"
const tempOutputFile = ".tempoutput.txt"


proc autoRemove(path: string) =
    if fileExists(path):
        removeFile(path)


when isMainModule:
    var testsDir = "tests" / "japl"
    var japlExec = "src" / "japl"
    var currentDir = getCurrentDir()
    # Supports running from both the project root and the tests dir itself
    if currentDir.lastPathPart() == "tests":
        testsDir = "japl"
        japlExec = ".." / japlExec
    if not fileExists(japlExec):
        echo "JAPL executable not found"
        quit(1)
    if not dirExists(testsDir):
        echo "Tests dir not found"
        quit(1)
    echo "Please enter the JAPL code or specify a file containing it with file:<path>"
    let response = stdin.readLine()
    if response =~ re"^file:(.*)$":
        let codepath = matches[0]
        writeFile(tempCodeFile, readFile(codepath))
    else:
        writeFile(tempCodeFile, response)
    let japlCode = readFile(tempCodeFile)
    discard execShellCmd(&"{japlExec} {tempCodeFile} > {tempOutputFile} 2>&1")
    var output: string
    if fileExists(tempOutputFile):
        output = readFile(tempOutputFile)
    else:
        echo "Temporary output file not detected, aborting"
        quit(1)
    autoRemove(tempCodeFile) 
    autoRemove(tempOutputFile) 
    echo "Got the following output:"
    echo output                
    echo "Do you want to keep it as a test? [y/N]"
    let keepResponse = ($stdin.readLine()).toLower()
    let keep = keepResponse[0] == 'y'
    if keep:
        block saving:
            while true:
                echo "Please name the test (without the .jpl extension)"
                let testname = stdin.readLine()
                if testname == "":
                    echo "aborted"
                    break saving # I like to be explicit
                let testpath = testsDir / testname & ".jpl"
                echo &"Generating test at {testpath}"
                var testContent = japlCode
                for line in output.split('\n'):
                    var mline = line
                    mline = mline.replace(tempCodeFile, "")
                    testContent = testContent & "\n" & "//output:" & mline & "\n"
                if fileExists(testpath):
                    echo "Test already exists"
                else:
                    writeFile(testpath, testContent)
                    break saving
    else:
        echo "Aborting"
