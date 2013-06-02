package async;

import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.Tools;

using async.tools.Macro;
using async.tools.Various;
import async.tools.Macro;
import haxe.ds.StringMap;

using Lambda;
private typedef Arg = {expr:Expr, direct:Bool, ?type:haxe.macro.ComplexType};  //TODO
private typedef Call = {ids:Array<Arg>, fun:Expr};

class Flow{
  static inline var PREFIX = #if async_readable '_' #else '__' #end;
  static inline var ERROR_NAME = '_e';
  static var NULL:ExprDef = 'null'.ident();
  static var ZERO:ExprDef = EConst(CInt('0'));
  static var TRUE:ExprDef = 'true'.ident();
  static var FALSE:ExprDef = 'false'.ident();
  static var ERROR:ExprDef = ERROR_NAME.ident();

  static var counter:Int;
  static var savedErrors:Array<Error> = [];

  public static function printErrors(){
    for(error in savedErrors){
      Context.error(error.message, error.pos);
    }
    savedErrors = [];
  }

  static inline function simpleType(name:String, pack:Array<String> = null){
    return TPath({name: name, pack: pack == null ? [] : pack, params:[] });
  }
  static var DYNAMIC = simpleType('Dynamic');
  static var VOID = simpleType('Void');

  public static function convertFunction(fun:Function, ?params:Array<Expr>){
    var cbType = null, returns = null;
    if(params != null && params.length == 1){
      switch(params[0].expr){
        case EVars(vars):
          returns = [];
          var types = [DYNAMIC];
          for(v in vars){
            returns.push(v.type);
            types.push(v.type);
          }
          cbType = TFunction(types, VOID);
        case EConst(CIdent('None')):
          returns = [];
          cbType = TFunction([DYNAMIC], VOID);
        default:
      }
    }
    counter = 0;
    var cvt = convertBlock('__cb', returns, fun.expr);
    fun.expr = cvt.expr;
    if(cbType == null && cvt.args == 0) cbType = TFunction([DYNAMIC], VOID);
    fun.args.push({name:'__cb', type:cbType, opt:false});
    fun.ret = VOID;
  }

  public static function blockToFunction(e:Expr){
    var pos = e.pos;
    var cbName = 'cb';
    return EFunction(null, {
      args: [{name:cbName, opt:false, type:null}],
      ret: null,
      expr: convertBlock(cbName, null, e).expr,
      params: [],
    }).pos(pos);
  }



  inline function mkFlow(isrc:Expr):Flow{
    var flow = new Flow(this);
    return flow.process(isrc);
  }

  inline function mkLoop(isrc:Expr):Flow{
    var flow = new Flow(this);
    flow.repsBreak = [];
    flow.repsContinue = [];
    return flow.process(isrc);
  }

  inline function mkTry(isrc:Expr):Flow{
    var flow = new Flow(this);
    flow.repsThrow = [];
    return flow.process(isrc);
  }

  function new(parent:Flow){
    root = lines = [];
    async = false;
    open = true;
    run = true;

    if(parent == null){
      repsContinue = repsBreak = null;
      repsThrow = [];
      repsReturn = [];
    }
    else{
      repsBreak = parent.repsBreak;
      repsContinue = parent.repsContinue;
      repsReturn = parent.repsReturn;
      repsThrow = parent.repsThrow;
    }
  }


