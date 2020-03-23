" Vim syntax file
" Language:     Magritte
" Maintainer:   Jeanine Adkisson

let ident = "[a-zA-Z-][\/a-zA-Z0-9_-]*"

"" dash is anywhere in an ident
setlocal iskeyword+=-

syntax sync fromstart

" syntax match   magPunctuation           /\%(:\|,\|\;\|!\|<\|\*\|>\|=\|(\|)\|\[\|\]\||\|{\|}\|\~\)/
syntax match   magPunctuation           /\%(|\|=>\|;\|(\|)\|\[\|\]\|<\|>\|{\|}\|&\|!\)/


syn match magComment /#[^\n]*\n/
exe "syn match magAnnot /++\\?" . ident . "/"
exe "syn match magName /" . ident . "/"
" exe "syn match magDotted /[.][\\/]\\?" . ident . "/"
exe "syn match magCheck /[\\%]" . ident . "/"
exe "syn match magPath /[\\:]" . ident . "/"
exe "syn match magLookup /[!]" . ident . "/"
exe "syn match magKeyword /[@][@!]\\?" . ident . "/"
exe "syn match magDollar /[\\$]/"
exe "syn match magBinder /[\\?]" . ident . "/"
exe "syn match magDynamic /[\\$]" . ident . "/"
exe "syn match magDynamic /[\\$][0-9]\\+/"
exe "syn match magMacro /\\(\\\\\\\\\\?" . ident . "\\)/"
exe "syn match magFlag /-" . ident . "/"
exe "syn match magInfix /`" . ident . "/"
" syn match magUppercase /[A-Z][a-zA-z0-9]*/

syn match magNumber /\d\+\(\.\d\+\)\?\>/

" syn match magBareString /'[^{][^ 	\n)\];]*/
" syn region magParseMacro start=/\\\w\+{/ end="" contains=magStringContents
" syn region magString start="'{" end="" contains=magStringContents
" syn region magStringContents start="{" end="}" contains=magStringContents contained

syn region magDQString start='"' end='"' contains=magUnicode,magEscape
syn match magUnicode /\\u[0-9a-f][0-9a-f][0-9a-f][0-9a-f]/ contained
syn match magEscape /\\[trn0e\\"]/ contained

hi! def link magName        Name
hi! def link magUppercase   Type
hi! def link magDotted      Type
hi! def link magPunctuation Punctuation
hi! def link magCheck       Type
hi! def link magKeyword     Keyword
hi! def link magMacro       Punctuation
hi! def link magFlag        Special
" hi! def link magBareString  String
" hi! def link magString      String
" hi! def link magParseMacro  Punctuation
hi! def link magDQString    String
hi! def link magPath    String
hi! def link magLookup    Function
hi! def link magUnicode SpecialChar
hi! def link magEscape SpecialChar
hi! def link magStringContents String
hi! def link magAnnot       Function
hi! def link magInfix       Function
hi! def link magLet         Punctuation
hi! def link magDynamic     Identifier
hi! def link magBinder      Special
hi! def link magDollar      Identifier
hi! def link magComment     Comment
hi! def link magNumber      Number
