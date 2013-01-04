package:
	zip -r async.zip async/ haxelib.xml

submit: package
	haxelib submit async.zip

test: package
	sudo haxelib test async.zip