  static function convertBlock(cbName:String, returns:Array<ComplexType>, e:Expr):{args:Int, expr:Expr}{
    e.pos.set();
    var flow = new Flow(null).process(e);
    if(flow.open) flow.finalize();

    var cb = cbName.ident().pos(e.pos);
    var returnsLength = 0;
    if(returns != null) returnsLength = returns.length;
    else{
      for(ret in flow.repsReturn){
        switch(ret.expr){
          case EReturn(e):
            returnsLength = switch(e){
              case null: 0;
              case {expr:ECall(f, args)} if (f.extractIdent() == 'many'): args.length;
              case _: 1;
            }
            break;
          default: trace('shouldnt happen');
        }
      }
    }
    var localNull = NULL.pos(e.pos), localZero = ZERO.pos(e.pos), localFalse = FALSE.pos(e.pos);
    for(ret in flow.repsReturn){
      switch(ret.expr){
        case EReturn(sub):
          var args = switch(sub){
            case null: [];
            case {expr:ECall(f, _args)} if (f.extractIdent() == 'many'): _args;
            default: [sub];
          };
          args.unshift(localNull);
          ret.expr = ECall(cb, args);
        default: throw 'shouldnt happen, not a return: '+ret;
      }
    }
    var ref;
    if(returns == null){
      ref = [for (i in 0...returnsLength) localNull];
    }
    else{
      ref = [for (i in 0...returnsLength) switch(returns[i]){
        case TPath({name:'Int', pack:[]}): localZero;
        case TPath({name:'Bool', pack:[]}): localFalse;
        default: localNull;
      }];
    }
    ref.unshift(null);

    for(thr in flow.repsThrow){
      switch(thr.expr){
        case EThrow(e):
          var args = ref.copy();
          args[0] = e;
          thr.expr = ECall(cb, args);
        default: trace('shouldn\'t happen: ${thr.toString()');
      }
    }


    var ret = EBlock(flow.root).pos(e.pos);
    // var ret = switch(newstate.root){ case [e]: e; case el: el.block().pos(e.pos); };
    return {args:returnsLength, expr:ret};
  }

  inline function finalize(?call){
    if(open){
      if(call == null){
        var expr = EReturn(null).p();
        repsReturn.push(expr);
        lines.push(EReturn(expr).p());
      }
      else{
        lines.push(call);
      }
      open = false;
    }
  }

  inline function jumpIn(newLines, ?callExpr){
    lines = newLines;
  }

  var root: Array<Expr>;
  var lines: Array<Expr>;
  var async: Bool;
  var open: Bool;

  var repsBreak:Array<Expr>;
  var repsContinue:Array<Expr>;
  var repsReturn:Array<Expr>;
  var repsThrow:Array<Expr>;

  var parent:Flow;
  var run:Bool;

  inline function makeCbArg(cbArgs, lines){
    var err = ERROR.p(), block = EBlock(lines).p(), ebCallGen = ebCall(err);
    lines.push(macro if($err != null) return $ebCallGen);
    return EFunction(null, {
      args: cbArgs,
      expr: block,
      ret: VOID,
      params: [],
    }).p();
  }

  inline function processAsyncCall(expr, call:Call){
    var cbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
    var newLines = [];
    call.fun.pos.set();
    for(id in call.ids){
      var name = id.expr.extractIdent();
      if(name == '_') cbArgs.push({name:name, type:null, opt:false, value:null});
      else if(id.direct){
        var genId = gen('_');
        cbArgs.push({name:genId, type:null, opt:false, value:null});
        newLines.push(EBinop(OpAssign, id.expr, genId.ident().p()).p());
      }
      else{
        if(name == null) error(id.expr, 'Not an identifier.', true);
        cbArgs.push({name:name, type:id.type, opt:false, value:null});
      }
    }
    switch(call.fun.expr){
      case ECall(_, args):
        args.push(makeCbArg(cbArgs, newLines));
        lines.push(call.fun);
        jumpIn(newLines);
      default: error(call.fun, 'Not a function call.');
    }
  }

  inline function ebCall(arg:Expr){
    var expr = EThrow(arg).p();
    repsThrow.push(expr);
    return expr;
  }

