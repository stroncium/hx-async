package async;

import haxe.macro.Expr;
import haxe.macro.Context;

using async.tools.Macro;
using async.tools.Various;
import async.tools.Macro;

using Lambda;

class Flow{
  static inline function isAsyncCall(name:String) return name == 'async' || name == 'as'
  static inline function isParallelCall(name:String) return name == 'parallel'

  static inline var PREFIX = #if async_readable '_' #else '__' #end;
  //~ static inline var ASYNC_RAW_FUN = 'asyncRaw';
  static inline var ERROR_NAME = #if async_readable '__error' #else '__e' #end;
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

  public static function convertFunction(fun:Function){
    if(fun.args.length == 0) fun.args.push({name:'cb', type:null, opt:false});
    var cbArg = fun.args[fun.args.length - 1];
    counter = 0;
    var returns = null;
    if(cbArg.type != null){
      switch(cbArg.type){
        case TFunction(args, _):
          returns = args.slice(1);
        default:
      }
    }
    fun.expr = convertBlock(cbArg.name, returns, fun.expr);
  }

  public static function blockToFunction(e:Expr){
    var pos = e.pos;
    var cbName = 'cb';
    return EFunction(null, {
      args: [{name:cbName, opt:false, type:null}],
      ret: null,
      expr: convertBlock(cbName, null, e),
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


  static function convertBlock(cbName:String, returns:Array<ComplexType>, e:Expr){
    e.pos.set();
    var flow = new Flow(null).process(e);
    if(flow.open) flow.finalize();

    var cb = cbName.ident().pos(e.pos);
    var returnsLength = returns == null ? 0 : returns.length;
    if(returns == null && flow.repsReturn.length > 0){
      for(ret in flow.repsReturn){
        switch(ret.expr){
          case EReturn(sub):
            returnsLength =
              if(sub == null) 0;
              else switch(sub.expr){
                case ECall(f, args): (f.extractIdent() == 'many') ? args.length : 1;
                default: 1;
              }
            break;
          default: throw 'shouldnt happen, not a return: '+ret;
        }
      }
    }
    var localNull = NULL.pos(e.pos), localZero = ZERO.pos(e.pos);
    for(ret in flow.repsReturn){
      switch(ret.expr){
        case EReturn(sub):
          var args =
            if(sub == null) [];
            else switch(sub.expr){
              case ECall(f, _args): (f.extractIdent() == 'many') ? _args : [sub];
              default: [sub];
            }
          args.unshift(localNull);
          ret.expr = ECall(cb, args);
        default: throw 'shouldnt happen, not a return: '+ret;
      }
    }
    if(returnsLength == 0){
      for(thr in flow.repsThrow){
        switch(thr.expr){
          case EThrow(e): thr.expr = ECall(cb, [e]);
          default:
          //~ default: throw 'shouldnt happen, not a throw: '+thr;
        }
      }
    }
    else{
      var ref = [null];
      if(returns == null){
        for(i in 0...returnsLength) ref.push(localNull);
      }
      else{
        for(i in 1...returns.length){
          ref.push(switch(returns[i]){
            case TPath(path): (path.name == 'Int' && path.pack.length == 0) ? localZero : localNull;
            default: localNull;
          });
        }
      }

      for(thr in flow.repsThrow){
        switch(thr.expr){
          case EThrow(e):
            var args = ref.copy();
            args[0] = e;
            thr.expr = ECall(cb, args);
          default:
          //~ default: throw 'shouldnt happen, not a throw: '+thr;
        }
      }
    }


    var ret = EBlock(flow.root).pos(e.pos);
    //~ return switch(newstate.root.length){
      //~ case 0: [].block().pos(e.pos);
      //~ case 1: newstate.root[0];
      //~ default: newstate.root.block().pos(e.pos);
    //~ };
    #if async_trace_converted trace(ret.pos+'\n'+async.tools.MacroDump.dump(ret)); #end
    return ret;
  }

  inline function finalize(?call){
    if(open){
      //~ if(lastCallExpr != null && lines.length == 0){
        //~ lastCallExpr.expr = cb;
      //~ }
      //~ else{
        if(call == null){
          var expr = EReturn(null).p();
          repsReturn.push(expr);
          lines.push(expr);
        }
        else{
          lines.push(call);
        }
      //~ }
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

  inline function processAsyncCalls(expr, calls:Array<{ids:Array<{expr:Expr, direct:Bool}>, fun:Expr}>){
    for(call in calls){
      var cbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
      var newLines = [];
      call.fun.pos.set();
      for(id in call.ids){
        if(id.direct){
          var genId = gen('');
          cbArgs.push({name:genId, type:null, opt:false, value:null});
          newLines.push(EBinop(OpAssign, id.expr, genId.ident().p()).p());
        }
        else{
          var name = id.expr.extractIdent();
          if(name != null){
            cbArgs.push({name:name, type:null, opt:false, value:null});
          }
          else{
            error(id.expr, 'Not an identifier.', true);
          }
        }
      }
      switch(call.fun.expr){
        case ECall(_, args):
          args.push(EFunction(null, {
            args: cbArgs,
            expr: EIf(
              EBinop(OpEq, ERROR.p(), NULL.p()).p(),
              EBlock(newLines).p(),
              ebCall(ERROR.p())
            ).p(),
            ret: null,
            params: [],
          }).p());
          lines.push(call.fun);
          jumpIn(newLines);
        default: error(call.fun, 'Not a function call.');
      }
    }
  }

  inline function ebCall(arg:Expr){
    var expr = EThrow(arg).p();
    repsThrow.push(expr);
    return expr;
  }

  inline function processParallelCalls(expr, calls:Array<{ids:Array<{expr:Expr, direct:Bool}>, fun:Expr}>){
    switch(calls.length){
      case 0:
        warning(expr, 'No parallel calls.');
      case 1:
        processAsyncCalls(expr, calls);
      default:{
        //TODO check our vars dont overlap with what we use in calls
        var prevPos = Macro.getPos();
        expr.pos.set();

        var parallelCounterN = gen('parallelCounter'), afterParallelN = gen('afterParallel');
        var parallelCounterI = parallelCounterN.ident(), afterParallelI = afterParallelN.ident();
        var vars = [];
        var idsUsed = new Hash();
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
              null
            ).p()
          ],
          EBlock([
            EBinop(OpAssign, parallelCounterI.p(), EConst(CInt('-1')).p()).p(),
            ebCall(ERROR.p())
          ]).p()
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
              else if(id.direct){
                var genId = gen('');
                lcbArgs.push({ name: genId, type: null, opt: false, value: null });
                lcbLines.push(EBinop(OpAssign, id.expr, genId.ident().p()).p());
              }
              else{
                var genId = gen(name);
                lcbArgs.push({ name: genId, type: null, opt: false, value: null });
                lcbLines.push(EBinop(OpAssign, name.ident().p(), genId.ident().p()).p());
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
        lines = newLines;
      }
    }
  }

  inline function processAsyncRawCall(realFunc:Expr, args:Array<Expr>, asyncParams:Array<Expr>){
    async = true;
    realFunc.pos.set();
    var cbArgs = [];
    for(par in asyncParams) cbArgs.push({
      name:par.extractIdent(),
      type:null,
      opt:false,
      value:null
    });
    var newLines = [];
    var cb = EFunction(null, {
          args: cbArgs,
          expr: EBlock(newLines).p(),
          params: [],
          ret: null,
        }).p();
    args.push(cb);
    //~ trace(MacroHelpers.dump(realFunc));
    lines.push(realFunc);
    lines = newLines;
  }

  public inline function getExpr(){
    //~ return (root.length == 1) ? root[0] : EBlock(root).p();
    return EBlock(root).p();
  }

  inline function closed() return !open

  public function process(isrc:Expr){
    var prevPos = Macro.getPos();
    var src = switch(isrc.expr){ case EBlock(blines): blines; default: [isrc]; };
    var pos, len;

    pos = 0;
    len = src.length;
    while(pos < len && run){
      var line = src[pos++];
      line.pos.set();
      switch(line.expr){
        case ECall(func, args):{
          var id = func.extractIdent();
          if(isAsyncCall(id)){
            async = true;
            processAsyncCalls(func, argsToCalls(args));
          }
          else if(isParallelCall(id)){
            async = true;
            processParallelCalls(func, argsToCalls(args));
          }
/*
          else if(id == ASYNC_PASSTHROUGH_FUN){
            for(arg in args)
              switch(arg.expr){
                case EBlock(blines): for(line in blines) lines.push(line);
                default: lines.push(arg);
              }
          }
          else if(id == ASYNC_RAW_FUN){
            //~ trace('async sure');
            var realFunc = extractRealFunc(args);
            switch(realFunc.expr){
              //~ case ECall(func, callArgs): processAsyncRawCall(realFunc, callArgs, args);
              case ECall(_, callArgs): processAsyncRawCall(realFunc, callArgs, args);
              default: throw 'not a function call';
            }
          }
*/
          else lines.push(line);
        }
        case EReturn(_):{
          lines.push(line);
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
        case EIf(econd, etrue, efalse):{
          var ftrue = mkFlow(etrue);
          var lasync = ftrue.async || !ftrue.open;
          var ffalse = null;
          if(efalse != null){
            ffalse = mkFlow(efalse);
            lasync = lasync || ffalse.async || !ffalse.open;
          }
          if(lasync){
            var afterIfN = gen('afterIf');
            var afterIfI = afterIfN.ident();
            var afterIfLines = [];
            var afterIfCall = afterIfI.p().call([]).p();
            if(efalse != null || ftrue.open){
              lines.push(makeNoargFun(afterIfN, EBlock(afterIfLines).p()));
            }
            var ifFalse = (efalse == null) ?
              ftrue.closed() ? EBlock(afterIfLines).p() :afterIfCall :
              EBlock(ffalse.root).p();
            lines.push(EIf(econd, EBlock(ftrue.root).p(), ifFalse).p());
            if(ftrue.open) ftrue.lines.push(afterIfCall);
            if(efalse != null && ffalse.open) ffalse.lines.push(afterIfCall);
            jumpIn(afterIfLines);
          }
          else{
            lines.push(EIf(econd, ftrue.getExpr(), efalse == null ? null : ffalse.getExpr()).p());
          }
          if(ftrue.closed() && efalse != null && ffalse.closed()){
            open = false;
            run = false;
            break;
          }
        }
        case EThrow(_):{
          repsThrow.push(line);
          lines.push(line);
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
            var afterSwitchN = gen('afterSwitch');
            var afterSwitchI = afterSwitchN.ident();
            var newLines = [];
            lines.push(makeNoargFun(afterSwitchN, EBlock(newLines).p()));
            for(flow in states){
              flow.finalize(afterSwitchI.p().call([]).p());
            }
            var i = cases.length;
            while(i --> 0){
              cases[i].expr = states[i].getExpr();
            }
            lines.push(ESwitch(e, cases, edef == null ? afterSwitchI.p().call([]).p() : states[states.length - 1].getExpr()).p());
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
              default:
              //~ default: throw 'shouldnt happen';
            }
          }

          if(flow.async){
            for(cat in catches){
              var cflow = mkFlow(cat.expr);
              cflow.finalize(afterCatchI.p().call([NULL.p()]).p());
              //~ cflow.finalize(EBinop(OpAssign, ERROR.p(), NULL.p()).p());
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
              //~ cflow.finalize(afterTryI.p().call([NULL.p()]).p());
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


  static inline function singleVar(name, val) return EVars([{name:name, type:null, expr:val}])

  static inline function makeErrorFun(name:String, lines:Array<Expr>, onError:Expr){
    return EFunction(name, {
      args: [{name:ERROR_NAME, type:null, opt:false}],
      expr: EIf(
        EBinop(OpEq, ERROR.p(), NULL.p()).p(),
        EBlock(lines).p(),
        onError
      ).p(),
      ret: null,
      params: [],
    }).p();
  }

  static inline function makeNoargFun(name:String, e:Expr){
    return EFunction(name, {
      expr: e,
      args: [],
      ret: null,
      params: [],
    }).p();
  }

  static function haveCatchAll(catches:Array<{ name : String, type : ComplexType, expr : Expr }>){
    for(cat in catches){
      switch(cat.type){
        case TPath(path):
          if(path.name == 'Dynamic' && path.pack.length == 0){
            return true;
          }
        default:
      }
    }
    return false;
  }

  inline static function argsToCalls(args:Array<Expr>){
    var calls = [];
    var ids = [];
    for(arg in args){
      switch(arg.expr){
        case EBinop(OpAssign, left, right):
          switch(left.expr){
            case EUnop(OpNot, _, expr): ids.push({expr:expr, direct:true});
            default: ids.push({expr:left, direct:false});
          }
          calls.push({ids:ids, fun:right});
          ids = [];
        case ECall(_,_), EBlock(_):
          if(ids.length > 0){
            error(arg, 'Unused identifiers (or wrong syntax).');
          }
          calls.push({ids:[], fun:arg});
          ids = [];
        default:
          ids.push({expr:arg, direct:false});
      }
    }
    if(ids.length > 0){
      trace(ids);
      error(args[args.length-1], 'Unused identifiers (or wrong syntax).');
    }
    return calls;
  }


  static inline function assert(v, msg = 'shouldnt happen') if(!v) throw msg

  static inline function gen(str = '') return PREFIX+str+StringTools.hex(counter++)

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

