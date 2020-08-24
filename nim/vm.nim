import strutils
import strformat
import math
import lenientops
import lists
import tables
import compiler
import util/debug
import meta/chunk
import meta/valueobject
import types/exceptions
import types/objecttype
import types/stringtype


proc `**`(a, b: int): int = pow(a.float, b.float).int


proc `**`(a, b: float): float = pow(a, b)


type KeyboardInterrupt* = object of CatchableError


type InterpretResult = enum
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR


func handleInterrupt() {.noconv.} =
    raise newException(KeyboardInterrupt, "Ctrl+C")


type VM = ref object
    chunk: Chunk
    ip: int
    stack*: seq[Value]
    stackTop*: int
    objects*: SinglyLinkedList[Obj]  # Unused for now
    globals*: Table[string, Value]
    lastPop: Value


proc error*(self: VM, error: JAPLException) =
    echo stringify(error)
    # Add code to raise an exception here


proc pop*(self: VM): Value =
    result = self.stack.pop()
    self.stackTop = self.stackTop - 1


proc push*(self: VM, value: Value) =
    self.stack.add(value)
    self.stackTop = self.stackTop + 1


proc peek*(self: VM, distance: int): Value =
    return self.stack[len(self.stack) - distance - 1]


proc slice(self: VM): bool =
    var idx = self.pop()
    var peeked = self.pop()
    case peeked.kind:
        of OBJECT:
            case peeked.obj.kind:
                of ObjectTypes.STRING:
                    var str = peeked.toStr()
                    if not idx.isInt():
                        self.error(newTypeError("string indeces must be integers"))
                        return false
                    elif idx.toInt() < 0:
                        idx.intValue = len(str) + idx.toInt()
                        if idx.toInt() < 0:
                            self.error(newIndexError("string index out of bounds"))
                            return false
                    if idx.toInt() - 1 > len(str) - 1:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    self.push(Value(kind: OBJECT, obj: newString(&"{str[idx.toInt()]}")))
                    return true

                else:
                    self.error(newTypeError(&"Unsupported slicing for object of type '{peeked.typeName()}'"))
                    return false
        else:
            self.error(newTypeError(&"Unsupported slicing for object of type '{peeked.typeName()}'"))
            return false


proc sliceRange(self: VM): bool =
    var sliceEnd = self.pop()
    var sliceStart = self.pop()
    var popped = self.pop()
    case popped.kind:
        of OBJECT:
            case popped.obj.kind:
                of ObjectTypes.STRING:
                    var str = popped.toStr()
                    if sliceEnd.isNil():
                        sliceEnd = Value(kind: INTEGER, intValue: len(str))
                    if sliceStart.isNil():
                        sliceStart = Value(kind: INTEGER, intValue: 0)
                    elif not sliceStart.isInt() or not sliceEnd.isInt():
                        self.error(newTypeError("string indeces must be integers"))
                        return false
                    elif sliceStart.toInt() < 0:
                        sliceStart.intValue = len(str) + sliceStart.toInt()
                        if sliceStart.toInt() < 0:
                            self.error(newIndexError("string index out of bounds"))
                            return false
                    if sliceEnd.toInt() < 0:
                        sliceEnd.intValue = len(str) + sliceEnd.toInt()
                        if sliceEnd.toInt() < 0:
                            self.error(newIndexError("string index out of bounds"))
                            return false
                    if sliceStart.toInt() - 1 > len(str) - 1 or sliceEnd.toInt() - 1 > len(str) - 1:
                        self.error(newIndexError("string index out of bounds"))
                        return false
                    elif sliceStart.toInt() > sliceEnd.toInt():
                        self.error(newIndexError("the start index can't be bigger than the end index"))
                        return false
                    self.push(Value(kind: OBJECT, obj: newString(str[sliceStart.toInt()..<sliceEnd.toInt()])))
                    return true

                else:
                    self.error(newTypeError(&"Unsupported slicing for object of type '{popped.typeName()}'"))
                    return false
        else:
            self.error(newTypeError(&"Unsupported slicing for object of type '{popped.typeName()}'"))
            return false


