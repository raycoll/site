SOURCE_DOCS := $(wildcard *.md)
EXPORTED_DOCS=$(SOURCE_DOCS:.md=.html)
OBJECT_NAME := index.html
OBJECT_VERSION_FILE := object_version
CURRENT_VERSION := $(shell cat ${OBJECT_VERSION_FILE})
NEXT_VERSION := $(shell echo "${CURRENT_VERSION}+1" | bc)
NEXT_VERSION_OBJECT_NAME := $(OBJECT_NAME).$(NEXT_VERSION)

DISTRIBUTION_ID_FILE := distribution_name
CF_DISTRIBUTION_ID := $(shell cat ${DISTRIBUTION_ID_FILE})

%.html : %.md
	pandoc -f markdown -t html5 -o $@ $<

.PHONY: all clean s3upload

all : $(EXPORTED_DOCS)

clean:
	- rm $(EXPORTED_DOCS)

s3upload: all
	# Store the current object as a new version object.
	aws s3 cp $(OBJECT_NAME)  s3://raycoll.com-website/$(NEXT_VERSION_OBJECT_NAME)
	# Move the CF distribution to point at it.
	echo "the distribution id $(CF_DISTRIBUTION_ID)"
	AWS_PAGER="" aws cloudfront update-distribution --id $(CF_DISTRIBUTION_ID) --default-root-object $(NEXT_VERSION_OBJECT_NAME)
	# Increment the version file
	echo "$(NEXT_VERSION)" > $(OBJECT_VERSION_FILE)
