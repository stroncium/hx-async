# async - Asynchronous programming in HaXe made easy.

## Beta version

The aim of the project is to use the power of HaXe macro system to make complex asynchronous operations easier to write and read.

We get seemingly synchronous code with special markings and convert it to asynchronous code. Synchronous code uses standard callback system like in node.js(and is interoperable with it, and other asynchronous functions written in this style).

## Example (look at `/test/Test.hx` for more)

  Class should implement `async.Build`, compiling should be done with `-lib async`.

  In the first function we think of everything like it is synchronous, but most parts are not.
  Later functions are just for the sake of completeness.

``` haxe
class Test implements async.Build{
  @async(var int:Int, string:String, dyn:Dynamic) static function foo(){
    //returned types are optional
    return many(222, 'string', null);
  }

  @async() delay(ms:Int){
    //use empty brackets for functions which return nothing(or error)
    //...
    return;
  }

  @async static function bar(){
    //when there
    var b;
    [var a:Int, b, _] = foo(); //getting multiple values
    [] = delay(100); //just waiting for callback
    trace(a);
    [
      [var c, var d] = foo(),
      delay(200),
    ]; // this will be ran in parallel
    trace(c, d);
  }
}
```

## Features / Done

  + Every class implementing `async.Build` interface will be automatically processed.
  + Every function of such class with `@async` meta will be converted.

  Use `@async(var foo:Foo, bar, bas:Bas)` to explicitly type callback.

  + write `[<returns>] = call(<args>)` to call asynchronous function

  `[a, var b, var c:Int] = call(1, 2, 3); <other code>` is converted to something like
``` js
call(1, 2, 3, function(err, _a, b, c:Int){
  if(err == null){
    a = _a;
    <other code>
  }
  else{ cb(err, null); }
});
```
  + if you put a couple of such calls into array, it will be executed in parallel
``` haxe
[
  [var a] = getA(),
  [var b] = getB(),
];
```
  + `for(<cond>){<code>}`, `if(<cond>){<code>}`, `if(<cond>){<code>}else{<code>}`, `do{<code>}while(<cond>)`, `while(<cond>){<code>}`, `switch(...){case ...: <code>}`

  will be converted to just what you expect, but you may put asynchronous calls only into `<code>` blocks, not into `<cond>` blocks, `continue` and `break` inside loops will work.

    - `throw` will be transformed to callback with error
    - `return` will be converted to callback with value
    - `return many(...)` will be converted to callback with multiple values

    - `try{<trycode>}catch(...){<code>}` will be converted.

  If there are asynchronous calls inside, it will catch asynchronous errors but not synchronous, but if there are only synchronous calls, synchronous errors will be caught.

  + **Mission control**: if there is no return in your code - it will be implicitly added.

    All in all, there is no way `@async` function will never call it's callback or call it more than one time if:
      - all the asynchronous function it uses always call their callbacks, do it only once and never *throw* (synchronous) errors.
      - there is no implicit calls to callback

  + Other

    Use `-D async_readable` compilation flag to make async code more readable.

  Function can be implicitly converted by passing is to `async.Async.it()` macro.

  Block of code can be converted to anonymous function of type `(Dynamic->Void)->Void` by using `async.Async.block()` macro.

## TODOs
  + We can allow optional arguments by setting callback as first argument(it isn't usable in pure code, but we dont care about this in generated code).
  + Source mapping may be a bit broken in some cases.
  + We can introduce a mode which will enrich errors with stacktrace-like information.
  + Some code can be simplified, amount of calls reduced (functions which just check error and call next function which will also check for same errors).

