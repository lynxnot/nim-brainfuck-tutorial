# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

## we need overflow-able chars
{.push overflowChecks: off.}
proc xinc(c: var char) = inc c
proc xdec(c: var char) = dec c
{.pop.}


proc interpret*(code: string) =
    ## As crazy as it seems, this proc interprets some brainfuck `code` 
    ## passed in as a string. 
    ## ...by leveraging the power of stdin *and* stdout (aka dual wielding) 
    ## creates an interactive environment that, sooner or later (aka à la Python),
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

    echo run()


when isMainModule:
    import os
  
    let code = if paramCount() > 0: readFile paramStr(1)
               else: readAll stdin

    echo("* brainfuck v69.420")

    echo "--------------------------------------------------------------------------------"
    echo code
    echo "--------------------------------------------------------------------------------"

    interpret code
