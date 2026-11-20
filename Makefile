SOURCE_DOCS := $(wildcard *.md)
EXPORTED_DOCS=$(SOURCE_DOCS:.md=.html)
OBJECT_NAME := index.html
CF_DISTRIBUTION_ID ?= $(shell cat distribution_name 2>/dev/null)

# Deploys assume the website-deploy role, which prompts for MFA. `?=` leaves an
# already-exported AWS_PROFILE alone, so `AWS_PROFILE=other make update_page`
# still overrides this.
AWS_PROFILE ?= deploy
export AWS_PROFILE

%.html : %.md
	pandoc -f markdown -t html5 -o $@ $<

.DEFAULT_GOAL := all
.PHONY: all clean update_page server

all : $(EXPORTED_DOCS)

clean:
	- rm $(EXPORTED_DOCS)

S3_BUCKET := raycoll.com-website

update_page: all
	@set -e; \
	if [ -z "$(CF_DISTRIBUTION_ID)" ]; then \
	  echo "Set CF_DISTRIBUTION_ID or add it to distribution_name." >&2; \
	  exit 1; \
	fi; \
	AWS_PAGER="" aws s3api put-object --bucket "$(S3_BUCKET)" \
	  --key "$(OBJECT_NAME)" --body "$(OBJECT_NAME)" --content-type text/html \
	  --query VersionId --output text; \
	invalidation_id=$$(AWS_PAGER="" aws cloudfront create-invalidation \
	  --distribution-id "$(CF_DISTRIBUTION_ID)" --paths '/' '/$(OBJECT_NAME)' \
	  --query Invalidation.Id --output text); \
	echo "CloudFront invalidation $$invalidation_id"; \
	aws cloudfront wait invalidation-completed \
	  --distribution-id "$(CF_DISTRIBUTION_ID)" --id "$$invalidation_id"

server: $(EXPORTED_DOCS)
	python3 -m http.server
