default: all

SRC = $(shell find .. -name "*-loop.txt" -type f -maxdepth 1 | sort)
JSON = $(SRC:../%.txt=../%.json)
LOOKUP = $(SRC:../%.txt=../%.lookup.json)
SIMPLE = $(SRC:../%.txt=../%.simple.txt)
COMPACT = $(SRC:../%.txt=../%.compact.txt)

../glossary.json: ../glossary.txt node_modules
	node node_modules/livescript/bin/lsc parse-glossary.ls $< > $@

../%.json: ../%.txt node_modules
	node node_modules/livescript/bin/lsc txt-to-json.ls $< > $@

../%.simple.txt: ../%.txt node_modules
	node node_modules/livescript/bin/lsc txt-to-simple.ls $< > $@

../%.compact.txt: ../%.txt node_modules
	node node_modules/livescript/bin/lsc txt-to-compact.ls $< > $@

../%.lookup.json: ../%.json ../glossary.json
	node node_modules/livescript/bin/lsc create-lookups.ls $< ../glossary.json > $@

node_modules:
	npm install

all: node_modules ../glossary.json ../glossary.lookup.json $(JSON) $(LOOKUP) $(SIMPLE) $(COMPACT)

clean:
	rm -f ../*.json
	rm -f ../*.simple.txt
	rm -f ../*.compact.txt

