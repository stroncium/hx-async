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

  + Every class implementing **async.Build** interface will be automatically processed.
    Which means every function of such class with **@async** metadata will be converted.

  + Function can be implicitly converted by passing is to **async.Async.it()** macro.

  + Along the code convertion, the following will be processed and converted to asynchronous:
    - **async(<arguments>)** calls - the main construct

      There are 2 forms of async call currently:
        + `async(someFunction(<arg list>))`

          is used for calling asynchronous functions which pass only null/error to it's callback.

          Stripping the details, `async(getA(1, 2, 3)); /*some code*/` will be converted to (something like) `getA(1, 2, 3, function(error){ /*some code*/ })`.

        + `async(<id list> <= someFunction(<arg list>))`

          is used for calling asynchronous functions which pass some other info to callback

          Stripping the details, `async(a <= getA()); /*some code*/` will be converted to (something like) `getA(function(error, a){ /*some code*/ })`.

      Any error got from asynchronous functions called will be passed to main function callback.

    - **asyncr(<arguments>)** calls - are treated the same way as **async** calls, but callback arguments are used as is.

    - **do** and **while** loops

      The condition should be fully synchronous(in it's context)
      The expression is processed the same way as whole function.
      If expression doesn't contain any parts which need conversion, the code is left as is.

    - **if** conditions

      The condition should be fully synchronous(in it's context).
      The expression is processed the same way as whole function.
      If expression doesn't contain any parts which need conversion, the code is left as is.

    - **throw** - is replaced by calling function callback with error.

    - **return** - is replaced by calling function callback with null and proper arguments.
      To return single value(except null for error) the normal *return value;* construction is used.
      To return multiple arguments *return many(value1, value2);* construction is used.

  + **Mission control**: if there is no return in your code - it will be implicitly added.

    All in all, there is no way @async function will never call it's callback or call it more than one time if:
      - all the asynchronous function it uses always call their callbacks and do it only once
      - there is no implicit calls to callback

  + **Callback typing**

    One can type his @async function callback and macro will notice it. Sometimes it is even needed: when the function doesn't contain any implicit returns there is no way macro can know how many arguments it should callback with.

## ToDo
  + parralel code execution
  + **for** loops - are not converted currently
  + **try{...}catch(...){...}** expressions - are not converted currently
  + code samples should be added to this file
