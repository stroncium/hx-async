package: async.zip
async.zip: async/* haxelib.json
	zip -r async.zip async/ haxelib.json LICENSE.txt

submit: package
	haxelib submit async.zip

test: package
	haxelib local async.zip
