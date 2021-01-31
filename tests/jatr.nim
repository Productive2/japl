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


# Just Another Test Runner for running JAPL tests
# a testrunner process

import ../src/vm
import directives
import os, strformat

var btvm = initVM()
if paramCount() > 0 and paramStr(1) == "stdin":
    block main:
        while true:
            block test:
                var test = ""
                while true:
                    let nl = stdin.readLine()
                    if 
    
elif paramCount() > 0:
    try:
        discard btvm.interpret(readFile(paramStr(1)), "")
        quit(0)
    except:
        let error = getCurrentException()
        writeLine stderr, error.msg
        quit(1)
       
