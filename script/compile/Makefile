default: all

SRC = $(shell find .. -name "*.txt" -type f -maxdepth 1 | sort)
JSON = $(SRC:../%.txt=../%.json)
LOOKUP = $(SRC:../%.txt=../%.lookup.json)

../glossary.json: ../glossary.txt node_modules
	node node_modules/livescript/bin/lsc parse-glossary.ls $< > $@

../%.json: ../%.txt node_modules
	node node_modules/livescript/bin/lsc txt-to-json.ls $< > $@

../%.lookup.json: ../%.json ../glossary.json
	node node_modules/livescript/bin/lsc create-lookups.ls $< ../glossary.json > $@

node_modules:
	npm install

all: node_modules $(JSON) $(LOOKUP)

clean:
	rm -f ../*.json

