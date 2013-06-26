package async;

import haxe.PosInfos;

class AsyncError{
  public static function mk(from:Dynamic, ?pos:PosInfos):AsyncError{
    var ret:AsyncError;
    if(Std.is(from, AsyncError)){
      ret = from;
      ret.addStack(pos);
    }
    else{
      ret = new AsyncError(from, pos);
    }
    return ret;
  }

  public var stack:Array<PosInfos>;
  public var msg(default, null):Dynamic;
  public function new(msg:Dynamic, ?pos:PosInfos){
    this.msg = msg;
    this.stack = [pos];
  }

  public inline function addStack(pos:PosInfos) stack.push(pos);

  public function toString(){
    var str = '$msg\n';
    var i = stack.length;
    while(i --> 0){
      var p = stack[i];
      str+= '  at ${p.className}.${p.methodName}() in ${p.fileName}:${p.lineNumber}\n';
    }
    return str;
  }



}
