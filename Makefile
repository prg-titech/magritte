LATEX_OPTS = -shell-escape

.PHONY: open-doc
open-doc: doc/paper.pdf
	open "$^"

.PHONY: doc
doc: doc/paper.pdf

%.pdf: %.tex
	pdflatex $(LATEX_OPTS) -output-directory $(dir $^) $^
