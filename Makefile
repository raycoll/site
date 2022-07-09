SOURCE_DOCS := $(wildcard *.md)
EXPORTED_DOCS=$(SOURCE_DOCS:.md=.html)

%.html : %.md
	pandoc -f markdown -t html5 -o $@ $<

.PHONY: all clean s3upload

all : $(EXPORTED_DOCS)

clean:
	- rm $(EXPORTED_DOCS)

s3upload: all
	aws s3 cp index.html  s3://raycoll.com-website/index11.html
