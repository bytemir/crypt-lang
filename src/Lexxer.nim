import std/strformat
import std/strutils
import std/monotimes
import std/times

type
    TokenType* = enum 
        LPAREN
        RPAREN

        LBRACE
        RBRACE

        LBRACKET
        RBRACKET

        SEPERATOR

        EQUAL
        DOUBLE_EQUAL
        GREATER
        GREATER_EQUAL
        LESS
        LESS_EQUAL

        NUMBER  
        STRING
        DIMENSIONAL

        IDENTIFIER
        TYPEOF

        ADD
        SUB
        MUL
        DIV

        INCREMENT   
        DECREMENT   

        EOL
        NONE

    Token* = object
        tokenType*: TokenType
        value*: string

    Tokenizer* = object
        lines*: seq[string]
        currentLineIndex*: int
        currentCharacterIndex*: int
        currentLine*: string
        currentCharacter*: char
        tokenStream*: seq[Token]

proc init*(tokenizer: var Tokenizer, lines: seq[string]) = 
    tokenizer.lines = lines
    tokenizer.currentLineIndex = 0
    tokenizer.currentCharacterIndex = -1
    tokenizer.tokenStream = @[]

    if lines.len > 0: 
        tokenizer.currentLine = lines[0]
    else: 
        tokenizer.currentLine = ""

proc advanceLine(tokenizer: var Tokenizer): bool =
    if tokenizer.currentLineIndex + 1 >= tokenizer.lines.len: 
        return true
    else: 
        tokenizer.currentLineIndex += 1
        tokenizer.currentLine = tokenizer.lines[tokenizer.currentLineIndex] 
        tokenizer.currentCharacterIndex = -1
        return false

proc advanceChar(tokenizer: var Tokenizer): bool = 
    while tokenizer.currentCharacterIndex + 1 >= tokenizer.currentLine.len: 
        if advanceLine(tokenizer): return true
        
    tokenizer.currentCharacterIndex += 1
    tokenizer.currentCharacter = tokenizer.currentLine[tokenizer.currentCharacterIndex]
    
    echo &"[DEBUG] Advanced to char: '{tokenizer.currentCharacter}' at index {tokenizer.currentCharacterIndex} (Line {tokenizer.currentLineIndex})"
    return false
 
proc emitToken(tokenizer: var Tokenizer, tokentype: TokenType, value: string) = 
    let genToken = Token(tokenType: tokentype, value: value)
    tokenizer.tokenStream.add(genToken)
    
    echo &"[INFO] Emitted Token: {tokentype} (Value: \"{value}\")"

