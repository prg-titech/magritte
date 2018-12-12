LATEX_OPTS += -shell-escape
LATEX_OPTS += -kanji=utf8 -kanji-internal=utf8 -etex

CLEAN = doc/paper.pdf doc/paper.log doc/paper.aux doc/paper.out doc/paper-autopp* doc/paper.bbl doc/paper.dvi

.PHONY: open-doc
open-doc: doc/paper.pdf
	open "$^" &

.PHONY: doc
doc: doc/paper.pdf

%.dvi: %.tex
	uplatex $(LATEX_OPTS) -output-directory $(dir $^) $^

%.pdf: %.dvi
	dvipdf "$^" "$@"


.PHONY: clean
clean:
	rm -f -- $(CLEAN)

# LATEXMK_OPTS += $(LATEX_OPTS)
LATEXMK_OPTS += -pdfdvi -latex='uplatex $(LATEX_OPTS)'
LATEXMK_OPTS += -view=none
LATEXMK_OPTS += -output-directory=doc
LATEXMK_OPTS += -e '$$bibtex="pbibtex"'


.PHONY: paper-watch
paper-watch:
	latexmk $(LATEXMK_OPTS) doc/paper.tex
