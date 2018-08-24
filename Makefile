LATEX_OPTS = -shell-escape

.PHONY: all
all: doc/paper.pdf
	evince $^

%.pdf: %.tex
	pdflatex $(LATEX_OPTS) -output-directory $(dir $^) $^
