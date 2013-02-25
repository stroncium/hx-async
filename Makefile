package:
	zip -r async.zip async/ haxelib.xml LICENSE.txt

submit: package
	haxelib submit async.zip

test: package
	haxelib local async.zip
