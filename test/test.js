var Std = function() { }
Std.__name__ = true;
Std.string = function(s) {
	return js.Boot.__string_rec(s,"");
}
var async = async || {}
async.Build = function() { }
async.Build.__name__ = true;
var Test = function() { }
Test.__name__ = true;
Test.__interfaces__ = [async.Build];
Test.goAsync = function(cb) {
	var c;
	var a = null, b = null;
	var parallelCounter = 3;
	var afterParallel = function(e) {
		if(e == null) {
			if(--parallelCounter == 0) {
				console.log("a+b == " + a + b);
				cb(null);
			}
		} else {
			parallelCounter = -1;
			cb(e);
		}
	};
	Test.delayGet(500,"a",function(e,_a) {
		a = _a;
		afterParallel(e);
	});
	Test.doError(false,afterParallel);
	Test.delayGet(1500,"b",function(e,_b) {
		b = _b;
		afterParallel(e);
	});
}
Test.doError = function(need,cb) {
	var _need = need;
	cb(_need?"planned error":null);
}
Test.delayGet = function(ms,val,cb) {
	haxe.Timer.delay(function() {
		console.log(ms + " passed, returning " + Std.string(val));
		cb(null,val);
	},ms);
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
haxe.Timer.__name__ = true;
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
var js = js || {}
js.Boot = function() { }
js.Boot.__name__ = true;
js.Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	var _g = t;
	switch(_g) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str = o[0] + "(";
				s += "\t";
				var _g2 = 2, _g1 = o.length;
				while(_g2 < _g1) {
					var i = _g2++;
					if(i != 2) str += "," + js.Boot.__string_rec(o[i],s); else str += js.Boot.__string_rec(o[i],s);
				}
				return str + ")";
			}
			var l = o.length;
			var i;
			var str = "[";
			s += "\t";
			var _g1 = 0;
			while(_g1 < l) {
				var i1 = _g1++;
				str += (i1 > 0?",":"") + js.Boot.__string_rec(o[i1],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString) {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) { ;
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) str += ", \n";
		str += s + k + " : " + js.Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
}
String.__name__ = true;
Array.__name__ = true;
var Int = { __name__ : ["Int"]};
var Bool = Boolean;
Bool.__ename__ = ["Bool"];
var Void = { __ename__ : ["Void"]};
Test.main();
