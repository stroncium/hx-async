import haxe.macro.Expr;
import async.Async;

class Test implements async.Build{

  @async
  static function asynchronous(int:Int, string:String, MARKER_cb){
    async(Async.block({
      async(delay(100));
    })());

    var i = 3;
    while(i --> 0) async(delay(10));

    var result = [null, null];
    async([result[0]] < asyncGet(string)); //direct assign
    async([result[1]] < asyncGet(string)); //direct assign
    trace('array: '+result);

    async(a, b < asyncGet2(string, string));
    trace('got '+a+' and '+b);
    try{
      syncThrow(); // synchronous as hell
    }
    catch(e:String){
      trace('got error: '+e);
      trace('thinking...');
      async(delay(100));
      trace('realized we dont care about this error');
    }
    //other errors would have gone to callback

    try{
      async(throwAsyncErrorIfTrue(false, 'error 1'));
      async(throwAsyncErrorIfTrue(true, 'error 2'));
    }
    catch(e:String){
      trace('error, just as we expected: '+e);
    }

    parallel( // direct assigns in parallel are not supported yet
      v1 = asyncGet(string),
      v2 < {
        async(v = asyncGet(string));
        async(delay(200));
        return 'another '+v;
      },
      delay(100)
    );
    trace('we have '+v1+' and '+v2+', at least 100 ms passed');

    for(i in 0...10){
      trace('it\'s '+i);
      switch(i){
        case 2:
          trace('2 always takes longer');
          async(delay(100));
        case 3:
          trace('don\'t like number 3');
          continue;
        case 4:
          trace('4 is enough');
          break;
      }
      trace('done with '+i);
    }
    if(result[0] == string){ //which is always true in our case
      return many(222, 'another string');
    }
    return many(111, 'string');
  }

  @async
  static function asyncGet<T>(val:T, cb){
    return val;
  }

  //freely integrates with normal asynchronous functions
  static function asyncGet2<T1, T2>(v1:T1, v2:T2, cb){
    cb(null, v1, v2);
  }

  @async
  static function throwAsyncErrorIfTrue(bool, err, cb){
    if(bool) throw err;
  }

  static function syncThrow(){
    trace('random calculations throw exception');
    throw 'too hard to calculate';
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
    asynchronous(10, 'string', function(err, v1:Int, v2:String){
      if(err != null){
        trace('Error: '+err);
      }
      else{
        trace('finished: '+v1+', '+v2);
      }
    });
    //~ asynchronous(function(err){
      //~ if(err != null){
        //~ trace('Error: '+err);
      //~ }
      //~ else{
        //~ trace(' == finished');
      //~ }
    //~ });
  }

  static inline function platformDelay(ms:Int, fun){
    #if cpp
      fun();
    #else
      haxe.Timer.delay(fun, ms);
    #end
  }
}
