package async.tools;
import haxe.macro.Expr;
using Lambda;
using StringTools;
class Macro{
  static var position:Position;
  public static inline function set(pos) position = pos
  public static inline function getPos() return position
  public static inline function p(e) return {expr:e, pos:position}

  static function dumpType(t:ComplexType){
    return switch(t){
      case TPath( p ): dumpTypePath(p);
      case TFunction( args, ret): args.map(dumpType).join('->')+'->'+dumpType(ret);
      case TAnonymous( fields ): '{...}';
      case TParent( t ): '('+dumpType(t)+')';
      case TExtend( p , fields ): '{...}';
      case TOptional( t ): 'Null<'+dumpType(t)+'>';
    }
  }

  static inline function dumpTypePath(t){
    return (t.pack.length == 0 ? '' : t.pack.join('.')+'.') + t.name + (t.sub == null ? '' : '.'+t.sub)+(t.params.length == 0 ? '' : '<'+t.params.join(', ')+'>');
  }

  static inline function dumpUnOp(op){
    return switch(op){
      case OpIncrement: '++';
      case OpDecrement: '--';
      case OpNot: '!';
      case OpNeg: '-';
      case OpNegBits: '~';
    }
  }

  static function dumpFunction(name:String, f:Function){
    incIdent();
    var ret = 'function '+(name == null ? '' : name)+'('+f.args.map(function(v){
          return
            (v.opt ? '?' : '')+
            v.name+
            (v.type == null ? '' : dumpType(v.type))+
            (v.value == null ? '' : ' = '+dumpExpr(v.value))
            ;
        }).join(', ')+')'+
      (f.ret == null ? '' : ':'+dumpType(f.ret))+' '+
      dumpExpr(f.expr)
      ;
    decIdent();
    return ret;
  }

  static inline function dumpConst(c){
    return switch(c){
      case CInt( v ): v;
      case CFloat( f ): f;
      case CString( s): '\''+s.replace('\\', '\\\\').replace('\'', '\\\'')+'\'';
      case CIdent( s): s;
      case CRegexp( r, opt): '/'+r+'/'+opt;
      #if !haxe3
      case CType( s ): s;
      #end
    }
  }

  static inline function dumpBinop(op, e1, e2){
    var ret;
    switch(op){
      case OpAdd: ret = dumpExpr(e1)+' + '+dumpExpr(e2);
      case OpMult: ret = dumpExpr(e1)+' * '+dumpExpr(e2);
      case OpDiv:ret = dumpExpr(e1)+' / '+dumpExpr(e2);
      case OpSub:ret = dumpExpr(e1)+' - '+dumpExpr(e2);
      case OpAssign:ret = dumpExpr(e1)+' = '+dumpExpr(e2);
      case OpEq:ret = dumpExpr(e1)+' == '+dumpExpr(e2);
      case OpNotEq:ret = dumpExpr(e1)+' != '+dumpExpr(e2);
      case OpGt:ret = dumpExpr(e1)+' > '+dumpExpr(e2);
      case OpGte:ret = dumpExpr(e1)+' >= '+dumpExpr(e2);
      case OpLt:ret = dumpExpr(e1)+' < '+dumpExpr(e2);
      case OpLte:ret = dumpExpr(e1)+' <= '+dumpExpr(e2);
      case OpAnd:ret = dumpExpr(e1)+' & '+dumpExpr(e2);
      case OpOr:ret = dumpExpr(e1)+' | '+dumpExpr(e2);
      case OpXor:ret = dumpExpr(e1)+' ^ '+dumpExpr(e2);
      case OpBoolAnd:ret = dumpExpr(e1)+' && '+dumpExpr(e2);
      case OpBoolOr:ret = dumpExpr(e1)+' || '+dumpExpr(e2);
      case OpShl:ret = dumpExpr(e1)+' << '+dumpExpr(e2);
      case OpShr:ret = dumpExpr(e1)+' >> '+dumpExpr(e2);
      case OpUShr:ret = dumpExpr(e1)+' >>> '+dumpExpr(e2);
      case OpMod:ret = dumpExpr(e1)+' % '+dumpExpr(e2);
      case OpAssignOp(op):
        ret = dumpExpr(e1)+' ASSIGN OP('+op+') '+dumpExpr(e2);
      case OpInterval:ret = dumpExpr(e1)+'...'+dumpExpr(e2);
    }
    return ret;
  }

  public static function dump(e:Expr, i = '', is = '  '){
    id = pid = i;
    idStep = is;
    idStepLen = idStep.length;
    return dumpExpr(e);
  }
  static var pid:String;
  static var id:String;
  static var idStep:String;
  static var idStepLen:Int;

  static inline function incIdent(){
    pid = id;
    id+= idStep;
  }

  static inline function decIdent(){
    id = pid;
    pid = (pid == '') ? '' : pid.substr(0, pid.length - idStepLen);
  }

