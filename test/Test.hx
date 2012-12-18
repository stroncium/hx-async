class Test implements async.Build{


/*
  function test(){
    var a = 0;
    async([
      a <= getA(a),
      b <= getB(),
      if(needWait) async(wait());
    ]);
    c = a+b;
    return c;
  }

  function test2(cb){
    var  = 0;
    {
    var a, b;
    var counter = 3;
    function afterParallel(e){
      if(e){
        counter = -1;
        cb(e, null, null);
      }
      else if(--counter == 0){
        cb(null, a, b);
      }
    }
    getA(function(e, v1){
      a = v1;
      afterParallel(e);
    });
    getB(function(e, v1){
      b = v1;
      afterParallel(e);
    });

    function afterIf(){
      reduceCounter()
    }
    if(needWait){
      counter++;
      afterIf()
      wait(function(e){
        reduceCounter(e);
      });
    }
  }
*/

  //~ @async
  //~ static function goAsync(cb){
    //~ trace('here we go');
    //~ async(
      //~ _ <= delayGet(1000, 'nothing'),
      //~ _ <= delayGet(1000, 'nothing')
    //~ );
    //~ async(doError(true));
  //~ }

  @async
  static function goAsync(cb){
    var c;
    async(
      a <= delayGet(500, 1),
      b <= delayGet(500, 2),
      c <= delayGet(500, a+b),
      doError(false)
    );
    trace('1+2 == '+c);
  }

  static inline function log(txt:String){
    trace(txt);
  }

  static inline function doError(need, cb) cb(need ? 'planned error' : null)
  static inline function delay(ms:Int, cb){
    haxe.Timer.delay(function(){
      log(ms+' passed');
      cb(null);
    }, ms);
  }
  static inline function delayGet(ms:Int, val:Dynamic, cb){
    haxe.Timer.delay(function(){
      log(ms+' passed, returning '+val);
      cb(null, val);
    }, ms);
  }

  public static function main(){
    goAsync(function(err){
      if(err != null){
        trace('Error: '+err);
      }
    });
  }
}