proc run(self: VM, debug, repl: bool): InterpretResult =
    template readByte: untyped =
        inc(self.ip)
        self.chunk.code[self.ip - 1]
    template readBytes: untyped =
        var arr = [readByte(), readByte(), readByte()]
        var index: int
        copyMem(index.addr, unsafeAddr(arr), sizeof(arr))
        index
    template readShort: untyped =
        inc(self.ip)
        inc(self.ip)
        cast[uint16]((self.chunk.code[self.ip - 2] shl 8) or self.chunk.code[self.ip - 1])
    template readConstant: Value =
        self.chunk.consts.values[int(readByte())]
    template readLongConstant: Value =
        var arr = [readByte(), readByte(), readByte()]
        var idx: int
        copyMem(idx.addr, unsafeAddr(arr), sizeof(arr))
        self.chunk.consts.values[idx]
    template BinOp(op, check) =
        var rightVal {.inject.} = self.pop()
        var leftVal {.inject.} = self.pop()
        if check(leftVal) and check(rightVal):
            if leftVal.isFloat() and rightVal.isInt():
                var res = `op`(leftVal.toFloat(), float rightVal.toInt())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                   self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isInt() and rightVal.isFloat():
                var res = `op`(float leftVal.toInt(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                   self.push(Value(kind: DOUBLE, floatValue: float res))
            elif leftVal.isFloat() and rightVal.isFloat():
                var res = `op`(leftVal.toFloat(), rightVal.toFloat())
                if res is bool:
                    self.push(Value(kind: BOOL, boolValue: bool res))
                else:
                   self.push(Value(kind: DOUBLE, floatValue: float res))
            else:
                var tmp = `op`(leftVal.toInt(), rightVal.toInt())
                if tmp is int:
                    self.push(Value(kind: INTEGER, intValue: int tmp))
                elif tmp is bool:
                    self.push(Value(kind: BOOL, boolValue: bool tmp))
                else:
                    self.push(Value(kind: DOUBLE, floatValue: float tmp))
        else:
            self.error(newTypeError(&"Unsupported binary operator for objects of type '{leftVal.typeName()}' and '{rightVal.typeName()}'"))
            return RUNTIME_ERROR
    var instruction: uint8
    var opcode: OpCode
    while true:
        {.computedgoto.}
        instruction = readByte()
        opcode = OpCode(instruction)
        if debug:
            stdout.write("Current stack status: [")
            for v in self.stack:
                stdout.write(stringify(v))
                stdout.write(", ")
            stdout.write("]\n")
            stdout.write("Global scope status: {")
            for k, v in self.globals.pairs():
                stdout.write(k)
                stdout.write(": ")
                stdout.write(stringify(v))
            echo "}\n"
            discard disassembleInstruction(self.chunk, self.ip - 1)
        case opcode:
            of OP_CONSTANT:
                var constant: Value = readConstant()
                self.push(constant)
            of OP_CONSTANT_LONG:
                var constant: Value = readLongConstant()
                self.push(constant)
            of OP_NEGATE:
                var cur = self.pop()
                case cur.kind:
                    of DOUBLE:
                        cur.floatValue = -cur.toFloat()
                        self.push(cur)
                    of INTEGER:
                        cur.intValue = -cur.toInt()
                        self.push(cur)
                    else:
                        self.error(newTypeError(&"Unsupported unary operator '-' for object of type '{cur.typeName()}'"))
            of OP_ADD:
                if self.peek(0).isObj() and self.peek(1).isObj():
                    if self.peek(0).isStr() and self.peek(1).isStr():
                        var r = self.peek(0).toStr()
                        var l = self.peek(1).toStr()
                        self.push(Value(kind: OBJECT, obj: newString(l & r)))
                    else:
                        self.error(newTypeError(&"Unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}"))
                        return RUNTIME_ERROR
                else:
                    BinOp(`+`, isNum)
            of OP_SUBTRACT:
                BinOp(`-`, isNum)
            of OP_DIVIDE:
                BinOp(`/`, isNum)
            of OP_MULTIPLY:
                if self.peek(0).isInt() and self.peek(1).isObj():
                    if self.peek(1).isStr():
                        var r = self.peek(0).toInt()
                        var l = self.peek(1).toStr()
                        self.push(Value(kind: OBJECT, obj: newString(l.repeat(r))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}"))
                        return RUNTIME_ERROR
                elif self.peek(0).isObj() and self.peek(1).isInt():
                    if self.peek(0).isStr():
                        var r = self.peek(0).toStr()
                        var l = self.peek(1).toInt()
                        self.push(Value(kind: OBJECT, obj: newString(r.repeat(l))))
                    else:
                        self.error(newTypeError(&"Unsupported binary operator for objects of type '{self.peek(0).typeName()}' and '{self.peek(1).typeName()}"))
                        return RUNTIME_ERROR
                else:
                    BinOp(`*`, isNum)
            of OP_MOD:
                BinOp(floorMod, isNum)
            of OP_POW:
                BinOp(`**`, isNum)
            of OP_TRUE:
                self.push(Value(kind: BOOL, boolValue: true))
            of OP_FALSE:
                self.push(Value(kind: BOOL, boolValue: false))
            of OP_NIL:
                self.push(Value(kind: NIL))
            of OP_NOT:
                self.push(Value(kind: BOOL, boolValue: isFalsey(self.pop())))
            of OP_EQUAL:
                var a = self.pop()
                var b = self.pop()
                if a.isFloat() and b.isInt():
                    b = Value(kind: DOUBLE, floatValue: float b.toInt())
                elif b.isFloat() and a.isInt():
                    a = Value(kind: DOUBLE, floatValue: float a.toInt())
                self.push(Value(kind: BOOL, boolValue: valuesEqual(a, b)))
            of OP_LESS:
                BinOp(`<`, isNum)
            of OP_GREATER:
                BinOp(`>`, isNum)
            of OP_SLICE:
                if not self.slice():
                    return RUNTIME_ERROR
            of OP_SLICE_RANGE:
                if not self.sliceRange():
                    return RUNTIME_ERROR
            of OP_DEFINE_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().toStr()
                    self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().toStr()
                    self.globals[constant] = self.peek(0)
                discard self.pop()   # This will help when we have a custom GC
            of OP_GET_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.push(self.globals[constant])
                else:
                    var constant = readConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.push(self.globals[constant])
            of OP_SET_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals[constant] = self.peek(0)
                else:
                    var constant = readConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"assignment to undeclared name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals[constant] = self.peek(0)
            of OP_DELETE_GLOBAL:
                if self.chunk.consts.values.len > 255:
                    var constant = readLongConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals.del(constant)
                else:
                    var constant = readConstant().toStr()
                    if constant notin self.globals:
                        self.error(newReferenceError(&"undefined name '{constant}'"))
                        return RUNTIME_ERROR
                    else:
                        self.globals.del(constant)
            of OP_GET_LOCAL:
                if self.stack.len > 255:
                    var slot = readBytes()
                    self.push(self.stack[slot])
                else:
                    var slot = readByte()
                    self.push(self.stack[slot])
            of OP_SET_LOCAL:
                if self.stack.len > 255:
                    var slot = readBytes()
                    self.stack[slot] = self.peek(0)
                else:
                    var slot = readByte()
                    self.stack[slot] = self.peek(0)
            of OP_DELETE_LOCAL:
                if self.stack.len > 255:
                    var slot = readBytes()
                    self.stack.delete(slot)
                else:
                    var slot = readByte()
                    self.stack.delete(slot)
            of OP_POP:
                self.lastPop = self.pop()
            of OP_JUMP_IF_FALSE:
                var offset = readShort()
                if isFalsey(self.peek(0)):
                    self.ip += int offset
            of OP_JUMP:
                var offset = readShort()
                self.ip += int offset
            of OP_LOOP:
                var offset = readShort()
                self.ip -= int offset
            of OP_BREAK:
                discard
            of OP_RETURN:
                var popped = self.lastPop
                if repl:
                    if popped.kind != NIL:
                        echo stringify(popped)
                return OK


proc freeVM*(self: VM) =
    unsetControlCHook()


proc interpret*(self: var VM, source: string, debug: bool = false, repl: bool = false): InterpretResult =
    var chunk = initChunk()
    var compiler = initCompiler(chunk)
    setControlCHook(handleInterrupt)
    if not compiler.compile(source, chunk) or compiler.parser.hadError:
        return COMPILE_ERROR
    self.chunk = chunk
    self.ip = 0
    if len(chunk.code) > 1:
        try:
            result = self.run(debug, repl)
        except KeyboardInterrupt:
            self.error(newInterruptedError(""))
            return RUNTIME_ERROR
    chunk.freeChunk()
    self.freeVM()


proc resetStack*(self: VM) =
    self.stackTop = 0


proc initVM*(): VM =
    result = VM(chunk: initChunk(), ip: 0, stack: @[], stackTop: 0, objects: initSinglyLinkedList[Obj](), globals: initTable[string, Value](), lastPop: Value(kind: NIL))


