LATEX_OPTS += -shell-escape
LATEX_OPTS += -kanji=utf8

# use the correct latex and bibtex
LATEXMK_OPTS += -pdfdvi -latex='uplatex $(LATEX_OPTS)'
LATEXMK_OPTS += -e '$$bibtex="pbibtex"' #; $$dvipdf="dvipdfmx %O %S"'
# don't open a viewer
LATEXMK_OPTS += -view=none

CLEAN = doc/paper.pdf doc/paper.log doc/paper.aux doc/paper.out doc/paper-autopp* doc/paper.bbl doc/paper.dvi

.PHONY: open-doc
open-doc: doc/paper.pdf
	open "$^" &

.PHONY: doc
doc: doc/paper.pdf

%.pdf: %.tex %.bib
	latexmk $(LATEXMK_OPTS) -output-directory=$(dir $<) $<

.PHONY: paper-watch
paper-watch:
	latexmk -pvc $(LATEXMK_OPTS) -output-directory=doc doc/paper.tex


.PHONY: clean
clean:
	rm -f -- $(CLEAN)
