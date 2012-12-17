var async = async || {}
async.Build = function() { }
var Test = function() { }
Test.__interfaces__ = [async.Build];
Test.goAsync = function(cb) {
	console.log("here we go");
	haxe.Timer.delay(function() {
		console.log("1000 ms passed");
		cb(null);
	},1000);
}
Test.main = function() {
	Test.goAsync(function(err) {
		if(err != null) console.log("Error: " + err);
	});
}
var haxe = haxe || {}
haxe.Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
haxe.Timer.delay = function(f,time_ms) {
	var t = new haxe.Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
}
haxe.Timer.prototype = {
	run: function() {
	}
	,stop: function() {
		if(this.id == null) return;
		clearInterval(this.id);
		this.id = null;
	}
}
Test.main();
