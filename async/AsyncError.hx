package async;

import haxe.PosInfos;

class AsyncError<T>{
  public static function mk(err:Dynamic, ?pos:PosInfos){
    var ret;
    if(Std.is(err, AsyncError)){
      ret = err;
      ret.addStack(pos);
    }
    else{
      ret = new AsyncError(err, pos);
    }
    return ret;
  }

  public var stack:Array<PosInfos>;
  public var msg(default, null):T;
  public function new(msg:T, ?pos:PosInfos){
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
