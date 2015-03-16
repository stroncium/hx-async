import haxe.macro.Expr;
import async.Async;
import haxe.PosInfos;
import haxe.CallStack;

class Test implements async.Build{
  @async static function test1(){
    trace(' === TEST 1 === basic');
    @await Async.block({ [] = delay(100); })(); // creepy, I know, just a test
    [var a:String, var b:String] = asyncGet2('string', 'another string');
    var c = @await asyncGet(null);
    trace('got $a, $b and $c');
  }

  @async @asyncDump static function test2(){
    trace(' === TEST 2 === while');
    var i = 3;
    while(i --> 0) @await delay(10);

    var i = 3;
    do{ @await delay(10); } while (i --> 0);
  }

  @async static function test3():Map<String, String>{
    trace(' === TEST 3 === direct assign');
    var a = [null, null];
    [a[0]] = asyncGet('string'); //direct assign
    [a[1]] = asyncGet('string'); //direct assign
    trace('array: $a');
    return new Map<String, String>();
  }

  @async static function test4(){
    trace(' === TEST 4 === throw-catch');
    try{
      syncThrow(); // synchronous as hell
    }
    catch(e:String){
      trace('got error: $e');
      trace('thinking...');
      @await delay(100);
      trace('realized we dont care about this error');
    }
    //other errors would have gone to callback
  }

  @async static function test5(){
    trace(' === TEST 5 === complex throw-catch');
    try{
      @await throwAsyncErrorIfTrue(false, 'error 1');
      @await throwAsyncErrorIfTrue(true, 'error 2');
    }
    catch(e:String){
      trace('error: $e');
      if(e == 'error 2') trace('just as we expected');
      #if async_stack
        trace('async error: '+Async.getError());
      #end
    }
  }

  @async @asyncDump static function test6(){
    trace(' === TEST 6 === parallel');
    [
      [var v1] = asyncGet('string'),
      [var v2] = {
        var v = @await asyncGet('string');
        [] = delay(200);
        return 'another '+v;
      },
      [] = delay(100),
    ];
    trace('we have $v1 and $v2, at least 100 ms passed');
  }

  @async static function test7(){
    trace(' === TEST 7 === for+switch');
    for(i in 0...10){
      trace('it\'s '+i);
      switch(i){
        case 2:
          trace('2 always takes longer');
          @await delay(100);
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
    trace(' === TEST 8 === return many');
    [var num, var str] = Async.block({
      if(Math.random() < 2){
        return many(222, 'another string');
      }
      return many(111, 'string');
    })();
    trace('we got $num and $str');
  }

  @async static function test9(){
    trace(' === TEST 9 === if+return');
    var t = true, f = false;
    if(f){
      trace('shouldn\'t happen');
      return;
    }
    if(t){
      trace('should happen');
      return;
    }
    else{
      trace('shouldn\'t happen');
      return;
    }
  }

  @async static function test10(){
    trace(' === TEST 10 === try-catch+return many');
    try{
      throw 'lol';
    }
    catch(e:String){
      return many(2,1);
    }
    catch(e:Dynamic){
      return many(1,2);
    }
  }

  @async static function testsFinished(){
    trace(' === TESTS FINISHED === ');
  }

  @async static function asynchronous(int:Int, string:String){
    @await test1();
    @await test2();
    _ = @await test3();
    @await test4();
    @await test5();
    @await test6();
    @await test7();
    @await test8();
    @await test9();
    [_,_] = @await test10();
    @await testsFinished();
  }


  @:async((ret:T)) static function asyncGet<T>(val:T){
    return val;
  }


  @async static function throwAsyncErrorIfTrue(bool, err:Dynamic){
    // #if async_stack
    //   if(bool) throw new async.AsyncError(err);
    // #else
      if(bool) throw err;
    // #end
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
        trace('TEST ERROR: '+err);
      }
    });
  }

  static inline function platformDelay(ms:Int, fun){
    #if (cpp || neko || php) fun(); #else haxe.Timer.delay(fun, ms); #end
  }
}
