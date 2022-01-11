PROPOSAL = p.tex
BASE := $(basename $(PROPOSAL))
#BIOS = bio-schwarzkopf.pdf
PIECEMEAL = submit-summary.pdf submit-description.pdf submit-references.pdf \
	    submit-datamgmt.pdf
EVERYTHING = $(BASE).pdf $(PIECEMEAL) $(BIOS)
SPELLTEX := $(shell ./bin/get-tex-files.sh $(PROPOSAL))

BIBS := $(wildcard *.bib)

OURENV = TEXINPUTS="sty:"

LATEX = $(OURENV) pdflatex

all: p.pdf $(PIECEMEAL) submit-summary.txt
pieces: $(PIECEMEAL)
#bios: $(BIOS)

# parts depend on the whole
$(PIECEMEAL): $(BASE).pdf

p.pdf : $(BIBS)

code/fmt.tex:
	pygmentize -f latex -S default \
		| grep -vw 'PY@tok@m' \
		| grep -vw 'PY@tok@mi' \
		| grep -vw 'PY@tok@o' \
	  |	grep -vw 'PY@tok@err'\
		> $@~
	mv $@~ $@

code/%.tex: code/%.go
	pygmentize -P mathescape -f latex $< | python2 pygmentize-refmt.py > $@

code/%.tex: code/%.py
	pygmentize -P mathescape -f latex $< | python2 pygmentize-refmt.py > $@

pygmentize: code/fmt.tex $(patsubst %.v,%.tex,$(wildcard code/*.v))

fig/%.pdf: fig/%.svg
	inkscape -z --export-area-drawing --export-pdf=$@ $<

fig/%.pdf: fig/%.plot fig/%.data
	gnuplot $<

PDFGRAPHS := $(addprefix fig/, $(addsuffix .pdf, ))

plots: $(patsubst fig/%.plot,fig/%.pdf,$(wildcard fig/*.plot))
.PHONY: plots

RERUN = egrep -q '(^LaTeX Warning:|\(\biblatex)).* rerun'
UNDEFINED = egrep -q '^.+\.tex:[0-9]+: Citation .* undefined'

$(BASE).pdf: $(BASE).tex $(SPELLTEX) $(PDFGRAPHS)
	PATH=$$PATH:. latexrun --bibtex-cmd=biber --latex-args=-synctex=1 $<
	cp latex.out/submit-*.tex .

%.pdf: %.tex $(SPELLTEX)
	PATH=$$PATH:. latexrun --bibtex-cmd=biber --latex-args=-synctex=1 $<

$(PIECEMEAL): %.pdf : $(SPELLTEX)

BIO_RULES = \
	usr=`expr $@ : 'bio-\([a-z]*\).pdf'`;			\
	echo $*; \
	(test ! -s $*.aux || ./bcv -$$usr || rm -f $*.aux)	\
	&& $(LATEX) $*						\
	&& (if grep -q 'rerun' $*.log; then			\
		./bcv -$$usr					\
		latex $*;					\
		grep -q 'rerun' $*.log && $(LATEX) $*; :;	\
		grep -q 'rerun' $*.log && $(LATEX) $*; :;	\
	fi); 							\
	rm -f bio-$${usr}*.bbl bio-$${usr}*.blg bio-$${usr}*.aux

$(BIOS) : %.pdf : %.tex $(BIBS)
	$(BIO_RULES)

submit-summary.txt: summary.tex
	cat $< | \
            sed -e 's/\\name/CBC/g' | \
            sed -e 's/\\emph//g' | \
            sed -e 's/\\textbf//g' | \
            sed -e 's/\\section\*{SaTC CORE: \\proptitle{}}//g' | \
            sed -e 's/\\label{sec:summary}//g' | \
	    sed -e 's/\\texttt//g' | \
            sed -e 's/{//g' | \
            sed -e 's/}//g' | \
            sed -e 's/\\paragraph//g' | \
            sed -e 's/%.*//g' | \
            fmt -w1000 > $@

xpdf: $(BASE).pdf
	if test -f .xpdf-running; then			\
		xpdf -remote $(BASE)-server -quit;	\
		sleep 1;				\
	fi
	touch .xpdf-running
	(xpdf -remote $(BASE)-server $(BASE).pdf; rm -f .xpdf-running) &

spell:
	@ for i in $(SPELLTEX); do aspell --mode=tex \
					  --add-tex-command="XXX oo" \
					  --add-tex-command="autoref p" \
					  -p ./aspell.words -c $$i; done
	@ for i in $(SPELLTEX); do perl bin/double.pl $$i; done
	@ for i in $(SPELLTEX); do perl bin/abbrv.pl  $$i; done
	@ bash bin/hyphens.sh $(SPELLTEX)
	@ ( head -1 aspell.words ; tail -n +2 aspell.words | sort ) > aspell.words~
	@ mv aspell.words~ aspell.words

clean:
	-rm -rf latex.out
	-rm -f *.aux *.dvi *.log *.blg *.bbl *.bak *.lof *.lot *.toc *.brf *.out
	-rm -f $(EVERYTHING)
	-rm -f $(PIECEMEAL:.pdf=.tex)
	-rm -f $(BASE_NORED).pdf
	-rm -f $(EPSFIGS) $(PDFFIGS) $(EPSGRAPHS)

.PHONY: clean spell

code/%.tex: code/%.v
	pygmentize -f latex $< > $@