proc beginLexicalAnalysis*(tokenizer: var Tokenizer): seq[Token] =
    echo "_________________________________________________________\n"
    echo "       \t\tLexical Analysis:"
    echo "_________________________________________________________\n"
    let startTime = getMonoTime()
    while advanceChar(tokenizer) == false:
        case tokenizer.currentCharacter
            of ' ', '\t', '\r', '\n':
                discard 

            of '>': 
                if tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '=':
                    discard advanceChar(tokenizer)
                    tokenizer.emitToken(TokenType.GREATER_EQUAL, ">=")
                else:
                    tokenizer.emitToken(TokenType.GREATER, $tokenizer.currentCharacter) 
                    
            of '<': 
                if tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '=':
                    discard advanceChar(tokenizer)
                    tokenizer.emitToken(TokenType.LESS_EQUAL, "<=")
                else:
                    tokenizer.emitToken(TokenType.LESS, $tokenizer.currentCharacter) 
                    
            of '=': 
                if tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '=':
                    discard advanceChar(tokenizer)
                    tokenizer.emitToken(TokenType.DOUBLE_EQUAL, "==")
                else:
                    tokenizer.emitToken(TokenType.EQUAL, $tokenizer.currentCharacter) 

            of ';': 
                tokenizer.emitToken(TokenType.EOL, $tokenizer.currentCharacter) 

            of '[': 
                tokenizer.emitToken(TokenType.LBRACKET, $tokenizer.currentCharacter) 

            of ',': 
                tokenizer.emitToken(TokenType.SEPERATOR, $tokenizer.currentCharacter) 

            of ']': 
                tokenizer.emitToken(TokenType.RBRACKET, $tokenizer.currentCharacter) 

            of ':': 
                tokenizer.emitToken(TokenType.TYPEOF, $tokenizer.currentCharacter) 

            of '@': 
                tokenizer.emitToken(TokenType.DIMENSIONAL, $tokenizer.currentCharacter) 

            of '+': 
                if tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '+':
                    discard advanceChar(tokenizer)
                    tokenizer.emitToken(TokenType.INCREMENT, "++")
                else:
                    tokenizer.emitToken(TokenType.ADD, $tokenizer.currentCharacter) 

            of '-': 
                if tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '-':
                    discard advanceChar(tokenizer)
                    tokenizer.emitToken(TokenType.DECREMENT, "--")
                else:
                    tokenizer.emitToken(TokenType.SUB, $tokenizer.currentCharacter) 

            of '*': 
                tokenizer.emitToken(TokenType.MUL, $tokenizer.currentCharacter) 

            of '/': 
                tokenizer.emitToken(TokenType.DIV, $tokenizer.currentCharacter) 

            of '(': 
                tokenizer.emitToken(TokenType.LPAREN, $tokenizer.currentCharacter) 

            of ')': 
                tokenizer.emitToken(TokenType.RPAREN, $tokenizer.currentCharacter) 

            of '{': 
                tokenizer.emitToken(TokenType.LBRACE, $tokenizer.currentCharacter) 

            of '}': 
                tokenizer.emitToken(TokenType.RBRACE, $tokenizer.currentCharacter) 

            of '"':
                var strBuffer = ""
                while advanceChar(tokenizer) == false:
                    if tokenizer.currentCharacter == '"':
                        break
                    strBuffer.add(tokenizer.currentCharacter)
                tokenizer.emitToken(TokenType.STRING, strBuffer)

            of '0'..'9':
                var numBuffer = ""
                numBuffer.add(tokenizer.currentCharacter)
                
                while tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                      tokenizer.currentLine[tokenizer.currentCharacterIndex + 1].isDigit:
                    discard advanceChar(tokenizer)
                    numBuffer.add(tokenizer.currentCharacter)
                
                if tokenizer.currentCharacterIndex + 2 < tokenizer.currentLine.len and
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '.' and
                   tokenizer.currentLine[tokenizer.currentCharacterIndex + 2].isDigit:
                    
                    discard advanceChar(tokenizer)
                    numBuffer.add(tokenizer.currentCharacter)
                    
                    while tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                          tokenizer.currentLine[tokenizer.currentCharacterIndex + 1].isDigit:
                        discard advanceChar(tokenizer)
                        numBuffer.add(tokenizer.currentCharacter)
                
                tokenizer.emitToken(TokenType.NUMBER, numBuffer)

            of 'a'..'z', 'A'..'Z', '_':
                var identBuffer = ""
                identBuffer.add(tokenizer.currentCharacter)
                while tokenizer.currentCharacterIndex + 1 < tokenizer.currentLine.len and 
                      (tokenizer.currentLine[tokenizer.currentCharacterIndex + 1].isAlphaNumeric or 
                       tokenizer.currentLine[tokenizer.currentCharacterIndex + 1] == '_'):
                    discard advanceChar(tokenizer)
                    identBuffer.add(tokenizer.currentCharacter)
                tokenizer.emitToken(TokenType.IDENTIFIER, identBuffer)

            else: 
                echo &"[DEBUG] Discarding: '{tokenizer.currentCharacter}' at index {tokenizer.currentCharacterIndex} (Line {tokenizer.currentLineIndex})"
                discard
    let endTime = getMonoTime() 
    let duration = endTime - startTime
    echo "\n=================== Final Token Stream ==================="
    for idx, tok in tokenizer.tokenStream:
        echo &"[{idx}] Type: {tok.tokenType:<12}    Value: \"{tok.value}\""
    echo "=========================================================="
    echo &"Time taken for Lexical Analysis: {duration.inMicroseconds} microseconds ({duration.inMilliseconds} ms)"
    echo "_________________________________________________________"
    return tokenizer.tokenStream