  inline function processParallelCalls(expr, calls:Array<Call>){
    switch(calls.length){
      case 0:
        warning(expr, 'No parallel calls.');
      case 1:
        processAsyncCall(expr, calls[0]);
      default:{
        //TODO check our vars dont overlap with what we use in calls
        var prevPos = Macro.getPos();
        expr.pos.set();

        var parallelCounterN = gen('rem_'), afterParallelN = gen('after_');
        var parallelCounterI = parallelCounterN.ident(), afterParallelI = afterParallelN.ident();
        var vars = [];
        var idsUsed = new StringMap();
        for(call in calls){
          switch(call.fun.expr){
            case EBlock(_): call.fun = ECall(blockToFunction(call.fun), []).pos(call.fun.pos);
            case ECall(_,_):
            default: error(call.fun, 'Not a call nor block.');
          }
          for(id in call.ids){
            if(!id.direct){
              var name = id.expr.extractIdent();
              if(name == null){
                error(id.expr, 'Not an identificator.');
                name = '_';
              }
              if(name != '_' && idsUsed.exists(name)){
                name = '_';
                error(id.expr, 'Identificator used more than once in one parallel.');
              }
              else{
                idsUsed.set(name, true);
                vars.push({name:name, expr:NULL.p(), type:null});
              }
            }
          }
        }
        vars.push({name:parallelCounterN, expr:EConst(CInt(''+calls.length)).p(), type:null});
        lines.push(EVars(vars).p());

        var newLines = [];
        lines.push(makeErrorFun(afterParallelN,
          [
            EIf(
              EBinop(OpEq, EUnop(OpDecrement, false, parallelCounterI.p()).p(), ZERO.p()).p(),
              EBlock(newLines).p(),
              null// EReturn(null).p()
            ).p()
          ],
          EIf(
            EBinop(OpGte, parallelCounterI.p(), ZERO.p()).p(),
            EBlock([
              EBinop(OpAssign, parallelCounterI.p(), EConst(CInt('-1')).p()).p(),
              EReturn(ebCall(ERROR.p())).p()
            ]).p(),
            null// EReturn(null).p()
          ).p()
        ));
        for(call in calls){
          var lcb;
          if(call.ids.length == 0){
            lcb = afterParallelI.p();
          }
          else{
            var lcbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
            var lcbLines = [];
            for(id in call.ids){
              var name = id.expr.extractIdent();
              if(name == '_'){
                lcbArgs.push({ name: '_', type: null, opt: false, value: null });
              }
              else{
                var genId = gen('_');
                lcbArgs.push({ name: genId, type: null, opt: false, value: null });
                lcbLines.push(EBinop(OpAssign, id.expr, genId.ident().p()).p());
              }
            }
            lcbLines.push(afterParallelI.p().call([ERROR.p()]).p());
            lcb = EFunction(null, {
              args: lcbArgs,
              expr: EBlock(lcbLines).p(),
              params: [],
              ret: null,
            }).p();
          }
          switch(call.fun.expr){
            case ECall(_, args):
              args.push(lcb);
              lines.push(call.fun);
            default:
              error(call.fun, 'Either function call or block required.');
          }
        }
        // lines.push(EReturn(null).p());
        lines = newLines;
      }
    }
  }

  public inline function getExpr(){
    //~ return (root.length == 1) ? root[0] : EBlock(root).p();
    return EBlock(root).p();
  }

  inline function closed() return !open;

  inline function oneExpr(ea:Array<Expr>){
    return ea.length == 1 ? ea[0] : EBlock(ea).p();
  }

