# $Id$

ENGINE = /usr/local/gwTeX/bin/powerpc-apple-darwin-current/
TEMP = tmp


all : clean pdf html

manual.bbl : clean-aux 
	$(ENGINE)pdflatex manual
	$(ENGINE)bibtex manual

html : manual.bbl clean-aux
	$(ENGINE)htlatex manual "htmanual"
	cp manual.html ../../index.html
	cp *.css ../../


pdf : manual.bbl clean-aux
	$(ENGINE)pdflatex manual
	$(ENGINE)pdflatex manual
	cp manual.pdf ../
tmp :  	
	mkdir $(TEMP)

clean-aux : 
	@rm -f *.aux *.lg *.4ct *.4tc *.log *.ps *~ *.dvi \
	*.idv *.tmp *.xref *.toc *.out *.idx *.ind *.ilg *.4dx *.4ix

clean : clean-aux
	@rm -f *.pdf *.html *.png *.bbl *.blg