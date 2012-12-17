class Test implements async.Build{

  @async
  static function goAsync(cb){
    trace('here we go');
    asyncr(delay(1000));
    trace('1000 ms passed');
  }

  static inline function delay(ms, fun) haxe.Timer.delay(fun, ms)

  public static function main(){
    goAsync(function(err){
      if(err != null){
        trace('Error: '+err);
      }
    });
  }
}
