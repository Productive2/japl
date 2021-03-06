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

const jatsVersion* = "(dev)"

var maxAliveTests* = 16 # number of tests that can run parallel
const testWait* = 100 # number of milliseconds per cycle
var timeout* = 50 # number of cycles after which a test is killed for timeout

var testRunner* = "jatr"
var force*: bool = false # if skipped tests get executed
var enumerate*: bool = false # if true, all failed/crashed and killed tests
                             # are enumerated to stdout

const outputIgnore* = [ "^DEBUG.*$" ]
