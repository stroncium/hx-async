package async;
#if macro import haxe.macro.Expr; #end
#if macro import haxe.macro.Context; #end

import haxe.PosInfos;

class Async{

  #if haxe3 macro #else @:macro #end
  public static function it(e:Expr):Dynamic{
    switch(e.expr){
      case EFunction(_, fun):
        Flow.convertFunction(fun);
      default:
    }
    Flow.printErrors();
    return e;
  }

  #if haxe3 macro #else @:macro #end
  public static function block(e:Expr):Dynamic{
    var ret = Flow.blockToFunction(e);
    Flow.printErrors();
    return ret;
  }

  #if macro //
  static inline function isAsyncMeta(name:String) return name == 'async' || name == ':async';
  public static function buildClass(){
    var buildFields = Context.getBuildFields();
    for(f in buildFields){
      switch(f.kind){
        case FFun(fun):
          var asyncAt = -1;
          for(i in 0...f.meta.length){
            if(isAsyncMeta(f.meta[i].name)){
              asyncAt = i;
              break;
            }
          }
          if(asyncAt != -1){
            var params = f.meta[asyncAt].params;
            f.meta[asyncAt].params = [];
            //~ trace(params);
            Flow.convertFunction(fun, params);
            //~ f.meta.splice(asyncAt, 1);
          }
        default:
      }
    }
    Flow.printErrors();
    return buildFields;
  }
  #end
}