  public function process(isrc:Expr, use_return = true){
    var prevPos = Macro.getPos();
    //FIXME something weird happens there
    //var src = isrc == null ? [] : switch(isrc.expr){ case EBlock(blines): blines; default: [isrc]; };
    var src = (isrc == null || isrc.expr == null) ? [] : switch(isrc.expr){ case EBlock(blines): blines; default: [isrc]; };
    var pos = 0, len = src.length;
    while(pos < len && run){
      var line = src[pos++];
      line.pos.set();
      switch(line.expr){
        case EBinop(OpAssign, {expr:EArrayDecl(_)}, _):
          async = true;
          processAsyncCall(line, argToCall(line));
        case EArrayDecl(elems):
          async = true;
          processParallelCalls(line, argsToCalls(elems));
        case EReturn(_):{
          lines.push(EReturn(line).p());
          repsReturn.push(line);
          open = false;
          run = false;
          break;
        }
        case EFor(iter, expr):{
          var flow = mkLoop(expr);
          if(!flow.async && flow.open){
            lines.push(EFor(iter, flow.getExpr()).p());
          }
          else{
            async = true;
            var loopN = gen('loop'), afterLoopN = gen('afterLoop'), iteratorN = gen('iter');
            var loopI = loopN.ident(), afterLoopI = afterLoopN.ident(), iteratorI = iteratorN.ident();
            var loopCall = loopI.p().call([]);
            var afterLoopCall = afterLoopI.p().call([]);
            for(bre in flow.repsBreak) bre.expr = afterLoopCall;
            for(con in flow.repsContinue) con.expr = loopCall;

            var it, id;
            switch(iter.expr){
              case EIn(idexpr, _it):
                it = _it;
                id = idexpr.extractIdent();
              default: error(line, 'Invalid for cycle.', true);
            }
            var afterLoopLines = [];
            var afterLoopDefinition = makeNoargFun(afterLoopN, EBlock(afterLoopLines).p());
            var loopDefinition = makeNoargFun(loopN, EIf(
                  ECall(EField(iteratorI.p(), 'hasNext').p(), []).p(),
                  EBlock(flow.root).p(),
                  afterLoopCall.p()
                ).p());
            lines.push(afterLoopDefinition);
            lines.push(singleVar(iteratorN, it).p());
            lines.push(loopDefinition);
            lines.push(loopCall.p());
            if(flow.open) flow.lines.push(loopCall.p());
            flow.root.unshift(singleVar(id, EField(iteratorI.p(), 'next').p().call([]).p()).p());
            //~ flow.replaceLoopBreaks(afterLoopCall, loopCall);
            //TODO
            jumpIn(afterLoopLines);
          }
        }
        case EWhile(econd, expr, normal):{
          var flow = mkLoop(expr);
          if(!flow.async && flow.open){
            lines.push(EWhile(econd, flow.getExpr(), normal).p());
          }
          else{
            async = true;
            var loopN = gen('loop'), afterLoopN = gen('afterLoop');
            var loopI = loopN.ident(), afterLoopI = afterLoopN.ident();
            var loopCall = loopI.p().call([]);
            var afterLoopLines = [];
            var afterLoopCall = afterLoopI.p().call([]);
            var afterLoopDefinition = makeNoargFun(afterLoopN, EBlock(afterLoopLines).p());
            for(bre in flow.repsBreak) bre.expr = afterLoopCall;
            for(con in flow.repsContinue) con.expr = loopCall;

            var loopDefinition;
            if(normal){
              loopDefinition = makeNoargFun(loopN, EIf(
                econd,
                EBlock(flow.root).p(),
                afterLoopCall.p()
              ).p());
            }
            else{
              flow.root.push(EIf(
                econd,
                loopCall.p(),
                afterLoopCall.p()
              ).p());
              loopDefinition = makeNoargFun(loopN, EBlock(flow.root).p());
            }

            lines.push(afterLoopDefinition);
            lines.push(loopDefinition);
            lines.push(loopCall.p());
            if(flow.open) flow.lines.push(loopCall.p());
            jumpIn(afterLoopLines);
          }
        }
        case EBreak:{
          repsBreak.push(line);
          lines.push(line);
          open = false;
          run = false;
          break;
        }
        case EContinue:{
          repsContinue.push(line);
          lines.push(line);
          open = false;
          run = false;
          break;
        }
        case EIf(econd, etrue, null):{
          var ftrue = mkFlow(etrue);
          if(!ftrue.open){
            var afterIfLines = [];
            lines.push(EIf(econd, ftrue.getExpr(), EBlock(afterIfLines).p()).p());
            jumpIn(afterIfLines);
          }
          else if(ftrue.async){
            var afterIfN = gen('after');
            var afterIfI = afterIfN.ident();
            var afterIfLines = [];
            var afterIfCall = afterIfI.p().call([]).p();
            lines.push(makeNoargFun(afterIfN, EBlock(afterIfLines).p()));
            ftrue.lines.push(afterIfCall);
            lines.push(EIf(econd, ftrue.getExpr(), afterIfCall).p());
            jumpIn(afterIfLines);
          }
          else{
            lines.push(EIf(econd, ftrue.getExpr(), null).p());
          }
        }
        case EIf(econd, etrue, efalse) :{
          var ftrue = mkFlow(etrue);
          var ffalse = mkFlow(efalse);
          if(!ftrue.open && !ffalse.open){
            lines.push(EIf(econd, ftrue.getExpr(), ffalse.getExpr()).p());
            run = open = false;
          }
          else if(!ftrue.async && !ffalse.async){
            lines.push(EIf(econd, ftrue.getExpr(), ffalse.getExpr()).p());
          }
          else{
            var afterIfN = gen('after');
            var afterIfI = afterIfN.ident();
            var afterIfLines = [];
            var afterIfCall = afterIfI.p().call([]).p();
            lines.push(makeNoargFun(afterIfN, EBlock(afterIfLines).p()));
            if(ffalse.open) ffalse.lines.push(afterIfCall);
            if(ftrue.open) ftrue.lines.push(afterIfCall);
            lines.push(EIf(econd, ftrue.getExpr(), ffalse.getExpr()).p());
            jumpIn(afterIfLines);
          }
        }
        case EThrow(_):{
          repsThrow.push(line);
          lines.push(EReturn(line).p());
          open = false;
          run = false;
          break;
        }
        case ESwitch(e, cases, edef):{
          var trees = [];
          for(cas in cases){
            trees.push(cas.expr);
          }
          if(edef != null) trees.push(edef);
          var asyncs = 0;

          var states = [];
          trees.map(function(tree){
            var flow = mkFlow(tree);
            if(flow.async || flow.closed()) asyncs++;
            states.push(flow);
          });
          if(asyncs == 0 && edef != null){
            lines.push(line);
          }
          else{
            async = true;
            var afterSwitchN = gen('after_');
            var afterSwitchI = afterSwitchN.ident();
            var newLines = [];
            lines.push(makeNoargFun(afterSwitchN, EBlock(newLines).p()));
            for(flow in states){
              // flow.finalize(EReturn(afterSwitchI.p().call([]).p()).p());
              flow.finalize(afterSwitchI.p().call([]).p());
            }
            var i = cases.length;
            while(i --> 0){
              cases[i].expr = states[i].getExpr();
            }
            // lines.push(ESwitch(e, cases, edef == null ? EReturn(afterSwitchI.p().call([]).p()).p() : states[states.length - 1].getExpr()).p());
            lines.push(ESwitch(e, cases, edef == null ? afterSwitchI.p().call([]).p() : states[states.length - 1].getExpr()).p());
            // lines.push(EReturn(null).p());
            lines = newLines;
          }
        }
        case ETry(expr, catches):{
          var afterTryN = gen('afterTry'), afterCatchN = gen('afterCatch');
          var afterTryI = afterTryN.ident(), afterCatchI = afterCatchN.ident();
          var flow = mkTry(expr);
          async = true;

          var newLines = [];
          lines.push(makeErrorFun(afterCatchN, newLines, ebCall(ERROR.p())));

          if(!haveCatchAll(catches)){
            catches.push({name:ERROR_NAME, type:TPath({name:'Dynamic', pack:[], params:[]}), expr:
              ebCall(ERROR.p())
            });
          }

          for(thr in flow.repsThrow){
            switch(thr.expr){
              case EThrow(e): thr.expr = ECall(afterTryI.p(), [e]);
              default: throw 'shouldnt happen';
            }
          }

          if(flow.async){
            for(cat in catches){
              var cflow = mkFlow(cat.expr);
              cflow.finalize(afterCatchI.p().call([NULL.p()]).p());
              cat.expr = cflow.getExpr();
            }

            lines.push(EFunction(afterTryN, {
              args: [{name:ERROR_NAME, type:null, opt:false}],
              expr: EIf(
                EBinop(OpNotEq, ERROR.p(), NULL.p()).p(),
                ETry( EThrow(ERROR.p()).p(), catches ).p(),
                ECall(afterCatchI.p(), [NULL.p()]).p()
              ).p(),
              ret: null,
              params: [],
            }).p());
            if(flow.open) flow.lines.push(afterTryI.p().call([NULL.p()]).p());
            for(nline in flow.root) lines.push(nline);
          }
          else{
            for(cat in catches){
              var cflow = mkFlow(cat.expr);
              cflow.finalize(afterCatchI.p().call([NULL.p()]).p());
              cat.expr = cflow.getExpr();
            }

            lines.push(ETry(flow.getExpr(), catches).p());
          }
          jumpIn(newLines);
        }
        default: lines.push(line);
      }
    }
    prevPos.set();
    return this;
  }


