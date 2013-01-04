# async - Asynchronous programming in HaXe made easy.

## Beta version

The aim of the project is to use the power of HaXe macro system to make complex asynchronous operations easier to write and read.

The main concept is to look at seemingly synchronous code with special markings and convert it to asynchronous code with the same overall flow as we seen in synchronous code (in compile time).

The basis for asynchronous processing is standard callback system, as the one used in node.js where first argument of callback is null or error in case the error was encountered during execution.

One useful feature is total interoperability with asynchronous functions written in normal way, the only thing required from such functions is accepting callback as last argument and returning null/error as first callback argument.

However, there is a simple way to also use functions which call their callbacks with arbitrary arguments, but there may be a need in custom processing of this arguments(which is inevitable).


The library isn't currently released on haxelib.

## Example (same code as in test/)

  Class should implement `async.Build`, compiling should be done with `-lib async`.

  In the first function we think of everything like it is synchronous, but most parts are not.
  Later functions are just for the sake of completeness.

``` haxe
import haxe.macro.Expr;
import async.Async;

class Test implements async.Build{

  @async static function test1(){
    trace(' === TEST 1 === ');
    async(Async.block({
      async(delay(100));
    })());
    async(a, b = asyncGet2('string', 'another string'));
    trace('got '+a+' and '+b);
  }

  @async static function test2(){
    trace(' === TEST 2 === ');
    var i = 3;
    while(i --> 0) async(delay(10));
  }

  @async static function test3(){
    trace(' === TEST 3 === ');
    var result = [null, null];
    async(
      [result[0]] < asyncGet(string), //direct assign
      [result[1]] < asyncGet(string) //direct assign
    );
    trace('array: '+result);
  }

  @async static function test4(){
    trace(' === TEST 4 === ');
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
  }

  @async static function test5(){
    trace(' === TEST 5 === ');
    try{
      async(throwAsyncErrorIfTrue(false, 'error 1'));
      async(throwAsyncErrorIfTrue(true, 'error 2'));
    }
    catch(e:String){
      trace('error, just as we expected: '+e);
    }
  }

  @async static function test6(){
    trace(' === TEST 6 === ');
    parallel( // direct assigns in parallel are not supported yet
      v1 = asyncGet('string'),
      v2 = {
        async(v = asyncGet('string'));
        async(delay(200));
        return 'another '+v;
      },
      delay(100)
    );
    trace('we have '+v1+' and '+v2+', at least 100 ms passed');
  }

  @async static function test7(){
    trace(' === TEST 7 === ');
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
  }

  @async static function test8(){
    trace(' === TEST 8 === ');
    async(num, str = Async.block({
      if(Math.random() < 2){
        return many(222, 'another string');
      }
      return many(111, 'string');
    })());
    trace('we got '+num+' and '+str);
  }

  @async static function testsFinished(){
    trace(' === TESTS FINISHED === ');
  }

  @async static function asynchronous(int:Int, string:String, MARKER_cb){
    async(
      test1(),
      test2(),
      test3(),
      test4(),
      test5(),
      test6(),
      test7(),
      test8(),
      testsFinished()
    );
  }


  @async static function asyncGet<T>(val:T, cb){
    return val;
  }


  @async static function throwAsyncErrorIfTrue(bool, err, cb){
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
```

