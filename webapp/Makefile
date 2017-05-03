default: build

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)
ASSETS_SRC = $(shell find src/assets -type f | sort)
ASSETS_LIB = $(ASSETS_SRC:src/assets/%=lib/assets/%)

lib:
	mkdir lib/

lib/%.js: src/%.ls lib node_modules
	node node_modules/livescript/bin/lsc --output "$(@D)" --compile "$<"

lib/apollo13rt.js: lib/app.js
	node node_modules/browserify/bin/cmd.js -e $< -o $@ --im

lib/index.html: src/index.html lib
	cp src/index.html lib/

lib/styles.css: src/styles.sass lib
	node node_modules/node-sass/bin/node-sass --output-style compressed $< > $@

lib/assets: lib
	@mkdir -p lib/assets

lib/assets/%: src/assets/% lib/assets
	@[[ -d "$(@D)" ]] || mkdir -p "$(@D)"
	cp $< $@

lib/assets/flight-director-loop.json: ../script/flight-director-loop.json
	cp $< $@

node_modules:
	npm install

build: $(LIB) lib/index.html lib/styles.css lib/apollo13rt.js $(ASSETS_LIB) lib/assets/flight-director-loop.json

clean:
	rm -rf lib

