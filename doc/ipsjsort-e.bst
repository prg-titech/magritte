% ipsjsort-e.bst 28-Oct-10 by Hiroshi Nakashima (ver 3.00)
% ipsjsort-e.bst 15-Jun-07 by Hiroshi Nakashima (ver 2.12)
% ipsjsort.bst 30-Jan-02 by Hiroshi Nakashima (ver 2.00)
% ipsjsort.bst 28-Dec-93 by Hiroshi Nakashima (ver 1.00)
% jssst.bst tomura@etl.go.jp (Satoru Tomura)
% BibTeX standard bibliography style `jplain'
	% version 0.10 for JBibTeX versions 0.10 or later, JLaTeX version 2.09.
	% by Shouichi Matsui, matsui@denken.junet

ENTRY
  { address
    author
    booktitle
    chapter
    doi							% 3.00(1)
    edition
    editor
    howpublished
    institution
    journal
    key
    month
    note
    number
    organization
    pages
    publisher
    refdate						% 3.00(1)
    school
    series
    title
    type
    url							% 3.00(1)
    volume
    year
  }
  {}
  { label }

INTEGERS { output.state before.all mid.sentence after.sentence after.block }

INTEGERS { before.year }

FUNCTION {init.state.consts}
{ #0 'before.all :=
  #1 'mid.sentence :=
  #2 'after.sentence :=
  #3 'after.block :=
  #4 'before.year :=					% 1.00(1)
}

STRINGS { s t }

FUNCTION {output.nonnull}
{ 's :=
  output.state mid.sentence =
    { ", " * write$ }
    { output.state after.block =
	{ add.period$ write$
	  newline$
	  "\newblock " write$
	}
	{ output.state before.all =
	    'write$
	    { output.state before.year =		% 1.00(1)
		{ " " * write$ }
		{ add.period$ " " * write$ }
	      if$
	    }
	  if$
	}
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}

FUNCTION {output}
{ duplicate$ empty$
    'pop$
    'output.nonnull
  if$
}

FUNCTION {required.argument}
{ 't :=
  empty$
    {"Missing required argument " t * " in " * cite$ * warning$}
    'skip$
  if$
}

FUNCTION {required.exclusive.or.argument}
{ 't :=
  empty$
    { 's := 
      empty$
        { t " or " * s * " is missing in " * cite$ * warning$}
        'skip$
      if$
    }
    { 's :=
      empty$
        'skip$
        { "You can use only one of " t * " and " * s * " in " * cite$ * warning$}
      if$
    }
  if$
}

FUNCTION {required.and.or.argument}
{ 't := empty$
     { 's := empty$
         { "there's no " t * " and/or " * s * cite$ * warning$ }
         'skip$
       if$
     }
     { pop$ pop$ }
  if$
}

FUNCTION {optional.series.volume.number.argument}
{ series empty$
    { volume empty$
        { number empty$
            'skip$
            { "there's a number but no series in " cite$ * warning$ }
          if$
        }
        { number empty$
            { "there's a volume but no series in " cite$ * warning$ }
            { "you can use only one of volume and number in " cite$ * warning$}
          if$
        }
     if$
    }
    { volume empty$
        { number empty$
            { "there's a series but neither volume nor number in " cite$ * warning$ }
            'skip$
          if$
        }
        { number empty$
            'skip$
            { "you can use only one of volume and number in " cite$ * warning$ }
          if$
        }
     if$
   }
   if$
}            

FUNCTION {output.bibitem}
{ newline$
  "\bibitem{" write$
  cite$ write$
  "}" write$
  newline$
  before.all 'output.state :=
}

FUNCTION {fin.entry}
{ add.period$
  write$
  newline$
}

FUNCTION {new.block}
{ output.state before.all =
    'skip$
    { after.block 'output.state := }
  if$
}

FUNCTION {new.sentence}
{ output.state after.block =
    'skip$
    { output.state before.all =
	'skip$
	{ after.sentence 'output.state := }
      if$
    }
  if$
}

FUNCTION {not}
{   { #0 }
    { #1 }
  if$
}

FUNCTION {and}
{   'skip$
    { pop$ #0 }
  if$
}

FUNCTION {or}
{   { pop$ #1 }
    'skip$
  if$
}

FUNCTION {new.block.checka}
{ empty$
    'skip$
    'new.block
  if$
}

FUNCTION {new.block.checkb}
{ empty$
  swap$ empty$
  and
    'skip$
    'new.block
  if$
}

FUNCTION {new.sentence.checka}
{ empty$
    'skip$
    'new.sentence
  if$
}

FUNCTION {new.sentence.checkb}
{ empty$
  swap$ empty$
  and
    'skip$
    'new.sentence
  if$
}

FUNCTION {field.or.null}
{ duplicate$ empty$
    { pop$ "" }
    'skip$
  if$
}

FUNCTION {emphasize}
{ duplicate$ empty$
    { pop$ "" }
    { "{\em " swap$ * "}" * }
  if$
}

INTEGERS { nameptr namesleft numnames }

FUNCTION {format.names}					% 1.00(4), 2.00(4)
{ 's :=
  #1 'nameptr :=
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { s nameptr "{vv }{ll}{, jj}{, f.}" format.name$ 't :=
      nameptr #1 >
	{ namesleft #1 >
	    { ", " * t * }
	    { t "others" =
		{" et al." * }
		{" and " * t * }
	      if$
	    }
	  if$
	}
	't
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

FUNCTION {format.authors}
{ author empty$
    { "" }
    { author format.names }
  if$
}

FUNCTION {add.colon}					% 2.00(5)
{ ": " *
}

FUNCTION {format.editors.inparen}			% 2.00(6)
{ editor empty$
    { "" }
    { editor format.names
      editor num.names$ #1 >
	{", eds." *}
	{", ed." *}
      if$
    }
  if$
}

FUNCTION {format.editors}
{ editor empty$
    { "" }
    { editor format.names
      editor num.names$ #1 >
	{"(eds.)" *}
	{"(ed.)" *}
      if$
    }
  if$
}

FUNCTION {n.dashify}
{ 't :=
  ""
    { t empty$ not }
    { t #1 #1 substring$ "-" =
	{ t #1 #2 substring$ "--" = not
	    { "--" *
	      t #2 global.max$ substring$ 't :=
	    }
	    {   { t #1 #1 substring$ "-" = }
		{ "-" *
		  t #2 global.max$ substring$ 't :=
		}
	      while$
	    }
	  if$
	}
	{ t #1 #1 substring$ *
	  t #2 global.max$ substring$ 't :=
	}
      if$
    }
  while$
}

FUNCTION {format.date}
{ before.year 'output.state :=				% 1.00(1)
  year empty$
    { month empty$
	{ "" }
	{ "there's a month but no year in " cite$ * warning$
          ""						% 1.00(5)
	}
      if$
    }
    { "(" year ")" * * }				% 1.00(5)
  if$
}

FUNCTION {format.ref.date}				% 3.00(1)>>
{ before.year 'output.state :=
  "\refdatee{" refdate "}" * *
}							% 3.00(1)<<

FUNCTION {tie.or.space.connect}
{ duplicate$ text.length$ #3 <
    { "~" }
    { "\ " }						% 1.00(6)
  if$
  swap$ * *
}

FUNCTION {output.volume}
{ 
  volume empty$
    'skip$
    { "Vol.~" volume * output}
  if$

}

FUNCTION {output.number}
{
  number empty$
    'skip$
    { "No.~" number * output}
  if$
}

FUNCTION {output.series.volume.number}
{ series empty$
    { output.volume
      output.number }
    { series output
      output.volume
      output.number }
 if$
}

FUNCTION {format.edition}
{ edition empty$
    { "" }
    { output.state mid.sentence =
	{ edition "l" change.case$ " edition" * }
	{ edition "t" change.case$ " edition" * }
      if$
    }
  if$
}

INTEGERS { multiresult }

FUNCTION {multi.page.check}
{ 't :=
  #0 'multiresult :=
    { multiresult not
      t empty$ not
      and
    }
    { t #1 #1 substring$
      duplicate$ "-" =
      swap$ duplicate$ "," =
      swap$ "+" =
      or or
	{ #1 'multiresult := }
	{ t #2 global.max$ substring$ 't := }
      if$
    }
  while$
  multiresult
}

FUNCTION {format.online}				% 3.00(1)>>
{ duplicate$ empty$
    { "(online)" * }
    { " (online)" * }
  if$
}							% 3.00(1)<<

FUNCTION {format.url}					% 3.00(1)>>
{ "\urle{" url "}" * *
}							% 3.00(1)<<

FUNCTION {format.pages}					% 1.00(7)
{ pages empty$
    { "" }
    { pages multi.page.check
	{ "pp." pages n.dashify tie.or.space.connect }
	{ "p." pages tie.or.space.connect }
      if$
    }
  if$
}

FUNCTION {format.doi.url}				% 3.00(1)>>
{ doi empty$
    { url empty$
	'skip$
	{ format.online output.nonnull
	  format.url
	}
	if$
    }
    { format.online output.nonnull
      "\doi{" doi "}" * *
    }
  if$							% 3.00(1)<<
}

FUNCTION {format.pages.output}				% 3.00(1)>>
{ format.pages
  format.doi.url output					% 3.00(1)<<
}

FUNCTION {format.vol.num.pages}				% 1.00(8)
{ volume empty$
  { ""}
  { " Vol.~" volume * }
  if$ 
  number empty$
    'skip$
    { volume empty$
	{ "there's a number but no volume in " cite$ * warning$ }
	{ "," *}
      if$
      " No.~" number * *
    }
  if$
  pages empty$
    'skip$
    { duplicate$ empty$
	{ pop$ format.pages }
	{ ", " * format.pages * }
      if$
    }
  if$
  format.doi.url					% 3.00(1)
}

FUNCTION {format.chapter.pages}
{ chapter empty$
    'format.pages
    { type empty$
	{ "chapter" chapter tie.or.space.connect }
        { type "l" change.case$ chapter tie.or.space.connect }
      if$
      pages empty$
	'skip$
	{ ", " * format.pages * }
      if$
    }
  if$
  format.doi.url					% 3.00(1)
}

FUNCTION {format.in.ed.booktitle}
{ booktitle empty$
    { "" }
    { booktitle emphasize
      editor empty$
	'skip$
	{ " (" * format.editors.inparen * ")" *}	% 1.00(9), 2.00(6)
      if$
    }
  if$
}

FUNCTION {empty.misc.check}
{ author empty$ title empty$ howpublished empty$
  month empty$ year empty$ note empty$
  and and and and and
  key empty$ not and
    { "all relevant fields are empty in " cite$ * warning$ }
    'skip$
  if$
}

FUNCTION {format.thesis.type}
{ type empty$
    'skip$
    { pop$
      type "t" change.case$
    }
  if$
}

FUNCTION {format.tr.number}
{ type empty$
    { "Technical Report" }
    {type}
  if$
  number empty$
    { "t" change.case$ }
    { " " number * * }
  if$
}

FUNCTION {format.article.crossref}			% 2.00(8)
{ key empty$
    { journal empty$
	{ "need key or journal for " cite$ * " to crossref " * crossref *
	  warning$
	  ""
	}
	{ journal emphasize }				% 1.00(10)
      if$
    }
    { "In " key * }
  if$
  " \cite{" * crossref * "}" *
}

FUNCTION {format.crossref.editor}			% 1.00(11)
{ editor #1 "{vv }{ll}" format.name$
  editor num.names$ duplicate$
  #2 >
    {pop$ " et al." * }
    { #2 <
	'skip$
	{ editor #2 "{ff }{vv }{ll}{ jj}" format.name$ "others" =
	    {" et al." * }
	    {" and " * editor #2 "{vv }{ll}" format.name$ * }
	  if$
	}
      if$
    }
  if$
}

FUNCTION {format.book.crossref}				% 2.00(8)
{ editor empty$
  editor field.or.null author field.or.null =
  or
    { key empty$
	{ series empty$
	    { "need editor, key, or series for " cite$ * " to crossref " *
	      crossref * warning$
	      ""
	    }
	    { series emphasize }			% 1.00(10)
	  if$
	}
	{ "In " key * }
      if$
    }
    { format.crossref.editor }
  if$
  " \cite{" * crossref * "}" *
  volume empty$
    { "empty volume in " cite$ * "'s crossref of " * crossref * warning$ }
    { * "Vol." * volume tie.or.space.connect }
  if$
}

FUNCTION {format.incoll.inproc.crossref}		% 2.00(8)
{ editor empty$
  editor field.or.null author field.or.null =
  or
    { key empty$
	{ booktitle empty$
	    { "need editor, key, or booktitle for " cite$ * " to crossref " *
	      crossref * warning$
	      ""
	    }
	    { booktitle emphasize }			% 1.00(10)
	  if$
	}
	{ "In " key * }
      if$
    }
    { format.crossref.editor }
  if$
  " \cite{" * crossref * "}" *
}

FUNCTION {article}
{ 
%%%%
  author  "author"  required.argument
  title   "title"   required.argument
  journal "journal" required.argument
  year    "year"    required.argument
%%%% jssst
  volume  "volume"  
  number  "number"  
     required.and.or.argument
  pages   "pages"   required.argument
%%%%
  output.bibitem 
  format.authors add.colon				% 2.00(5)
  title output
  crossref missing$
    { journal emphasize output
      format.vol.num.pages output			% 1.00(12)
      format.date output
    }
    { format.article.crossref output.nonnull
      format.pages.output				% 3.00(1)
    }
  if$
  new.block
  note output
  fin.entry
}

FUNCTION {book}
{ 
%%%%
  author  "author"
  editor  "editor"
    required.exclusive.or.argument
  title   "title"  required.argument
  publisher "publisher" required.argument
  year    "year" required.argument
  optional.series.volume.number.argument
%%%%
  output.bibitem
  author empty$
    { format.editors}
    { format.authors}
  if$
  add.colon						% 2.00(5)
  title emphasize output
  crossref missing$
    { output.series.volume.number
      publisher output
      address output
    }
    { new.block
      format.book.crossref output.nonnull
    }
  if$
  format.edition output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {booklet}
{
%%%%
  title   "title"   required.argument
%%%% jssst
  author  "author"  required.argument
%%%%
  output.bibitem
  format.authors add.colon				% 2.00(5)
  title output
  howpublished output
  address output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {inbook}
{ 
%%%%
  author  "author"
  editor  "editor"
     required.exclusive.or.argument
  title   "title"  required.argument
  chapter "chapter"
  pages   "pages"
     required.and.or.argument
  publisher  "publisher" required.argument
  year       "year"      required.argument

  optional.series.volume.number.argument
%%%%
  output.bibitem 
  author empty$
    { format.editors}
    { format.authors}
  if$
  add.colon						% 2.00(5)
  title emphasize output
  crossref missing$
    { output.series.volume.number
      format.chapter.pages output
      publisher output
    }
    { format.chapter.pages output
      new.block
      format.book.crossref output.nonnull
    }
  if$
  format.edition output
  format.date output					% 1.00(13)
  new.block
  note output
  fin.entry
}

FUNCTION {incollection}
{
%%%%
  author    "author"    required.argument
  title     "title"     required.argument
  booktitle "booktitle" required.argument
  publisher "publisher" required.argument
  year      "year"      required.argument

  optional.series.volume.number.argument
%%%%
  output.bibitem
  format.authors add.colon				% 2.00(5)
  title output
  crossref missing$
    { format.in.ed.booktitle output
      output.series.volume.number
      publisher output
      address output
      format.edition output
      format.chapter.pages output			% 1.00(13)
      format.date output
    }
    { format.incoll.inproc.crossref output.nonnull
      format.chapter.pages output
    }
  if$
  new.block
  note output
  fin.entry
}

FUNCTION {inproceedings}
{
%%%%
  author    "author"    required.argument
  title     "title"     required.argument
  year      "year"      required.argument

  optional.series.volume.number.argument
%%%%
  output.bibitem 
  format.authors add.colon				% 2.00(5)
  title output
  crossref missing$
    { format.in.ed.booktitle output
      booktitle "booktitle" required.argument
      output.series.volume.number
      address output
      organization output
      publisher output
      format.pages.output				% 3.00(1)
      format.date output				% 1.00(13)
    }
    { format.incoll.inproc.crossref output.nonnull
      format.pages.output				% 3.00(1)
    }
  if$
  new.block
  note output
  fin.entry
}

FUNCTION {conference} { inproceedings }

FUNCTION {manual}
{	
%%%%
  title   "title"    required.argument
%%%% jssst
  author   "author"
  organization "organazaion"
     required.exclusive.or.argument
%%%%
  output.bibitem
  author empty$
    { organization}
    { format.authors}
  if$
  add.colon						% 2.00(5)
  title emphasize output
  author empty$
    'skip$
    { organization output }
  if$
  address output
  format.edition output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {mastersthesis}
{
%%%%
  author   "author"  required.argument
  title    "title"   required.argument
  school   "school"  required.argument
  year     "year"    required.argument
%%%%
  output.bibitem
  format.authors add.colon				% 2.00(5)
  title output
  "Master's thesis"
  format.thesis.type output.nonnull
  school output
  address output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {misc}
{
%%%%
%%%% jssst
  author "author" required.argument
  title  "title"  required.argument
%%%%
  output.bibitem
  format.authors add.colon				% 2.00(5)
  title output
  howpublished output
  format.date output
  new.block
  note output
  fin.entry
  empty.misc.check
}

FUNCTION {phdthesis}
{
%%%%
  author   "author"  required.argument
  title    "title"   required.argument
  school   "school"  required.argument
  year     "year"    required.argument
%%%%
  output.bibitem 
  format.authors add.colon				% 2.00(5)
  title output						% 2.00(9)
  "PhD Thesis"
  format.thesis.type output.nonnull
  school output
  address output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {proceedings}
{
%%%%
  title  "title"  required.argument
  year   "year"   required.argument

  optional.series.volume.number.argument
%%%% jssst
  editor  "editor"
  organization "organization"
      required.exclusive.or.argument 
%%%%
  output.bibitem 
  editor empty$
    { organization }
    { format.editors }
  if$
  add.colon						% 2.00(5)
  title emphasize output
  output.series.volume.number
  address output
  editor empty$
    'skip$
    { organization output }
  if$
  publisher output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {techreport}
{
%%%%
  author   "author"   required.argument
  title    "title"    required.argument
  institution "institution" required.argument
  year     "year"     required.argument
%%%%
  output.bibitem
  format.authors add.colon				% 2.00(5)
  title output
  format.tr.number output.nonnull
  institution output
  address output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {unpublished}
{
%%%%
  author   "author"   required.argument
  title    "title"    required.argument
  note     "note"     required.argument
%%%%
  output.bibitem
  format.authors add.colon				% 2.00(5)
  title output
  format.date output
  new.block
  note output
  fin.entry
}

FUNCTION {webpage}					% 3.00(1)>>
{
%%%%
  author       "author"       required.argument
  title        "title"        required.argument
  url          "url"          required.argument
  refdate      "refdate"      required.argument
%%%%
  output.bibitem
  format.authors add.colon
  title output
  organization format.doi.url output
  format.ref.date output
  new.block
  note output
  fin.entry
}							% 3.00(1)<<

FUNCTION {default.type} { misc }

MACRO {jan} {"January"}

MACRO {feb} {"February"}

MACRO {mar} {"March"}

MACRO {apr} {"April"}

MACRO {may} {"May"}

MACRO {jun} {"June"}

MACRO {jul} {"July"}

MACRO {aug} {"August"}

MACRO {sep} {"September"}

MACRO {oct} {"October"}

MACRO {nov} {"November"}

MACRO {dec} {"December"}

MACRO {acmcs} {"ACM Computing Surveys"}

MACRO {acta} {"Acta Informatica"}

MACRO {cacm} {"Communications of the ACM"}

MACRO {ibmjrd} {"IBM Journal of Research and Development"}

MACRO {ibmsj} {"IBM Systems Journal"}

MACRO {ieeese} {"IEEE Transactions on Software Engineering"}

MACRO {ieeetc} {"IEEE Transactions on Computers"}

MACRO {ieeetcad}
 {"IEEE Transactions on Computer-Aided Design of Integrated Circuits"}

MACRO {ipl} {"Information Processing Letters"}

MACRO {jacm} {"Journal of the ACM"}

MACRO {jcss} {"Journal of Computer and System Sciences"}

MACRO {scp} {"Science of Computer Programming"}

MACRO {sicomp} {"SIAM Journal on Computing"}

MACRO {tocs} {"ACM Transactions on Computer Systems"}

MACRO {tods} {"ACM Transactions on Database Systems"}

MACRO {tog} {"ACM Transactions on Graphics"}

MACRO {toms} {"ACM Transactions on Mathematical Software"}

MACRO {toois} {"ACM Transactions on Office Information Systems"}

MACRO {toplas} {"ACM Transactions on Programming Languages and Systems"}

MACRO {tcs} {"Theoretical Computer Science"}

READ

FUNCTION {sortify}
{ purify$
  "l" change.case$
}

INTEGERS { len }

FUNCTION {chop.word}
{ 's :=
  'len :=
  s #1 len substring$ =
    { s len #1 + global.max$ substring$ }
    's
  if$
}

FUNCTION {sort.format.names}
{ 's :=
  #1 'nameptr :=
  ""
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { nameptr #1 >
	{ "   " * }
	'skip$
      if$
      s nameptr "{vv{ } }{ll{ }}{  ff{ }}{  jj{ }}" format.name$ 't :=
      nameptr numnames = t "others" = and
	{ "et al" * }
	{ t sortify * }
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

FUNCTION {sort.format.title}
{ 't :=
  "A " #2
    "An " #3
      "The " #4 t chop.word
    chop.word
  chop.word
  sortify
  #1 global.max$ substring$
}

FUNCTION {author.sort}
{ author empty$
    { key empty$
	{ "to sort, need author or key in " cite$ * warning$
	  ""
	}
	{ key sortify }
      if$
    }
    { author sort.format.names }
  if$
}

FUNCTION {author.editor.sort}
{ author empty$
    { editor empty$
	{ key empty$
	    { "to sort, need author, editor, or key in " cite$ * warning$
	      ""
	    }
	    { key sortify }
	  if$
	}
	{ editor sort.format.names }
      if$
    }
    { author sort.format.names }
  if$
}

FUNCTION {author.organization.sort}
{ author empty$
    { organization empty$
	{ key empty$
	    { "to sort, need author, organization, or key in " cite$ * warning$
	      ""
	    }
	    { key sortify }
	  if$
	}
	{ "The " #4 organization chop.word sortify }
      if$
    }
    { author sort.format.names }
  if$
}

FUNCTION {editor.organization.sort}
{ editor empty$
    { organization empty$
	{ key empty$
	    { "to sort, need editor, organization, or key in " cite$ * warning$
	      ""
	    }
	    { key sortify }
	  if$
	}
	{ "The " #4 organization chop.word sortify }
      if$
    }
    { editor sort.format.names }
  if$
}

FUNCTION {presort}
{ type$ "book" =
  type$ "inbook" =
  or
    'author.editor.sort
    { type$ "proceedings" =
	'editor.organization.sort
	{ type$ "manual" =
	    'author.organization.sort
	    'author.sort
	  if$
	}
      if$
    }
  if$
  "    "
  *
  year field.or.null sortify
  *
  "    "
  *
  title field.or.null
  sort.format.title
  *
  #1 entry.max$ substring$
  'sort.key$ :=
}

ITERATE {presort}

SORT

STRINGS { longest.label }

INTEGERS { number.label longest.label.width }

FUNCTION {initialize.longest.label}
{ "" 'longest.label :=
  #1 'number.label :=
  #0 'longest.label.width :=
}

FUNCTION {longest.label.pass}
{ number.label int.to.str$ 'label :=
  number.label #1 + 'number.label :=
  label width$ longest.label.width >
    { label 'longest.label :=
      label width$ 'longest.label.width :=
    }
    'skip$
  if$
}

EXECUTE {initialize.longest.label}

ITERATE {longest.label.pass}

FUNCTION {begin.bib}
{ preamble$ empty$
    'skip$
    { preamble$ write$ newline$ }
  if$
  "\begin{thebibliography}{"  longest.label  * "}" * write$ newline$
}

EXECUTE {begin.bib}

EXECUTE {init.state.consts}

ITERATE {call.type$}

FUNCTION {end.bib}
{ newline$
  "\end{thebibliography}" write$ newline$
}

EXECUTE {end.bib}


