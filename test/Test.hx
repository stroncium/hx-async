import haxe.macro.Expr;
import async.Async;

class Test implements async.Build{

  @:async(None) static function test1(){
    trace(' === TEST 1 === ');
    as(Async.block({
      as(delay(100));
    })());
    var a;
    as(!a, b = asyncGet2('string', 'another string'));
    as(c = asyncGet(null));
    trace('got $a, $b and $c');
  }

  @async static function test2(){
    trace(' === TEST 2 === ');
    var i = 3;
    while(i --> 0) as(delay(10));
  }

  @async(var a:haxe.ds.StringMap<String>)
  //~ @async
  static function test3(){
    trace(' === TEST 3 === ');
    var a = [null, null];
    as([
      !a[0] = asyncGet('string'), //direct assign
      !a[1] = asyncGet('string'), //direct assign
    ]);
    trace('array: $a');
    return new haxe.ds.StringMap();
  }

  @async static function test4(){
    trace(' === TEST 4 === ');
    try{
      syncThrow(); // synchronous as hell
    }
    catch(e:String){
      trace('got error: $e');
      trace('thinking...');
      as(delay(100));
      trace('realized we dont care about this error');
    }
    //other errors would have gone to callback
  }

  @:async static function test5(){
    trace(' === TEST 5 === ');
    try{
      as(throwAsyncErrorIfTrue(false, 'error 1'));
      as(throwAsyncErrorIfTrue(true, 'error 2'));
    }
    catch(e:String){
      trace('error, just as we expected: $e');
    }
  }

  @async static function test6(){
    trace(' === TEST 6 === ');
    parallel([ // direct assigns in parallel are not supported yet
      v1 = asyncGet('string'),
      v2 = {
        as(v = asyncGet('string'));
        as(delay(200));
        return 'another '+v;
      },
      delay(100),
    ]);
    trace('we have $v1 and $v2, at least 100 ms passed');
  }

  @async static function test7(){
    trace(' === TEST 7 === ');
    for(i in 0...10){
      trace('it\'s '+i);
      switch(i){
        case 2:
          trace('2 always takes longer');
          as(delay(100));
        case 3:
          trace('don\'t like number 3');
          continue;
        case 4:
          trace('4 is enough');
          break;
      }
      trace('done with $i');
    }
  }

  @async static function test8(){
    trace(' === TEST 8 === ');
    async(num, str = Async.block({
      if(Math.random() < 2){
        return many(222, 'another string');
      }
      return many(111, 'string');
    })());
    trace('we got $num and $str');
  }

  @async static function testsFinished(){
    trace(' === TESTS FINISHED === ');
  }

  @async static function asynchronous(int:Int, string:String){
    async([
      test1(),
      test2(),
      _ = test3(),
      test4(),
      test5(),
      test6(),
      test7(),
      test8(),
      testsFinished(),
    ]);
  }


  @async(var ret:T) static function asyncGet<T>(val:T){
    return val;
  }


  @async static function throwAsyncErrorIfTrue(bool, err){
    if(bool) throw err;
  }

  //freely integrates with normal asynchronous functions
  static function asyncGet2<T1, T2>(v1:T1, v2:T2, cb){
    cb(null, v1, v2);
  }

  static function syncThrow(){
    trace('random calculations throw exception');
    throw 'too hard to calculate';
  }

  static inline function delay(ms:Int, cb){
    platformDelay(ms, function(){ trace(ms+' passed'); cb(null); });
  }

  static inline function delayGet(ms:Int, val:Dynamic, cb){
    platformDelay(ms, function(){ trace(ms+' passed, returning '+val); cb(null, val); });
  }

  public static function main(){
    asynchronous(10, 'string', function(err){
      if(err != null){
        trace('Error: '+err);
      }
    });
  }

  static inline function platformDelay(ms:Int, fun){
    #if cpp fun(); #else haxe.Timer.delay(fun, ms); #end
  }
}
