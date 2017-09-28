default: build

JS_SRC = $(shell find src -name "*.ls" -type f | sort)
JS_LIB = $(JS_SRC:src/%.ls=lib/%.js)
ASSETS_SRC = $(shell find src/assets -name '*.ai' -prune -o -type f -print | sort)
ASSETS_LIB = $(ASSETS_SRC:src/assets/%=lib/assets/%)
SCRIPT_SRC = $(shell find ../script -name '*.json' -maxdepth 1 -type f | sort)
SCRIPT_LIB = $(SCRIPT_SRC:../script/%=lib/assets/%)
EXHIBITS_SRC = $(shell find ../exhibits -name '*.html' -o -name '*.md' -maxdepth 1 -type f | sort)
EXHIBITS_LIB = $(EXHIBITS_SRC:../exhibits/%=lib/content/%.part)
EXHIBITS_JSON_SRC = $(shell find ../exhibits -name '*.json' | sort)
EXHIBITS_JSON_LIB = $(EXHIBITS_STATIC_SRC:../exhibits/%=lib/content/%)
LINES_SRC = $(shell find ../script -name '*loop.json' -maxdepth 1 -type f | sort)
LINES_LIB = $(LINES_SRC:../script/%=lib/content/%.part)

lib:
	mkdir lib/

lib/%.js: src/%.ls lib node_modules
	node node_modules/livescript/bin/lsc --output "$(@D)" --compile "$<"

lib/apollo13rt.js: lib/app.js
	node node_modules/browserify/bin/cmd.js --exclude domino -e $< -o $@ --im

lib/apollo13rt.min.js: lib/apollo13rt.js
	node node_modules/uglify-js/bin/uglifyjs "$<" -o $@

lib/content: lib
	@mkdir -p lib/content

lib/content/%.json: ../exhibits/%.json lib/content
	cp $< $@

lib/content/%.md.part: ../exhibits/%.md lib/content
	cat $< | node node_modules/marked/bin/marked | awk 'BEGIN{ print "<div class=\"article\" id=\"$(shell basename $(basename $<))\">" } END{ print "</div>" } 1' > $@

lib/content/%.html.part: ../exhibits/%.html lib/content
	cp $< $@

lib/content/%.json.part: ../script/%.json lib/content
	node node_modules/livescript/bin/lsc build/script.ls $< > $@

lib/index.html: src/index.html lib $(EXHIBITS_LIB) $(EXHIBITS_JSON_LIB) $(LINES_LIB)
	find lib/content -name '*.part' -type f | xargs cat | awk 'BEGIN{ RS = "\f"; getline c < "-"; RS="\n" } /###/{ print c } 1' $< > $@

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

build: $(JS_LIB) lib/apollo13rt.js lib/styles.css $(ASSETS_LIB) $(SCRIPT_LIB) lib/index.html

production: build lib/apollo13rt.min.js

clean:
	rm -rf lib/

