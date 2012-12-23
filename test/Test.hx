import haxe.macro.Expr;
class Test implements async.Build{

  static var async:Dynamic;
  @async
  static function goAsync(cb){
    for(a in 0...3){
      trace('hop '+a);
      async(delay(100));
      if(Math.random() > 0.5) break;
    }
    trace('good');
  }

  static inline function log(txt:String){
    trace(txt);
  }

  static inline function doError(need, cb){
    var _need = need;
    cb(_need ? 'planned error' : null);
  }
  static inline function delay(ms:Int, cb){
    platformDelay(ms, function(){
      log(ms+' passed');
      cb(null);
    });
  }
  static inline function delayGet(ms:Int, val:Dynamic, cb){
    platformDelay(ms, function(){
      log(ms+' passed, returning '+val);
      cb(null, val);
    });
  }

  public static function main(){
    //~ try { throw null; }
    //~ catch(e:Int){}
    //~ catch(e:Float){}
    goAsync(function(err){
      if(err != null){
        trace('Error: '+err);
      }
    });
  }

  static inline function platformDelay(ms:Int, fun){
    #if cpp
      fun();
    #else
      haxe.Timer.delay(fun, ms);
    #end
  }
}
