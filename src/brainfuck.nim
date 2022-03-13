# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import macros
import streams

## we need overflow-able chars
{.push overflowChecks: off.}
proc bfinc*(c: var char) = inc c
proc bfdec*(c: var char) = dec c
{.pop.}


proc readCharEOF*(input: Stream): char =
    ## readChar and converts 0 to -1 for brainfuck compat
    result = input.readChar
    if result == '\0':
        result = '\255';

proc interpret*(code: string; input, output: Stream) =
    ## As crazy as it seems, this proc interprets some brainfuck `code` 
    ## passed in as a string. 
    ## ...by leveraging the power of stdin *and* stdout (aka dual wielding) 
    ## creates an interactive environment that, sooner or later (à la Python),
    ## spits out whatever the brainfuck machinery decides to do.
    ## 
    var
        tape = newSeq[char]()
        codePos = 0
        tapePos = 0
  
    proc run(skip = false): bool =

        while tapePos >= 0 and codePos < code.len:
            # grow the tape if needed
            if tapePos >= tape.len:
                tape.add '\0'
        
            # interpret code
            if code[codePos] == '[':
                inc codePos
                let oldPos = codePos
                while run(tape[tapePos] == '\0'):
                    codePos = oldPos
            elif code[codePos] == ']':
                return tape[tapePos] != '\0'
            elif not skip:
                case code[codePos]
                of '+': bfinc tape[tapePos]
                of '-': bfdec tape[tapePos]
                of '>': inc tapePos
                of '<': dec tapePos
                of '.': write output, tape[tapePos]
                of ',': tape[tapePos] = input.readCharEOF
                else: discard
  
            inc codePos

    discard run()


proc interpret*(code, input: string): string =
    ## Interprets the brainfuck `code` string, reading from `input` and returning
    ## the result directly.
    var outStream = newStringStream()
    interpret(code, input.newStringStream, outStream)
    result = outStream.data


proc interpret*(code: string) =
    ## Interprets the brainfuck `code` string, reading from stdin and writing to
    ## stdout.
    interpret(code, stdin.newFileStream, stdout.newFileStream)  


proc compile(code, input, output: string): NimNode {.compiletime.} =
    var stmts = @[newStmtList()]

    template addStmt(text) =
        stmts[stmts.high].add parseStmt(text)
    
    addStmt """
      when not compiles(newStringStream()):
        static:
          quit("Error: Import the streams module to compile brainfuck code", 1)
    """

    addStmt "var tape: array[1_000_000, char]"
    addStmt "var tapePos = 0"
    addStmt "var inpStream = " & input
    addStmt "var outStream = " & output

    for c in code:
        case c
        of '+': addStmt "bfinc tape[tapePos]"
        of '-': addStmt "bfdec tape[tapePos]"
        of '>': addStmt "inc tapePos"
        of '<': addStmt "dec tapePos"
        of '.': addStmt "outStream.write tape[tapePos]"
        of ',': addStmt "tape[tapePos] = inpStream.readCharEOF"
        of '[': stmts.add newStmtList()
        of ']': 
            var loop = newNimNode(nnkWhileStmt)
            loop.add parseExpr("tape[tapePos] != '\\0'")
            loop.add stmts.pop
            stmts[stmts.high].add loop
        else: discard

    result = stmts[0]


macro compileString*(code: string) =
    compile code.strval, "stdin.newFileStream", "stdout.newFileStream"

macro compileString*(code: string; input, output: untyped) =
    result = compile($code, "newStringStream(" & $input & ")", "newStringStream()")
    result.add parseStmt($output & " = outStream.data")

macro compileFile*(fileName: string) =
    compile(staticRead(fileName.strVal), "stdin.newFileStream", "stdout.newFileStream")

macro compileFile*(fileName: string; input, output: untyped) = 
    result = compile(staticRead(fileName.strVal), 
        "newStringStream(" & $input & ")", "newStringStream()")
    result.add parseStmt($output & " = outStream.data")

# this stuff does not exists if we are included as lib
when isMainModule:
    import docopt
    
    const
        program = "brainfuck"
        version = "4.20.69"
        # compiler has cat powers
        longProgram = program & " " & version
    
    # this is compiled at compile time! how about that ??
    proc mbrot = compileFile "../examples/mandelbrot.b"

    # all your docopt versions are 69ers! pretty pog!
    let doc = """
brainfuck

Usage:
    brainfuck mbrot
    brainfuck i [<file.b>]
    brainfuck (-h | --help)
    brainfuck (-v | --version)

Options:
    -h --help     Show this screen
    -v --version  Show version
    """

    let args = docopt(doc, version = longProgram)

    if args["mbrot"]:
        mbrot()

    elif args["i"]:

        let code = 
            # dont let the $ trigger your inner haskell
            if args["<file.b>"]: readFile $args["<file.b>"]
            else: readAll stdin

        echo longProgram
        echo "--------------------------------------------------------------------------------"
        echo code
        echo "--------------------------------------------------------------------------------"

        interpret code
