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

# Implementations of builtin functions and modules

import vm
import types/native
import types/baseObject
import types/japlNil
import types/numbers
import types/methods
import types/japlString
import types/exception

import times
import math
import strformat


proc natPrint(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] =
    ## Native function print
    ## Prints an object representation
    ## to stdout. If more than one argument
    ## is passed, they will be printed separated
    ## by a space
    var res = ""
    for i in countup(0, args.high()):
        let arg = args[i]
        if i < args.high():
            res = res & arg.stringify() & " "
        else:
            res = res & arg.stringify()
    echo res
    # Note: we return nil and not asNil() because
    # the VM will later use its own cached pointer
    # to nil
    return (ok: true, result: nil)


proc natClock(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] =
    ## Native function clock
    ## Returns the current unix
    ## time (also known as epoch)
    ## with subsecond precision

    # TODO: Move this to a separate module once we have imports

    result = (ok: true, result: getTime().toUnixFloat().asFloat())


proc natRound(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] = 
    ## Rounds a floating point number to a given
    ## precision (when precision == 0, this function drops the
    ## decimal part and returns an integer). Note that when
    ## precision > 0 and the value of the dropped digits
    ## exceeds or equals 5, the closest decimal place is
    ## increased by 1 (i.e. round(3.141519, 3) == 3.142)
    var precision = 0
    if len(args) notin 1..2:
        # Here we need to return immediately to exit the procedure
        return (ok: false, result: newTypeError(&"function 'round' takes from 1 to 2 arguments, got {len(args)}"))
    elif len(args) == 2:
        if not args[1].isInt():
            return (ok: false, result: newTypeError(&"precision must be of type 'int', not '{args[1].typeName()}'"))
        else:
            precision = args[1].toInt()
    if args[0].kind notin {ObjectType.Integer, ObjectType.Float}:
        return (ok: false, result: newTypeError(&"input must be of type 'int' or 'float', not '{args[0].typeName()}'"))
    if precision < 0:
        result = (ok: false, result: newTypeError(&"precision must be positive"))
    else:
        if args[0].isInt():
            result = (ok: true, result: args[0])
        elif precision == 0:
            result = (ok: true, result: int(args[0].toFloat()).asInt())
        else:
            result = (ok: true, result: round(args[0].toFloat(), precision).asFloat())


proc natToInt(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] = 
    ## Drops the decimal part of a float and returns an integer.
    ## If the value is already an integer, the same object is returned
    if args[0].isInt():
        result = (ok: true, result: args[0])
    elif args[0].isFloat():
        result = (ok: true, result: int(args[0].toFloat()).asInt())
    else:
        result = (ok: false, result: newTypeError(&"input must be of type 'int' or 'float', not '{args[0].typeName()}'"))


proc natType(args: seq[ptr Obj]): tuple[ok: bool, result: ptr Obj] = 
    ## Returns the type of a given object as a string
    result = (ok: true, result: args[0].typeName().asStr())


proc stdlibInit*(vm: VM) =
    ## Initializes the VM's standard library by defining builtin
    ## functions that do not require imports. An arity of -1
    ## means that the function is variadic (or that it can
    ## take a different number of arguments according to
    ## how it's called) and should be handled by the nim
    ## procedure accordingly
    vm.defineGlobal("print", newNative("print", natPrint, -1))
    vm.defineGlobal("clock", newNative("clock", natClock, 0))
    vm.defineGlobal("round", newNative("round", natRound, -1))
    vm.defineGlobal("toInt", newNative("toInt", natToInt, 1))
    vm.defineGlobal("type", newNative("type", natType, 1))



