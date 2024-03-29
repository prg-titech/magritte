# use the correct latex and bibtex
UPLATEXMK_OPTS += -pdfdvi
UPLATEXMK_OPTS += -latex=uplatex
UPLATEXMK_OPTS += -latexoption='-shell-escape'
UPLATEXMK_OPTS += -latexoption='-kanji=utf8'
UPLATEXMK_OPTS += -e '$$bibtex="pbibtex"' #; $$dvipdf="dvipdfmx %O %S"'
# don't open a viewer
UPLATEXMK_OPTS += -view=none

PDFLATEXMK_OPTS += -pdf
PDFLATEXMK_OPTS += -latexoption='-shell-escape'
PDFLATEXMK_OPTS += -usepretex='\def\sigplan{1}'
PDFLATEXMK_OPTS += -view=none

CLEAN += doc/paper.pdf doc/paper.log doc/paper.aux doc/paper.out doc/paper-autopp* doc/paper.bbl doc/paper.dvi

all: vm

.PHONY: open-doc
open-doc: doc/paper.pdf
	open "$^" &

.PHONY: doc
doc: doc/paper.pdf

%.pdf: %.tex %.bib
	latexmk $(LATEXMK_OPTS) -output-directory=$(dir $<) $<

.PHONY: sigpro-watch
sigpro-watch:
	latexmk -pvc $(UPLATEXMK_OPTS) -output-directory=doc doc/paper.tex

.PHONY: sigplan-watch
sigplan-watch:
	latexmk -pvc $(PDFLATEXMK_OPTS) -output-directory=doc doc/paper.tex

.PHONY: clean
clean:
	rm -f -- $(CLEAN)

VM_BIN=./bin/magvm
CLEAN += $(VM_BIN)

$(VM_BIN): lib/magvm/*.py
	./bin/rpython-compile ./lib/magvm/targetmagritte.py
	mv targetmagritte-c $(VM_BIN)

TEST_FILE=./test/test.mag

DYNAMIC ?= 0

.PHONY: vm
vm: $(VM_BIN)

.PHONY: test
test: $(VM_BIN) $(TEST_FILE)
	./bin/mag $(TEST_FILE)

.PHONY: test-dynamic
test-dynamic: $(TEST_FILE)
	./bin/mag-dynamic $(TEST_FILE)

CLEAN += **/*.magc **/*.magx
