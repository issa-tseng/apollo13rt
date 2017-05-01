default: all

SRC = $(shell find .. -name "*.txt" -type f -maxdepth 1 | sort)
JSON = $(SRC:../%.txt=../%.json)

../%.json: ../%.txt node_modules
	node node_modules/livescript/bin/lsc txt-to-json.ls $< > $@

node_modules:
	npm install

all: node_modules $(JSON)

clean:
	rm -f ../*.json

