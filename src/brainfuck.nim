# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import macros

## we need overflow-able chars
{.push overflowChecks: off.}
proc xinc(c: var char) = inc c
proc xdec(c: var char) = dec c
{.pop.}


proc interpret*(code: string) =
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
                of '+': xinc tape[tapePos]
                of '-': xdec tape[tapePos]
                of '>': inc tapePos
                of '<': dec tapePos
                of '.': write stdout, tape[tapePos]
                of ',': tape[tapePos] = readChar stdin
                else: discard
  
            inc codePos

    discard run()


proc compile(code: string): NimNode {.compileTime.} =
    var stmts = @[newStmtList()]

    template addStmt(text): void =
        stmts[stmts.high].add parseStmt(text)
    
    addStmt "var tape: array[1_000_000, char]"
    addStmt "var tapePos = 0"

    for c in code:
        case c
        of '+': addStmt "xinc tape[tapePos]"
        of '-': addStmt "xdec tape[tapePos]"
        of '>': addStmt "inc tapePos"
        of '<': addStmt "dec tapePos"
        of '.': addStmt "stdout.write tape[tapePos]"
        of ',': addStmt "tape[tapePos] = stdin.readChar"
        of '[': stmts.add newStmtList()
        of ']': 
            var loop = newNimNode(nnkWhileStmt)
            loop.add parseExpr("tape[tapePos] != '\\0'")
            loop.add stmts.pop
            stmts[stmts.high].add loop
        else: discard
    
    result = stmts[0]


macro compileString*(code: string): void =
    compile code.strval

macro compileFile*(fileName: string): void =
    compile staticRead(fileName.strVal)

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
