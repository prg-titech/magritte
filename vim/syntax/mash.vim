" Vim syntax file
" Language:     Magritte
" Maintainer:   Jeanine Adkisson

let ident = "[a-zA-Z-][\/a-zA-Z0-9_-]*"

"" dash is anywhere in an ident
setlocal iskeyword+=-

syntax sync fromstart

" syntax match   mashPunctuation           /\%(:\|,\|\;\|!\|<\|\*\|>\|=\|(\|)\|\[\|\]\||\|{\|}\|\~\)/
syntax match   mashPunctuation           /\%(|\|=>\|;\|(\|)\|\[\|\]\|<\|>\|{\|}\|&\|!\)/


syn match mashComment /#[^\n]*\n/
exe "syn match mashAnnot /++\\?" . ident . "/"
exe "syn match mashName /" . ident . "/"
" exe "syn match mashDotted /[.][\\/]\\?" . ident . "/"
exe "syn match mashCheck /[\\%]" . ident . "/"
exe "syn match mashPath /[\\:]" . ident . "/"
exe "syn match mashLookup /[!]" . ident . "/"
exe "syn match mashKeyword /[@][@]\\?" . ident . "/"
exe "syn match mashDollar /[\\$]/"
exe "syn match mashBinder /[\\?]" . ident . "/"
exe "syn match mashDynamic /[\\$]" . ident . "/"
exe "syn match mashDynamic /[\\$][0-9]\\+/"
exe "syn match mashMacro /\\(\\\\\\\\\\?" . ident . "\\)/"
exe "syn match mashFlag /-" . ident . "/"
exe "syn match mashInfix /`" . ident . "/"
" syn match mashUppercase /[A-Z][a-zA-z0-9]*/

syn match mashNumber /\d\+\(\.\d\+\)\?\>/

" syn match mashBareString /'[^{][^ 	\n)\];]*/
" syn region mashParseMacro start=/\\\w\+{/ end="" contains=mashStringContents
" syn region mashString start="'{" end="" contains=mashStringContents
" syn region mashStringContents start="{" end="}" contains=mashStringContents contained

syn region mashDQString start='"' end='"' contains=mashUnicode,mashEscape
syn match mashUnicode /\\u[0-9a-f][0-9a-f][0-9a-f][0-9a-f]/ contained
syn match mashEscape /\\[trn0e\\"]/ contained

hi! def link mashName        Name
hi! def link mashUppercase   Type
hi! def link mashDotted      Type
hi! def link mashPunctuation Punctuation
hi! def link mashCheck       Type
hi! def link mashKeyword     Keyword
hi! def link mashMacro       Punctuation
hi! def link mashFlag        Special
" hi! def link mashBareString  String
" hi! def link mashString      String
" hi! def link mashParseMacro  Punctuation
hi! def link mashDQString    String
hi! def link mashPath    String
hi! def link mashLookup    Function
hi! def link mashUnicode SpecialChar
hi! def link mashEscape SpecialChar
hi! def link mashStringContents String
hi! def link mashAnnot       Function
hi! def link mashInfix       Function
hi! def link mashLet         Punctuation
hi! def link mashDynamic     Identifier
hi! def link mashBinder      Special
hi! def link mashDollar      Identifier
hi! def link mashComment     Comment
hi! def link mashNumber      Number
