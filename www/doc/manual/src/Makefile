# $Id$

ENGINE = /usr/local/gwTeX/bin/i386-apple-darwin-current/
TEMP = tmp

ifdef APM
	ifndef REPOSITORY
		REPOSITORY = $(APM) 
	endif
endif

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

# some release-related targets

release-clean : 
	@ rm -f *.apm *.tar

release-trunk : 
	@if [ "$$APM" = "" ]; then echo 1>&2 "APM must be set to the APM package name (package key)!"; exit 1; fi
	@svn export http://svn.thinkersfoot.net/$(strip $(REPOSITORY))/trunk $(APM)
	@tar cf $(APM)-trunk.tar $(APM)
	@gzip -9 --to-stdout $(APM)-trunk.tar > $(APM)-trunk.apm
	@rm -f $(APM)-trunk.tar
	@rm -rf $(APM)

release-deploy : release-clean release-trunk release-tag
	@scp *.apm sobernig@alice.wu-wien.ac.at:/home/xotcl/www.xotcl.org/download/

release-tag : 
	@if [ "$$TAG" = "" ]; then echo 1>&2 "TAG must be set to version number!"; exit 1; fi
	@if [ "$$APM" = "" ]; then echo 1>&2 "APM must be set to the APM package name (package key)!"; exit 1; fi
	@echo 1>&2 "TAG=$(TAG),REP=$(REPOSITORY),APM=$(APM)"
	@svn export http://svn.thinkersfoot.net/$(strip $(REPOSITORY))/tags/release-${TAG} $(APM)
	@tar cf $(APM)-$(TAG).tar $(APM)
	@gzip -9 --to-stdout $(APM)-$(TAG).tar > $(APM)-$(TAG).apm
	@rm -f $(APM)-$(TAG).tar
	@rm -rf $(APM)
