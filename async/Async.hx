package async;
#if macro import haxe.macro.Expr; #end
#if macro import haxe.macro.Context; #end

class Async{
  @:macro
  public static function it(e:Expr):Dynamic{
    switch(e.expr){
      case EFunction(_, fun):
        Flow.convertFunction(fun);
      default:
    }
    return e;
  }

  @:macro
  public static function block(e:Expr):Dynamic{
    return Flow.blockToFunction(e);
  }

  #if macro //
  static inline var ASYNC_META = 'async';
  public static function buildClass(){
    var buildFields = Context.getBuildFields();
    for(f in buildFields){
      switch(f.kind){
        case FFun(fun):
          var asyncAt = -1;
          for(i in 0...f.meta.length){
            var m = f.meta[i];
            switch(m.name){
              case ASYNC_META: asyncAt = i; break;
              default:
            }
          }
          if(asyncAt != -1){
            Flow.convertFunction(fun);
            f.meta.splice(asyncAt, 1);
          }
        default:
      }
    }
    return buildFields;
  }
  #end
}
