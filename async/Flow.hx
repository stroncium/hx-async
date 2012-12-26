package async;

import haxe.macro.Expr;
import haxe.macro.Context;

using async.tools.Macro;
using async.tools.MacroDump;
using async.tools.Various;
import async.tools.Macro;

using Lambda;

class Flow{

  static var counter:Int;

  static inline function gen(){
    return StringTools.hex(counter++);
  }

  public static function syncToAsync(cbArg:FunctionArg, e:Expr){
    counter = 0;
    var flow = new Flow(null).process(e);
    if(flow.open) flow.finalize();

    var cb = cbArg.name.ident().pos(e.pos);
    var returns = null, returnsLength = 0;
    if(cbArg.type != null){
      switch(cbArg.type){
        case TFunction(args, _):
          returns = args.slice(1);
          returnsLength = returns.length;
        default:
      }
    }
    else if(flow.repsReturn.length > 0){
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
          default: throw 'shouldnt happen, not a throw: '+thr;
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
          default: throw 'shouldnt happen';
        }
      }
    }

    return EBlock(flow.root).pos(e.pos);
    //~ return switch(newstate.root.length){
      //~ case 0: [].block().pos(e.pos);
      //~ case 1: newstate.root[0];
      //~ default: newstate.root.block().pos(e.pos);
    //~ };
  }


  static inline var PREFIX = #if async_readable '' #else '__' #end;
  static inline var ASYNC_CALL_FUN = 'async';
  static inline var PARALLEL_CALL_FUN = 'parallel';
  static inline var ASYNC_RAW_FUN = 'asyncr';

  //~ var lastCallExpr:Expr;

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
    //~ lastCallExpr = callExpr;
  }

  //~ static inline function replaceExpressionsWithCalls(arr:Array<{a:Array<Expr>, p:Int}>, call:ExprDef){
    //~ for(acc in arr){
      //~ acc.set(call.pos(acc.get().pos));
    //~ }
  //~ }
