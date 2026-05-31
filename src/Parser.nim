import std/strformat
import std/monotimes
import std/times
import std/strutils

import Lexxer

type SyntaxError* = object of CatchableError
type EvaluationError* = object of CatchableError

type
    NodeType* = enum 
        DECLARATION

    Node* = ref object
        NodeType*: NodeType
        Value*: string
        Left*: Node
        Right*: Node


    Parser* = object
        TokenStream*: seq[Token]
        CurrentTokenIndex*: int
        CurrentToken*: Token
        AST*: seq[Node]

proc init*(parser: var Parser, TokenStream: seq[Token]) = 
    parser.TokenStream = TokenStream
    parser.CurrentTokenIndex = 0
    parser.CurrentToken = TokenStream[parser.CurrentTokenIndex]
    parser.AST = @[]

proc advanceToken(parser: var Parser) =
    if parser.CurrentTokenIndex + 1 < parser.TokenStream.len: 
        parser.CurrentTokenIndex += 1
        parser.CurrentToken = parser.TokenStream[parser.CurrentTokenIndex]
        echo &"[DEBUG] Advanced to Token: 'TYPE: {parser.CurrentToken.tokenType}' VALUE: '{parser.CurrentToken.value}'"
    else:
        parser.CurrentTokenIndex += 1


proc peekToken*(parser: var Parser, offset: int = 1): Token =
    let targetIndex = parser.CurrentTokenIndex + offset
    if targetIndex >= parser.TokenStream.len:
        return Token(tokenType: TokenType.EOL, value: "") 
    return parser.TokenStream[targetIndex]    


proc expectToken*(parser: var Parser, expectedType: TokenType, errorMsg: string = ""): Token =
    let nextToken = parser.peekToken()
    
    if nextToken.tokenType == expectedType:
        advanceToken(parser)
        return parser.CurrentToken
    else:
        let defaultMsg = &"Expected token of type '{expectedType}', but got '{nextToken.tokenType}' with value '{nextToken.value}'"
        let finalMsg = if errorMsg == "": defaultMsg else: errorMsg
        
        raise newException(SyntaxError, finalMsg)

proc evaluateExpression*(expression: seq[Token]): seq[Token] =
    if expression.len == 0:
        raise newException(EvaluationError, "Empty expression")

    var tokens = expression
    var i = 0
    
    while i < tokens.len:
        if tokens[i].tokenType in {TokenType.MUL, TokenType.DIV}:
            if i == 0 or i == tokens.len - 1:
                raise newException(EvaluationError, "Malformed expression")
            
            let left = tokens[i-1]
            let right = tokens[i+1]
            
            if left.tokenType == TokenType.NUMBER and right.tokenType == TokenType.NUMBER:
                let valLeft = parseFloat(left.value)
                let valRight = parseFloat(right.value)
                var res: float
                
                if tokens[i].tokenType == TokenType.MUL:
                    res = valLeft * valRight
                else:
                    if valRight == 0.0: raise newException(EvaluationError, "Division by zero")
                    res = valLeft / valRight
                    
                tokens[i-1] = Token(tokenType: TokenType.NUMBER, value: $res)
                tokens.delete(i) 
                tokens.delete(i) 
                i -= 1
            else:
                i += 1
        else:
            i += 1

    i = 1
    while i < tokens.len - 1:
        let left = tokens[i-1]
        let op = tokens[i]
        let right = tokens[i+1]
        
        if left.tokenType == TokenType.NUMBER and right.tokenType == TokenType.NUMBER:
            let valLeft = parseFloat(left.value)
            let valRight = parseFloat(right.value)
            let res = if op.tokenType == TokenType.ADD: valLeft + valRight else: valLeft - valRight
            
            tokens[i-1] = Token(tokenType: TokenType.NUMBER, value: $res)
            tokens.delete(i)
            tokens.delete(i)
            i = 1
        elif left.tokenType == TokenType.STRING and right.tokenType == TokenType.STRING:
            if op.tokenType == TokenType.ADD:
                tokens[i-1] = Token(tokenType: TokenType.STRING, value: left.value & right.value)
                tokens.delete(i)
                tokens.delete(i)
                i = 1
            else:
                raise newException(EvaluationError, "Invalid string operation")
        else:
            i += 2

    return tokens

proc fetchExpression*(parser: var Parser): seq[Token] =
    result = @[]
    while parser.CurrentTokenIndex < parser.TokenStream.len:
        let nextTok = parser.peekToken(1)
        
        if nextTok.tokenType == TokenType.EOL:
            advanceToken(parser)
            break

        advanceToken(parser)
        result.add(parser.CurrentToken)

proc beginParsing*(parser: var Parser): seq[Node] =
    echo "_________________________________________________________\n"
    echo "       \t\tParsing Analysis:"
    echo "_________________________________________________________\n"
    let startTime = getMonoTime()
    while parser.CurrentTokenIndex < parser.TokenStream.len:
        case parser.CurrentToken.tokenType
            of TokenType.IDENTIFIER:
                if parser.CurrentToken.value == "let":
                    echo &"[DEBUG] Found Declaration: 'TYPE: {parser.CurrentToken.tokenType}' VALUE: '{parser.CurrentToken.value}'"
                    let declarationName: string = parser.expectToken(TokenType.IDENTIFIER, "Failed to fetch declaration name!").value
                    discard parser.expectToken(TokenType.TYPEOF, "Missing : to declare type.")
                    let declarationType: string = parser.expectToken(TokenType.IDENTIFIER, "Failed to fetch declaration type!").value
                    discard parser.expectToken(TokenType.EQUAL, "Missing : to declare type.")
                    var declerationExpression: seq[Token] = parser.fetchExpression()
                    declerationExpression = evaluateExpression(declerationExpression)
                    echo &"{declarationName}, {declarationType}, {declerationExpression}"

            else: 
                echo &"[DEBUG] Discarding Token: 'TYPE: {parser.CurrentToken.tokenType}' VALUE: '{parser.CurrentToken.value}'"
                discard

        advanceToken(parser)
    
            
    let endTime = getMonoTime() 
    let duration = endTime - startTime
    echo "\n=================== Final Node Stream ==================="
    for idx, node in parser.AST:
        echo &"[{idx}] Type: {node.NodeType:<12}    Value: \"{node.Value}\""
    echo "=========================================================="
    echo &"Time taken to Parse: {duration.inMicroseconds} microseconds ({duration.inMilliseconds} ms)"
    echo "_________________________________________________________"
    return parser.AST