## Features / Done

  + Converting is rebuilding seemingly synchronous code to asynchronous.

  + Every class implementing `async.Build` interface will be automatically processed, which means every function of such class with **`@async`** metadata will be converted.

  + Function can be implicitly converted by passing is to `async.Async.it()` macro.

  + Block of code can be converted to anonymous function of type `(Dynamic->Void)->Void` by using `async.Async.block()` macro.

  + Along the code convertion, the following will be processed and converted to asynchronous:

    - **`async(<comma-separated list of calls>)`** - the main construct

      Each call have form of
        `<comma-separated list of identifiers> <= <function>(<arguments without callback>))`
        or
        `<function>(<arguments without callback>)` for functions which return pass only null/error to it's callback.

      If assign expression is prefixed with `!`, such expression will be directly assigned, like `!array[index]`..

      Any error got from asynchronous functions called will be passed to main function callback.

      Stripping the code related to handling errors, the code will be converted as follows(actual AST may be different):

      `async(getA(1, 2, 3)); /*some code*/` ⇒ `getA(1, 2, 3, function(error){ /*some code*/ })`

      `async(a <= getA()); /*some code*/` ⇒ `getA(function(error, a){ /*some code*/ })`

      `async(!a[0] <= getA()); /*some code*/` ⇒ `getA(function(error, v1){ a[0] = v1; /*some code*/ })`

      note than you can't use 'v1' to access value, as the identifier is dynamically generated and is just an example.

      `async(a <= getA(), getB)()); /*some code*/` ⇒ `getA(function(error, a){ getB(function(error){/*some code*/ }); };`.

    - **`parallel(<comma-separated list of calls>)`** - construct to handle parallel execution

        Calls have the same form as calls passed to `async(...)` but are executed in parallel.

        ...except you can pass code block instead of function andd it will be converted to `(Dynamic->Void)->Void`

        First error returned from any of calls will be passed to higher level.

        Calls can't use variable named the same of any variable `parallel(...)` construct will pass results to unless in deeper scopes.
        That means `var a = 123; parallel(a <= getA(a));` will result in error which won't be detected.

    - **DISABLED** `asyncr(<arguments>)` calls - are treated the same way as **async** calls, but callback arguments are used as is.

    - **`do{...}while(...); while(...){...}; for(<identifier> in <iterator>){...}`** loops

      The condition should be fully synchronous(in it's context)
      The expression is processed the same way as whole function.
      If expression doesn't contain any parts which need conversion, the code is left as is.

      **continue** and **break** expressions will be processed and do exactly what you expect them to do.

      For for loops the iterator should be explicitly specified ( `v in [1,2,3]` won't do, but `v in [1,2,3].iterator()` will).

    - **`if(...){...}else{...}`** conditions

      The condition should be fully synchronous(in it's context).
      The expression is processed the same way as whole function.
      If expression doesn't contain any parts which need conversion, the code is left as is.

    - **`throw`** is replaced by calling function callback with error.

    - **`return; return val; return many(val1, val2, ...)`**
      will be replaced by calling function callback with null and proper arguments.

      `return many(value1, value2);` is used to return multiple values.

    - **`try{...}catch(...){...}`** are converted.

      If there is no asynchronous constructions inside try expression(throw doesnt count as async construction for that case)
      the expression will be left synchronous, which allows to use functions throwing synchronous exceptions,
      however catch expressions will be always converted to asynchronous (for the sake of simplifying flow management, later it may be optimized).

  + **`switch{...}`** constructions are converted.

  + **Mission control**: if there is no return in your code - it will be implicitly added.

    All in all, there is no way `@async` function will never call it's callback or call it more than one time if:
      - all the asynchronous function it uses always call their callbacks, do it only once and never *throw* (synchronous) errors.
      - there is no implicit calls to callback

  + **Callback typing**

    One can type his @async function callback and macro will notice it.
    Sometimes it is even needed: when the function doesn't contain any implicit returns there is no way macro can know how many arguments it should callback with.
    However, if function takes no arguments, untyped callback argument will be added. (As I found myself forgetting to add it sometimes.)

  + Other

    Use `-D async_readable` compilation flag to make async code more readable.


## ToDo
  + parallel(...) should support direct assigns, just as async(...)
  + testing, testing, testing (unit?)

## Further improvements
  + check source code mapping, it may be broken in some cases
  + enriching errors with stacktrace-like information
  + some code can be simplified, amount of calls reduced (functions which just check error and call next function which will also check for same errors)
