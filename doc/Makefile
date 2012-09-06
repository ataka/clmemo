#
# clmemo/doc Makefile
#

## Copyright (C) 2005  Masayuki Ataka  <masayuki.ataka@gmail.com>

SRC       = clmemo
PART      = install.texi news.texi
TMPCSS    = tmp.css
INFO      = changelog

prefix    = /usr/local
datadir   = ${prefix}/share
infodir   = ${datadir}/info

TEX       = ptex
MAKEINFO  = makeinfo
TEXI2INFO = $(MAKEINFO)
TEXI2HTML = $(MAKEINFO) --html --no-split --enable-encoding \
            --number-sections --css-include=$(TMPCSS) #-D website
TEXI2DVI  = TEX=$(TEX) texi2dvi

.PHONY : info html dvi ps pdf
info: $(INFO).info
html: $(INFO).html
dvi:  $(SRC).dvi
ps:   $(SRC).ps
pdf:  $(SRC).pdf

$(INFO).info: $(SRC).texi $(PART)
	$(TEXI2INFO) $<

$(INFO).html: $(SRC).texi $(PART) $(TMPCSS)
	$(TEXI2HTML) $<

$(SRC).dvi: $(SRC).texi $(PART)
#	$(TEXI2DVI) $<
	$(TEX) $<
	$(TEX) $<
	texindex $(SRC).??
	$(TEX) $<

$(SRC).ps: $(SRC).dvi
	dvips -o $@ $<
$(SRC).pdf: $(SRC).dvi
	dvipdfmx $<

#
# clean target
#
RM = rm -f
.PHONY : clean distclean
clean:
	$(RM) *~
	$(RM) *.aux *.log *.toc
	$(RM) *.cp{,s}  *.fn{,s}  *.ky{,s}  *.pg{,s}  *.tp{,s}  *.vr{,s}

distclean: clean
	$(RM) $(SRC).dvi $(INFO).html *.info
	$(RM) $(SRC).ps $(SRC).pdf

#
# install target
#
INSTALL = install -m 644
.PHONY : install
install: $(INFO).info
	if [ ! -d $(infodir) ]; then \
	  $(MKDIR) -p $(infodir); \
	fi
	$(INSTALL) $^ $(infodir)

../INSTALL.ja: install.texi
	$(MAKEINFO) --no-headers -D rawfile $< --output $@
