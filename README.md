# async - Asynchronous programming in HaXe made easy.


## Beta version.
The aim of the project is to use the power of HaXe macro system to make complex asynchronous operations easier to write and read.

The main concept is to look at seemingly synchronous code with special markings and convert it to asynchronous code with the same overall flow as we seen in synchronous code (in compile time).

The basis for asynchronous processing is standard callback system, as the one used in node.js where first argument of callback is null or error in case the error was encountered during execution.

One useful feature is total interoperability with asynchronous functions written in normal way, the only thing required from such functions is accepting callback as last argument and returning null/error as first callback argument.

However, there is a simple way to also use functions which call their callbacks with arbitrary arguments, but there may be a need in custom processing of this arguments(which is inevitable).


The library isn't currently released on haxelib.


## Features / Done

  + Converting is rebuilding seemingly synchronous code to asynchronous.

  + Every class implementing **async.Build** interface will be automatically processed, which means every function of such class with **@async** metadata will be converted.

  + Function can be implicitly converted by passing is to **async.Async.it()** macro.

  + Along the code convertion, the following will be processed and converted to asynchronous:
    - **async(<comma-separated list of calls>)** - the main construct

      Each call have form of
        `<comma-separated list of identifiers> <= <function>(<arguments without callback>))`
        or
        `<function>(<arguments without callback>)` for functions which return pass only null/error to it's callback.

      Stripping the code related to handling errors,

      `async(getA(1, 2, 3)); /*some code*/` will be converted to (something like) `getA(1, 2, 3, function(error){ /*some code*/ })`.

      `async(a <= getA()); /*some code*/` will be converted to (something like) `getA(function(error, a){ /*some code*/ })`.

      `async(a <= getA(), getB)()); /*some code*/` will be converted to (something like) `getA(function(error, a){ getB(function(error){/*some code*/ }); };`.

      Any error got from asynchronous functions called will be passed to main function callback.

    - **parallel(<comma-separated list of calls>)** - construct to handle parallel execution

        Calls have the same form as calls passed to async(...) but are executed in parallel.

        First error returned from any of calls will be passed to higher level.

        Calls can't use variable named the same of any variable parallel(...) construct will pass results to unless in deeper scopes.
        That means `var a = 123; parallel(a <= getA(a));` will result in error which won't be detected.

    - **asyncr(<arguments>)** calls - are treated the same way as **async** calls, but callback arguments are used as is.

    - **do** and **while** loops

      The condition should be fully synchronous(in it's context)
      The expression is processed the same way as whole function.
      If expression doesn't contain any parts which need conversion, the code is left as is.

      **continue** and **break** expressions will be processed and exactly what you expect them to do.

    - **if** conditions

      The condition should be fully synchronous(in it's context).
      The expression is processed the same way as whole function.
      If expression doesn't contain any parts which need conversion, the code is left as is.

    - **throw** - is replaced by calling function callback with error.

    - **return** - is replaced by calling function callback with null and proper arguments.
      To return single value(except null for error) the normal *return value;* construction is used.
      To return multiple arguments *return many(value1, value2);* construction is used.

    - **try{...}catch(...){...}**

      Asynchronous catches not allowed.

      May fail, needs better testing.

  + **Mission control**: if there is no return in your code - it will be implicitly added.

    All in all, there is no way @async function will never call it's callback or call it more than one time if:
      - all the asynchronous function it uses always call their callbacks, do it only once and never *throw* (synchronous) errors.
      - there is no implicit calls to callback

  + **Callback typing**

    One can type his @async function callback and macro will notice it. Sometimes it is even needed: when the function doesn't contain any implicit returns there is no way macro can know how many arguments it should callback with.

## ToDo
  + better coder mistake detection
  + more parallel execution options
  + **for** loops - are not converted currently
  + asynchronous **catch**es
  + code samples should be added to this file
  + handling of asynchronous functions which can to throw (synchronous) errors
  + **switch**es are not converted currently