  public static function dumpExpr(e:Expr){
    if(e.pos == null) return '### NO POS ###';
    var expr = e.expr;
    switch(expr){
      case EMeta(_): throw 'error';
      case EWhile(cond, expr, normal):
        return 'while( '+dumpExpr(cond)+' ) '+dumpExpr(expr);
      case EVars(vars):
        return
          'var '+vars.map(function(v){
            var str = v.name;
            if(v.type != null) str+= ':'+dumpType(v.type);
            if(v.expr != null) str+= ' = '+dumpExpr(v.expr);
            return str;
          }).join(', ');
      case EUntyped(e): return 'untyped '+dumpExpr(e);
      case EUnop(op,postFix,e):
        return postFix ?
          dumpExpr(e) + dumpUnOp(op) :
          dumpUnOp(op) + dumpExpr(e) ;
      //~ case EType(e,field):
        //~ throw 'type';
        //~ return null;
      case ETry(e,catches):
        var ret = 'try ';
        ret+= dumpExpr(e);
        ret+= '';
        for(cat in catches) ret+= 'catch('+cat.name+':'+dumpType(cat.type)+') '+dumpExpr(cat.expr);
        return ret;
      case EThrow(e):
        return 'throw '+dumpExpr(e);
      case ETernary(econd,eif,eelse):
        return dumpExpr(econd)+' ? '+dumpExpr(eif)+' : '+dumpExpr(eelse);
      //~ case ESwitch(e : Expr,cases : Array<{ values : Array<Expr>, expr : Expr }>,edef : Null<Expr>):
      case ESwitch(e,cases,edef):
        throw 'switch';
        return null;
      case EReturn(e):
        return 'return'+(e == null ? '' : ' '+dumpExpr(e));
      case EParenthesis(e):
        return '('+dumpExpr(e)+')';
      //~ case EObjectDecl(fields : Array<{ field : String, expr : Expr }>)
      case EObjectDecl(fields):
        //~ throw 'object';
        return '{...}';
      case ENew(t,params):
        return 'new '+dumpTypePath(t)+'('+params.map(dumpExpr).join(', ')+')';
      //~ case EIn(e1 : Expr,e2 : Expr):
      case EIn(e1,e2):
        return dumpExpr(e1)+' in '+dumpExpr(e2);
      case EIf(econd,eif,eelse):
        var ret = 'if('+dumpExpr(econd)+') ';
        incIdent();
        ret+= dumpExpr(eif);
        if(eelse != null){
          ret+= '\n'+pid+'else ';
          ret+= dumpExpr(eelse);
        }
        decIdent();
        return ret;
      case EFunction(name, f):
        return dumpFunction(name, f);
      case EFor(it,expr):
        return 'for('+dumpExpr(it)+') '+dumpExpr(expr);
      case EField(e,field):
        return dumpExpr(e)+'.'+field;
      //~ case EDisplayNew(t : TypePath)
      case EDisplayNew(t): throw 'displaynew'; return null;
      //~ case EDisplay(e : Expr,isCall : Bool)
      case EDisplay(e,isCall): throw 'display'; return null;
      case EContinue:
        return 'continue';
      case EConst(c):
        return dumpConst(c);
      //~ case ECheckType(e : Expr,t : ComplexType)
      case ECheckType(e,t): throw 'checktype'; return null;
      case ECast(e,t):
        return t == null ?
          'cast('+dumpExpr(e)+')':
          'cast('+dumpExpr(e)+', '+dumpType(t)+')';
      case ECall(e,params): return  dumpExpr(e)+'('+params.map(dumpExpr).join(', ')+')';
      case EBreak: return 'break';
      case EBlock(exprs):
        var ret = '{\n';
        incIdent();
        ret+= exprs.map(function(v){
          var semi = switch(v.expr){
            case EFunction(_,_), EIf(_,_,_), EFor(_,_), EWhile(_,_,_), EBlock(_): false;
            default: true;
          };
          return id+dumpExpr(v)+(semi ? ';\n' :'\n');
        }).join('')+pid+'}';
        decIdent();
        return ret;

      case EBinop(op, e1, e2): return dumpBinop(op, e1, e2);
      case EArrayDecl(values): return '['+values.map(dumpExpr).join(', ')+']';
      //~ case EArray(e1 : Expr,e2 : Expr)
      case EArray(e1,e2):
        throw 'array';
        return null;

    }
  }

  public static inline function pos(e:ExprDef, pos) return {expr:e, pos:pos}
  public static inline function ident(name:String) return EConst(CIdent(name))
  public static inline function binop(op, e1, e2) return EBinop(op, e1, e2)
  public static inline function call(func, params) return ECall(func, params)
  public static inline function block(lines) return EBlock(lines)

  public static inline function extractIdent(expr:Expr):String{
    return switch(expr.expr){
      case EConst(ident):
        switch(ident){
          case CIdent(name): name;
          default: null;
        }
      default: null;
    }
  }

}
