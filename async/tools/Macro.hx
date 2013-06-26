package async.tools;
import haxe.macro.Expr;
using Lambda;
using StringTools;
class Macro{
  static var position:Position;
  public static inline function set(pos) position = pos;
  public static inline function getPos() return position;
  public static inline function p(e) return {expr:e, pos:position};

  public static inline function pos(e:ExprDef, pos) return {expr:e, pos:pos};
  public static inline function ident(name:String) return EConst(CIdent(name));
  public static inline function binop(op, e1, e2) return EBinop(op, e1, e2);
  public static inline function call(func, params) return ECall(func, params);
  public static inline function block(lines) return EBlock(lines);

  public static inline function extractIdent(expr:Expr):String return switch(expr.expr){
    case EConst(CIdent(name)): name;
    default: null;
  };

}
