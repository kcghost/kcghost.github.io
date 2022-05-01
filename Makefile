.PHONY: build host clean install_deps

build:
	bundle exec jekyll build

host:
	bundle exec jekyll serve --host 0.0.0.0 --port 5000

clean:
	bundle exec jekyll clean

install_deps:
	echo "Install ruby if you don't have it already"
	gem install bundler jekyll
	echo "If this step fails try removing Gemfile.lock and try again"
	bundle install

