import haxe.macro.Expr;

class Test implements async.Build{
//~
  @async
  static function asynchronous(cb){
    async(delay(10));
    async(delay(10));
    async(delay(10));
    async(delay(10));
//~
    var i = 3;
    while(i --> 0){
      async(delay(10));
      trace('hop');
      if(Math.random() > 0.5) break;
      else continue;
      trace('ololo');
    }
//~
    for(v in 0...4){
      try{
        switch(v){
          case 0:
            async(delay(10));
          case 1:
            trace('lol');
          case 2:
            throw 'ooops';
          default:
            return;
        }
      }catch(e:String){trace(e);}
      trace('ahah');
    }
//~ //~
    try{
      try{
        async(delay(10));
        throw 'error';
      }
      catch(e:String){
        trace(e);
        throw e;
      }
    }
    catch(e:String){
      trace('this exception doesn\'t dissolve');
    }
//~ //~
    parallel(
      a <= delayGet(10, 1),
      b <= delayGet(10, 2)
    );
    trace(a+b);
  }

  static inline function log(txt:String){
    trace(txt);
  }

  static inline function doError(need, cb){
    var _need = need;
    cb(_need ? 'planned error' : null);
  }
  static inline function delay(ms:Int, cb){
    platformDelay(ms, function(){ log(ms+' passed'); cb(null); });
  }
  static inline function delayGet(ms:Int, val:Dynamic, cb){
    platformDelay(ms, function(){ log(ms+' passed, returning '+val); cb(null, val); });
  }

  public static function main(){
    //~ asynchronous(10, 'string', function(err, v1:Int, v2:String){
      //~ if(err != null){
        //~ trace('Error: '+err);
      //~ }
      //~ else{
        //~ trace('finished: '+v1+', '+v2);
      //~ }
    //~ });
    asynchronous(function(err){
      if(err != null){
        trace('Error: '+err);
      }
      else{
        trace(' == finished');
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
