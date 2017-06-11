default: build

JS_SRC = $(shell find src -name "*.ls" -type f | sort)
JS_LIB = $(JS_SRC:src/%.ls=lib/%.js)
ASSETS_SRC = $(shell find src/assets -name '*.ai' -prune -o -type f -print | sort)
ASSETS_LIB = $(ASSETS_SRC:src/assets/%=lib/assets/%)
JSON_SRC = $(shell find ../script -name '*.json' -maxdepth 1 -type f | sort)
JSON_LIB = $(JSON_SRC:../script/%=lib/assets/%)
ARTICLES_SRC = $(shell find src/articles -name '*.html' -o -name '*.md' -maxdepth 1 -type f | sort)
ARTICLES_LIB = $(ARTICLES_SRC:src/articles/%=lib/articles/%.part)

lib:
	mkdir lib/

lib/%.js: src/%.ls lib node_modules
	node node_modules/livescript/bin/lsc --output "$(@D)" --compile "$<"

lib/apollo13rt.js: lib/app.js
	node node_modules/browserify/bin/cmd.js -e $< -o $@ --im

lib/articles: lib
	@mkdir -p lib/articles

lib/articles/%.md.part: src/articles/%.md lib/articles
	cat $< | node node_modules/marked/bin/marked | awk 'BEGIN{ print "<div class=\"article\" id=\"$(shell basename $(basename $<))\">" } END{ print "</div>" } 1' > $@

lib/articles/%.html.part: src/articles/%.html lib/articles
	cp $< $@

lib/index.html: src/index.html lib $(ARTICLES_LIB)
	find lib/articles -name '*.part' -type f | xargs cat | awk 'BEGIN{ RS = "\f"; getline c < "-"; RS="\n" } /###/{ print c } 1' $< > $@

lib/styles.css: src/styles.sass src/styles/*.sass lib
	node node_modules/node-sass/bin/node-sass --output-style compressed $< > $@

lib/assets: lib
	@mkdir -p lib/assets

lib/assets/%: src/assets/% lib/assets
	@[[ -d "$(@D)" ]] || mkdir -p "$(@D)"
	cp $< $@

lib/assets/%.json: ../script/%.json
	cp $< $@

node_modules:
	npm install

build: $(JS_LIB) lib/apollo13rt.js lib/styles.css $(ASSETS_LIB) $(JSON_LIB) lib/index.html
quick: lib/index.html lib/styles.css $(ASSETS_LIB)

clean:
	rm -rf lib/

