MAKEFLAGS := --no-builtin-rules --no-builtin-variables
.PHONY: all host clean
.INTERMEDIATE: index.md

# https://stackoverflow.com/a/37483527
_pos = $(if $(findstring $1,$2),$(call _pos,$1,\
       $(wordlist 2,$(words $2),$2),x $3),$3)
pos = $(words $(call _pos,$1,$2))
prev = $(subst _empty,,$(word $(call pos,$1,$2),_empty $2))
next = $(word $(call pos,$1,$2),$(filter-out $1,$2))

# https://stackoverflow.com/a/14260762
reverse = $(if $(wordlist 2,2,$(1)),$(call reverse,$(wordlist 2,$(words $(1)),$(1))) $(firstword $(1)),$(1))

get_title = $(shell grep -iPo '(?<=^title: )(.*)' $1)

GEN:=pandoc \
-s --template=template.html

PAGES:=$(foreach page,$(sort $(shell find pages -type f)),$(basename $(notdir $(page))))
POSTS:=$(foreach post,$(sort $(shell find posts -type f)),$(basename $(notdir $(post))))

all: _site/index.html $(foreach page,$(PAGES) $(POSTS),_site/$(page).html)

index.md: index_partial.md
	cp $< $@
	printf "\n$(foreach post,$(call reverse,$(POSTS)),\n * [$(call get_title,posts/$(post).md)]($(post).html))" >>$@

_site/index.html: index.md template.html
	$(GEN) $< -o $@

_site/%.html: pages/%.* template.html
	$(GEN) $< -o $@

_site/%.html: posts/%.* template.html
	$(eval PREV:=$(strip $(call prev,$(basename $(notdir $@)),$(POSTS))))
	$(eval PREV_TITLE:=$(if $(PREV),$(call get_title,posts/$(PREV).md),))
	$(eval NEXT:=$(strip $(call next,$(basename $(notdir $@)),$(POSTS))))
	$(eval NEXT_TITLE:=$(if $(NEXT),$(call get_title,posts/$(NEXT).md),))
	$(GEN) $< -o $@ \
	$(if $(PREV),-V prev=$(PREV).html -V prev_title="$(PREV_TITLE)") \
	$(if $(NEXT),-V next=$(NEXT).html -V next_title="$(NEXT_TITLE)") \
	-V author="Casey Fitzpatrick"

# Host a quick and dirty server to test the site
host:
	python3 -m http.server 5000 -d _site/

clean:
	rm -f index.md
	rm -f _site/*.html
