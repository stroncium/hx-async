package async;
#if macro import haxe.macro.Expr; #end
#if macro import haxe.macro.Context; #end

import haxe.PosInfos;

class Async{

  public static function traceError(err:Dynamic){
    if(err != null) trace(err);
  }

  macro public static function it(e:Expr):Dynamic{
    switch(e.expr){
      case EFunction(_, fun):
        Flow.convertFunction(fun);
      default:
    }
    Flow.printErrors();
    return e;
  }

  macro public static function block(e:Expr):Dynamic{
    var ret = Flow.blockToFunction(e);
    Flow.printErrors();
    return ret;
  }

  #if macro
  public static function buildClass(){
    var buildFields = Context.getBuildFields();
    for(f in buildFields){
      switch(f.kind){
        case FFun(fun):
          var async = false, params = null, dump = false;
          for(meta in f.meta){
            switch(meta.name){
              case 'async', ':async':
                async = true;
                params = meta.params;
                meta.params = [];
              case 'asyncDump', ':asyncDump':
                dump = true;
              default:
            }
          }
          if(async){
            Flow.convertFunction(fun, params);
            if(dump){
              neko.Lib.println(f.pos+':');
              neko.Lib.println(haxe.macro.ExprTools.toString({expr:EFunction(f.name, fun), pos:f.pos}));
            }
          }
        default:
      }
    }
    Flow.printErrors();
    return buildFields;
  }
  #end
}
