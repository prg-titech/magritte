LATEX_OPTS += -shell-escape

CLEAN = doc/paper.pdf doc/paper.log doc/paper.aux doc/paper.out doc/paper-autopp* doc/paper.bbl

.PHONY: open-doc
open-doc: doc/paper.pdf
	open "$^" &

.PHONY: doc
doc: doc/paper.pdf

%.pdf: %.tex
	pdflatex $(LATEX_OPTS) -output-directory $(dir $^) $^

.PHONY: clean
clean:
	rm -- $(CLEAN)

.PHONY: paper-watch
paper-watch:
	latexmk -pvc -pdf $(LATEX_OPTS) -view=none -output-directory=doc doc/paper.tex