  static inline function singleVar(name, val)
    return EVars([{name:name, type:null, expr:val}]);

  static inline function makeFunction(name, args, expr, ret = null, params = null){
    return EFunction(name, {
      args: args,
      expr: expr,
      ret: ret,
      params: params == null ? [] : params,
    }).p();
  }

  static inline function makeErrorFun(name:String, lines:Array<Expr>, onError:Expr){
    return makeFunction(name, [{name:ERROR_NAME, type:null, opt:false}], 
      EIf(
        EBinop(OpEq, ERROR.p(), NULL.p()).p(),
        EBlock(lines).p(),
        onError
      ).p(),
      VOID
    );
  }

  static inline function makeNoargFun(name:String, e:Expr)
    return makeFunction(name, [], e, VOID);

  static function haveCatchAll(catches:Array<Catch>){
    for(cat in catches){
      switch(cat.type){
        case TPath({name:Dynamic, pack:[]}):
        default:
      }
    }
    return false;
  }

  inline static function argToCall(arg:Expr):Call{
    return switch(arg.expr){
      case EBinop(OpAssign, {expr:EArrayDecl(elems)}, fun):
        {
          ids:[for(e in elems) switch(e.expr){
            case EVars(vars) if(vars.length == 1):
              var vr = vars[0];
              {expr: EConst(CIdent(vr.name)).p(), type:vr.type, direct:false};
            default:
              {expr:e, direct:true};
          }],
          fun:fun
        };
      case EBinop(OpAssign, expr, fun):
        {ids:[{expr:expr, direct:true}], fun:fun};
      case EVars(vars) if(vars.length == 1):
        var vr = vars[0];
        {ids:[{expr:EConst(CIdent(vr.name)).p(), type:vr.type, direct:false}], fun:vr.expr};
      case ECall(_,_), EBlock(_):
        {ids:[], fun:arg};
      default: error(arg, 'wtf'); null;
    }
  }

  inline static function argsToCalls(args:Array<Expr>):Array<{ ids:Array<Arg>, fun:Expr}>{
    if(args.length == 1){
      switch(args[0].expr){
        case EArrayDecl(elems): args = elems;
        default:
      }
    }
    return [for(arg in args) argToCall(arg)];
  }

  static inline function assert(v, msg = 'shouldnt happen') if(!v) throw msg;

  static inline function gen(str = '_') return str+StringTools.hex(counter++);

  static inline function error(expr:Expr, msg = 'Error (not clarified)', stop = false){
    if(stop){
      throw new Error(msg, expr.pos);
    }
    else{
      savedErrors.push(new Error(msg, expr.pos));
    }
  }

  static inline function warning(expr:Expr, msg = 'Warning (not clarified)'){
    Context.warning(msg, expr.pos);
  }



}

