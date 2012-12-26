package async;
#if macro import haxe.macro.Expr; #end
#if macro import haxe.macro.Context; #end
#if macro using async.tools.MacroDump; #end

class Async{

  @:macro
  public static function it(e:Expr):Dynamic{
    switch(e.expr){
      //~ case EFunction(name, data):
      case EFunction(_, data):
        var cbArg = data.args[data.args.length - 1];
        data.expr = Flow.syncToAsync(cbArg, data.expr);
      default:
        return e;
    }
    return e;
  }


  #if macro //

  static inline var ASYNC_CALL_FUN = 'async';
  static inline var PARALLEL_CALL_FUN = 'parallel';
  static inline var ASYNC_RAW_FUN = 'asyncr';


  static function convertClassFunction(fun:Function, whole){
    if(whole){
      if(fun.args.length == 0) fun.args.push({name:'cb', type:null, opt:false});
      var cbArg = fun.args[fun.args.length - 1];
      var newexpr = Flow.syncToAsync(cbArg, fun.expr);
      fun.expr = newexpr;
      trace(fun.expr.dump());
      //~ fun.expr = EUntyped(newexpr).pos(fun.expr.pos);
      //~ throw 'lol';
    }
    else{
      throw 'not implemented';
    }
  }

  public static function buildClass(){
    log('building async class');
    var buildFields = Context.getBuildFields();
    log('total fields: '+buildFields.length);
    try{
    for(f in buildFields){
      switch(f.kind){
        case FFun(fun):
          log('found function '+f.name);
          var asyncAt = -1;
          log('meta: '+f.meta);
          for(i in 0...f.meta.length){
            var m = f.meta[i];
            switch(m.name){
              case 'async': asyncAt = i; break;
              default:
            }
          }
          if(asyncAt != -1){
            log('building async function '+f.name);
            convertClassFunction(fun, true);
            f.meta.splice(asyncAt, 1);
          }
          else{
            log('skipping');
          }
        default:
          //~ log('skipping field '+f.name);
      }
    }
    }
    catch(e:Dynamic){trace('Error building async class: '+e);}
    //~ trace(buildFields);
    return buildFields;
  }

  static inline function log(str:String){
    #if async_log //
      neko.Lib.println(str);
    #end
  }
  #end
}
