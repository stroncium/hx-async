package async;
#if macro import haxe.macro.Expr; #end
#if macro import haxe.macro.Context; #end

class Async{

  public static function traceError(err:Dynamic){
    if(err != null) trace(err);
  }

  public static macro function getError() return Flow.getAsyncError();

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

}
