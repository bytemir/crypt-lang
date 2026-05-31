import std/strutils
import Lexxer
import Parser

let fileContent = readFile("tests/Example.crypt")
let lines = fileContent.splitLines()

var TokenizerInstance = Lexxer.Tokenizer()
TokenizerInstance.init(lines)
let tokenStream: seq[Token] = TokenizerInstance.beginLexicalAnalysis()

var ParserInstance = Parser.Parser()
ParserInstance.init(tokenStream)
let AST: seq[Node] = ParserInstance.beginParsing()