//~
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

  #if async_readable
    static inline var ASYNC_PASSTHROUGH_FUN = PREFIX+'asyncPassthrough';
    static inline var LOOP_FUN = PREFIX+'loop';
    static inline var AFTER_LOOP_FUN = PREFIX+'afterLoop';
    static inline var AFTER_BRANCH_FUN = PREFIX+'afterBranch';
    static inline var ERROR_NAME = '_e';
    static inline var CALLBACK_FUN = PREFIX+'cb';
    static inline var PARALLEL_COUNTER = PREFIX+'parallelCounter';
    static inline var AFTER_PARALLEL = PREFIX+'afterParallel';
    static inline var AFTER_SWITCH = PREFIX+'afterSwitch';
    static inline var AFTER_TRY = PREFIX+'afterTry';
    static inline var AFTER_CATCH = PREFIX+'afterCatch';
    static inline var AFTER_IF = PREFIX+'afterIf';
    static inline var ITERATOR = PREFIX+'iter';
    static inline var NO_ERROR = PREFIX+'noError';
  #else
    static inline var ASYNC_PASSTHROUGH_FUN = PREFIX+'';
    static inline var LOOP_FUN = PREFIX+'';
    static inline var AFTER_LOOP_FUN = PREFIX+'';
    static inline var AFTER_BRANCH_FUN = PREFIX+'';
    static inline var ERROR_NAME = '_e';
    static inline var CALLBACK_FUN = PREFIX+'';
    static inline var PARALLEL_COUNTER = PREFIX+'';
    static inline var AFTER_PARALLEL = PREFIX+'';
    static inline var AFTER_SWITCH = PREFIX+'';
    static inline var AFTER_TRY = PREFIX+'';
    static inline var AFTER_CATCH = PREFIX+'';
    static inline var AFTER_IF = PREFIX+'';
    static inline var ITERATOR = PREFIX+'';
    static inline var NO_ERROR = PREFIX+'';
  #end

  static var ASYNC_CALL;
  static var PARALLEL_CALL;
  static var ASYNC_PASSTHROUGH;
  static var LOOP;
  static var AFTER_LOOP;
  static var AFTER_BRANCH;
  static var ERROR:ExprDef;
  static var CALLBACK;

  static var NULL:ExprDef;
  static var ZERO:ExprDef;
  static var TRUE:ExprDef;
  static var FALSE:ExprDef;

  static function __init__(){
    NULL = 'null'.ident();
    ZERO = EConst(CInt('0'));
    TRUE = 'true'.ident();
    FALSE = 'false'.ident();

    ASYNC_CALL = ASYNC_CALL_FUN.ident();
    PARALLEL_CALL = PARALLEL_CALL_FUN.ident();
    ASYNC_PASSTHROUGH = ASYNC_PASSTHROUGH_FUN.ident();
    LOOP = LOOP_FUN.ident();
    AFTER_LOOP = AFTER_LOOP_FUN.ident();
    AFTER_BRANCH = AFTER_BRANCH_FUN.ident();
    ERROR = ERROR_NAME.ident();
    CALLBACK = CALLBACK_FUN.ident();

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

  inline function processAsyncCall(realFunc:Expr, args:Array<Expr>, asyncParams:Array<Expr>){
    async = true;
    var oldPos = Macro.getPos();
    realFunc.pos.set();
    var cbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
    var assigns = [];
    for(par in asyncParams){
      var ident;
      switch(par.expr){
        case EArrayDecl(vals):
          if(vals.length == 1){
            ident = PREFIX+assigns.length;
            assigns.push(vals[0]);
          }
          else{
            throw 'error';
          }
        default:
          ident = par.extractIdent();
      }
      cbArgs.push({name:ident, type:null, opt:false, value:null});
    }
    var newLines = [];
    var fun = makeErrorFun(null, newLines, ebCall(ERROR.p()) );
    args.push(fun);
    var i = assigns.length;
    while(i --> 0){
      newLines.push(EBinop(OpAssign, assigns[i], (PREFIX+i).ident().p()).p());
    }
    lines.push(realFunc);
    jumpIn(newLines, asyncParams.length == 0 ? fun : null);
    oldPos.set();
  }

  inline function ebCall(arg:Expr){
    var expr = EThrow(arg).p();
    repsThrow.push(expr);
    return expr;
  }

  inline function processParallelCall(parallels:Array<{ids:Array<String>, fun:Expr}>){
    switch(parallels.length){
      case 0: //TODO show warning
      case 1: //TODO process as single async call
      default:
        //TODO check our vars dont overlap with what we use in calls
        var parallelCounterN = PARALLEL_COUNTER+gen(), afterParallelN = AFTER_PARALLEL+gen();
        var parallelCounterI = parallelCounterN.ident(), afterParallelI = afterParallelN.ident();
        var vars = [];
        var idsUsed = new Hash();
        for(par in parallels){
          for(id in par.ids){
            if(idsUsed.exists(id)){
              throw 'double id'; //TODO
            }
            else{
              idsUsed.set(id, true);
              //~ vars.push({name:id, expr:null, type:null});
              vars.push({name:id, expr:NULL.p(), type:null});
            }
          }
        }
        lines.push(EVars(vars).p()); //TODO position
        lines.push(singleVar(parallelCounterN, EConst(CInt(''+parallels.length)).p()));

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
        for(par in parallels){
          var lcbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
          var lcbLines = [];
          for(id in par.ids){
            lcbArgs.push({ name: '_'+id, type: null, opt: false, value: null });
            lcbLines.push(EBinop(OpAssign, id.ident().p(), ('_'+id).ident().p()).p());
          }
          lcbLines.push(afterParallelI.p().call([ERROR.p()]).p());
          var lcb;
          if(par.ids.length == 0){
            lcb = AFTER_PARALLEL.ident().p();
          }
          else{
            var lcbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
            var lcbLines = [];
            for(id in par.ids){
              lcbArgs.push({ name: '_'+id, type: null, opt: false, value: null });
              lcbLines.push(EBinop(OpAssign, id.ident().p(), ('_'+id).ident().p()).p());
            }
            lcbLines.push(ECall(afterParallelI.p(), [ERROR.p()]).p());
            lcb = EFunction(null, {
              args: lcbArgs,
              expr: EBlock(lcbLines).p(),
              params: [],
              ret: null,
            }).p();
          }
          switch(par.fun.expr){
            case ECall(_, args):
              args.push(lcb);
              lines.push(par.fun);
            default: throw 'not a function call';
          }
        }
        lines = newLines;
    }
  }

  inline function processAsyncRawCall(realFunc:Expr, args:Array<Expr>, asyncParams:Array<Expr>){
    async = true;
    var oldPos = Macro.getPos();
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
    oldPos.set();
  }

  inline function extractRealFunc(args:Array<Expr>){
        var idx = args.length-1;
        var arg = args[idx];
        return switch(arg.expr){
          case EBinop(op, realArg, fun):
            if(op == OpLte){ //1+ return
              args[idx] = realArg;
              fun;
            }
            else{
              throw 'unknown shit(bad op)';
              null;
            }
          default: // no returns
            args.pop();
        }
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

  public function new(parent:Flow){
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

  public inline function expr(){
    //~ return (root.length == 1) ? root[0] : EBlock(root).p();
    return EBlock(root).p();
  }

  inline function replaceLoop(ebreak, econt){
    for(e in repsBreak) e.expr = ebreak;
    for(e in repsContinue) e.expr = econt;
  }

  inline function replaceReturn(ereturn, ethrow){
    for(e in repsReturn) e.expr = ereturn;
    for(e in repsThrow) e.expr = ethrow;
  }


  static inline function singleVar(name, val){
    return EVars([{name:name, type:null, expr:val}]);
  }

  inline function closed() return !open

  public function process(isrc:Expr){
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
          if(id == ASYNC_CALL_FUN && args.length != 0){
            async = true;
            var calls = [];
            var ids = [];
            for(arg in args){
              switch(arg.expr){
                case EBinop(op, left, right):
                  switch(op){
                    case OpLt, OpLte:
                      ids.push(left);
                      calls.push({ids:ids, fun:right});
                      ids = [];
                    default:
                      throw 'unknown shit(bad op)';
                  }
                case ECall(_,_):
                  calls.push({ids:[], fun:arg});
                  ids = [];
                case EConst(_):
                  ids.push(arg);
                default:
                  throw 'error';
              }
            }
            for(call in calls){
              switch(call.fun.expr){
                case ECall(_, callArgs): processAsyncCall(call.fun, callArgs, call.ids);
                default: throw 'not a function call';
              }
            }
          }
          else if(id == PARALLEL_CALL_FUN){
            var parallels = [];
            var ids = [];
            for(arg in args){
              switch(arg.expr){
                case EBinop(op, left, right):
                  switch(op){
                    case OpLte:
                      ids.push(left.extractIdent());
                      parallels.push({ids:ids, fun:right});
                      ids = [];
                    default:
                      throw 'unknown shit(bad op)';
                  }
                case ECall(_,_):
                  parallels.push({ids:[], fun:arg});
                  ids = [];
                case EConst(_):
                  ids.push(arg.extractIdent());
                default:
                  throw 'error';
              }
            }
            processParallelCall(parallels);
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
            lines.push(EFor(iter, flow.expr()).p());
          }
          else{
            async = true;
            var loopN = LOOP_FUN+gen(), afterLoopN = AFTER_LOOP_FUN+gen(), iteratorN = ITERATOR+gen();
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
              default: throw 'error';
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
            lines.push(EWhile(econd, flow.expr(), normal).p());
          }
          else{
            async = true;
            var loopN = LOOP_FUN+gen(), afterLoopN = AFTER_LOOP_FUN+gen();
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
            var afterIfN = AFTER_IF+gen();
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
            lines.push(EIf(econd, ftrue.expr(), efalse == null ? null : ffalse.expr()).p());
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
          //~ //var values : Array<Expr>;
          //~ //@:optional var guard : Null<Expr>;
          //~ //var expr: Expr;
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
          if(asyncs == 0){
            lines.push(line);
          }
          else{
            async = true;
            var afterSwitchN = AFTER_SWITCH+gen();
            var afterSwitchI = afterSwitchN.ident();
            var newLines = [];
            lines.push(makeNoargFun(afterSwitchN, EBlock(newLines).p()));
            for(flow in states){
              flow.finalize(afterSwitchI.p().call([]).p());
            }
            var i = cases.length;
            while(i --> 0){
              cases[i].expr = EBlock(states[i].root).p();
            }
            lines.push(ESwitch(e, cases, edef == null ? null : EBlock(states[states.length - 1].root).p()).p());
            lines = newLines;
          }
        }

        case ETry(expr, catches):{
          var afterTryN = AFTER_TRY+gen(), afterCatchN = AFTER_CATCH+gen();
          var afterTryI = afterTryN.ident(), afterCatchI = afterCatchN.ident();
          var prevPos = Macro.getPos();
          var flow = mkTry(expr);
          prevPos.set();
          if(flow.async){
            async = true;

            var newLines = [];
            lines.push(makeErrorFun(afterCatchN, newLines, ebCall(ERROR.p())));

            for(thr in flow.repsThrow){
              switch(thr.expr){
                case EThrow(e): thr.expr = ECall(afterTryI.p(), [e]);
                default: throw 'shouldnt happen';
              }
            }

            for(cat in catches){
              var cflow = mkFlow(cat.expr);
              cflow.finalize(EBinop(OpAssign, ERROR.p(), NULL.p()).p());
              //~ if(cflow.open){
                //~ cflow.lines.push(EBinop(OpAssign, ERROR.p(), NULL.p()).p());
              //~ }
              cat.expr = cflow.expr();
            }

            if(!haveCatchAll(catches)){ // catch all
              catches.push({name:ERROR_NAME, type:TPath({name:'Dynamic', pack:[], params:[]}), expr:
                ebCall(ERROR.p())
              });
            }
            lines.push(EFunction(afterTryN, {
              args: [{name:ERROR_NAME, type:null, opt:false}],
              expr: EBlock([
                EIf(
                  EBinop(OpNotEq, ERROR.p(), NULL.p()).p(),
                  ETry( EThrow(ERROR.p()).p(), catches ).p(),
                  null
                ).p(),
                EIf(
                  EBinop(OpEq, ERROR.p(), NULL.p()).p(),
                  ECall(afterCatchI.p(), [NULL.p()]).p(),
                  null
                ).p(),
              ]).p(),
              ret: null,
              params: [],
            }).p());
            if(flow.open) flow.lines.push(afterTryI.p().call([NULL.p()]).p());
            for(nline in flow.root) lines.push(nline);
            jumpIn(newLines);
          }
          else{
            if(haveCatchAll(catches)){
              lines.push(line);
            }
            else{

              catches.push({
                name:ERROR_NAME,
                type:TPath({name:'Dynamic', pack:[], params:[]}),
                expr: EBlock([
                  EBinop(OpAssign, NO_ERROR.ident().p(), FALSE.p()).p(),
                  ebCall(ERROR.p()),
                ]).p(),
              });
              var newLines = [];

              lines.push(EVars([{name:NO_ERROR, type:null, expr:TRUE.p()}]).p());
              lines.push(line);
              lines.push(EIf(NO_ERROR.ident().p(), EBlock(newLines).p(), null).p());
              lines = newLines;

            }
            //~ trace('sync try expr');
            //TODO
          }
        }

        default: lines.push(line);
      }
    }
    return this;
  }
}

