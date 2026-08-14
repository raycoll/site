SOURCE_DOCS := $(wildcard *.md)
EXPORTED_DOCS=$(SOURCE_DOCS:.md=.html)
OBJECT_NAME := index.html
OBJECT_VERSION_FILE := object_version
CURRENT_VERSION := $(shell cat ${OBJECT_VERSION_FILE})
NEXT_VERSION := $(shell echo "${CURRENT_VERSION}+1" | bc)
NEXT_VERSION_OBJECT_NAME := $(OBJECT_NAME).$(NEXT_VERSION)

DISTRIBUTION_ID_FILE := distribution_name
CF_DISTRIBUTION_ID := $(shell cat ${DISTRIBUTION_ID_FILE})

# Deploys assume the website-deploy role, which prompts for MFA. `?=` leaves an
# already-exported AWS_PROFILE alone, so `AWS_PROFILE=other make update_page`
# still overrides this.
AWS_PROFILE ?= deploy
export AWS_PROFILE

%.html : %.md
	pandoc -f markdown -t html5 -o $@ $<

.PHONY: all clean s3upload

all : $(EXPORTED_DOCS)

clean:
	- rm $(EXPORTED_DOCS)

S3_BUCKET := raycoll.com-website

# Deploy: upload the built page under a new version name, then repoint the
# distribution's default root object at it.
#
# The whole recipe is one shell with `set -e`, so any failing step aborts
# before the version file is bumped. Previously each line ran in its own
# shell and the bump happened unconditionally, which silently desynced
# $(OBJECT_VERSION_FILE) from what CloudFront was actually serving.
#
# The distribution update reads the live config, changes only
# DefaultRootObject, and writes it back with --if-match. Passing
# --default-root-object alone would send an otherwise-empty config to the
# AWS CLI v2 and drop the aliases and TLS cert on this distribution.
update_page: all
	@set -e; \
	echo "==> uploading $(NEXT_VERSION_OBJECT_NAME) to s3://$(S3_BUCKET)/"; \
	aws s3 cp $(OBJECT_NAME) s3://$(S3_BUCKET)/$(NEXT_VERSION_OBJECT_NAME); \
	echo "==> repointing distribution $(CF_DISTRIBUTION_ID) at $(NEXT_VERSION_OBJECT_NAME)"; \
	tmp=$$(mktemp -d); \
	trap 'rm -rf "$$tmp"' EXIT; \
	AWS_PAGER="" aws cloudfront get-distribution-config \
	  --id $(CF_DISTRIBUTION_ID) --output json > $$tmp/live.json; \
	etag=$$(jq -r '.ETag' $$tmp/live.json); \
	jq '.DistributionConfig | .DefaultRootObject = "$(NEXT_VERSION_OBJECT_NAME)"' \
	  $$tmp/live.json > $$tmp/next.json; \
	AWS_PAGER="" aws cloudfront update-distribution \
	  --id $(CF_DISTRIBUTION_ID) \
	  --if-match "$$etag" \
	  --distribution-config file://$$tmp/next.json \
	  --query 'Distribution.DistributionConfig.DefaultRootObject' --output text; \
	echo "$(NEXT_VERSION)" > $(OBJECT_VERSION_FILE); \
	echo "==> deployed version $(NEXT_VERSION)"

server: $(EXPORTED_DOCS)
	python3 -m http.server
