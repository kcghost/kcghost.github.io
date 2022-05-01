.PHONY: install host

install:
	echo "Install ruby if you don't have it already"
	gem install bundler jekyll
	echo "If this step fails try removing Gemfile.lock and try again"
	bundle install

host:
	bundle exec jekyll serve
