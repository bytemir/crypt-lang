import std/strutils
import Lexxer

let fileContent = readFile("tests/Example.crypt")
let lines = fileContent.splitLines()

var TokenizerInstance = Lexxer.Tokenizer()
TokenizerInstance.init(lines)
let tokenStream: seq[Token] = TokenizerInstance.beginLexicalAnalysis()
