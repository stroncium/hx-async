package async;

import haxe.macro.Expr;
import haxe.macro.Context;

using async.tools.Macro;
using async.tools.Various;
import async.tools.Macro;

private typedef State = {
  rootLines: Array<Expr>,
  lines: Array<Expr>,
  async: Bool,
  open: Bool,
  addEbArgs: Array<Expr>,
  ebCallArgsArray: Array<Array<Expr>>,
  loopBreaks: Array<{a:Array<Expr>, p:Int}>,
  loopConts: Array<{a:Array<Expr>, p:Int}>,
};

class Async{

  @:macro
  public static function it(e:Expr):Dynamic{
    switch(e.expr){
      //~ case EFunction(name, data):
      case EFunction(_, data):
        var cbArg = data.args[data.args.length - 1];
        data.expr = syncToAsync(cbArg, data.expr);
      default:
        return e;
    }
    return e;
  }


  #if macro //
  static inline var ASYNC_CALL_FUN = 'async';
  static inline var PARALLEL_CALL_FUN = 'parallel';
  static inline var ASYNC_RAW_FUN = 'asyncr';
  static inline var ASYNC_PASSTHROUGH_FUN = 'asyncPassthrough';
  static inline var LOOP_FUN = 'loop';
  static inline var AFTER_LOOP_FUN = 'afterLoop';
  static inline var AFTER_BRANCH_FUN = 'afterBranch';
  static inline var ERROR_NAME = 'e';
  static inline var CALLBACK_FUN = 'cb';

  static var ASYNC_CALL;
  static var PARALLEL_CALL;
  static var ASYNC_PASSTHROUGH;
  static var LOOP;
  static var AFTER_LOOP;
  static var AFTER_BRANCH;
  static var ERROR;
  static var CALLBACK;

  static var NULL:ExprDef;
  static var ZERO:ExprDef;

  static function __init__(){
    NULL = 'null'.ident();
    ZERO = EConst(CInt('0'));

    ASYNC_CALL = ASYNC_CALL_FUN.ident();
    PARALLEL_CALL = PARALLEL_CALL_FUN.ident();
    ASYNC_PASSTHROUGH = ASYNC_PASSTHROUGH_FUN.ident();
    LOOP = LOOP_FUN.ident();
    AFTER_LOOP = AFTER_LOOP_FUN.ident();
    AFTER_BRANCH = AFTER_BRANCH_FUN.ident();
    ERROR = ERROR_NAME.ident();
    CALLBACK = CALLBACK_FUN.ident();

  }

  static inline function replaceExpressionsWithCalls(arr:Array<{a:Array<Expr>, p:Int}>, ident:ExprDef){
    for(acc in arr){
      var pos = acc.get().pos;
      acc.set(ident.pos(pos).call([]).pos(pos));
    }
  }

  static function convertTree(cbIdent:ExprDef, ghostPos:Position, isrc:Expr, pstate:State, inLoop = false):State{
    var src = switch(isrc.expr){
          case EBlock(blines): blines;
          default: [isrc];
        };
    var lines = [];
    var ebCallArgsArray = pstate.ebCallArgsArray;
    var loopBreaks = inLoop ? [] : pstate.loopBreaks;
    var loopConts = inLoop ? [] : pstate.loopConts;
    var state = {
      rootLines: lines,
      lines: null,
      async: false,
      open: true,
      addEbArgs: pstate.addEbArgs,
      ebCallArgsArray: ebCallArgsArray,
      loopBreaks: loopBreaks,
      loopConts: loopConts,
    };

    inline function trySetupEbArgs(args){
      if(pstate.addEbArgs == null){
          pstate.addEbArgs = [];
        if(args.length > 1){
          for(i in 1...args.length){
            pstate.addEbArgs.push(NULL.pos(ghostPos));
          }
        }
      }
    }

    inline function processAsyncCall(realFunc:Expr, args:Array<Expr>, asyncParams:Array<Expr>){
      state.async = true;
      var oldPos = Macro.getPos();
      realFunc.pos.set();
      var cbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
      for(par in asyncParams) cbArgs.push({
        name:par.extractIdent(),
        type:null,
        opt:false,
        value:null
      });
      var newLines = [];
      var ebArgs = [ERROR_NAME.ident().p()];
      ebCallArgsArray.push(ebArgs); // we'll add nulls and zeros later
      var cb = EFunction(null, {
            args: cbArgs,
            //~ expr: expr(EBlock(newLines), pos),
            expr: EIf(
              EBinop(OpEq, ERROR_NAME.ident().p(), NULL.p()).p(),
              EBlock(newLines).p(),
              cbIdent.p().call(ebArgs).p()
            ).p(),
            params: [],
            ret: null,
          }).p();
      args.push(cb);
      //~ trace(MacroHelpers.dump(realFunc));
      lines.push(realFunc);
      lines = newLines;
      oldPos.set();
    }

    inline function processParallelCall(parallels:Array<{ids:Array<String>, fun:Expr}>){
      switch(parallels.length){
        case 0: //TODO show warning
        case 1: //TODO process as single async call
        default:
          //TODO check our vars dont overlap with what we use in calls
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
          lines.push(EVars([{name:'parallelCounter', type:null, expr: EConst(CInt(''+parallels.length)).p()}]).p());

          var newLines = [];
          var ebArgs = [ERROR_NAME.ident().p()];
          ebCallArgsArray.push(ebArgs); // we'll add nulls and zeros later
          var postParallel = EFunction('afterParallel', {
                args: [{ name: ERROR_NAME, type: null, opt: false, value: null }],
                expr: EIf(
                  EBinop(OpEq, ERROR_NAME.ident().p(), NULL.p()).p(),
                  EIf(
                    EBinop(OpEq, EUnop(OpDecrement, false, 'parallelCounter'.ident().p()).p(), ZERO.p()).p(),
                    EBlock(newLines).p(),
                    null
                  ).p(),
                  EBlock([
                    EBinop(OpAssign, 'parallelCounter'.ident().p(), EConst(CInt('-1')).p()).p(),
                    cbIdent.p().call(ebArgs).p()
                  ]).p()
                ).p(),
                params: [],
                ret: null,
              }).p();

          lines.push(postParallel);
          for(par in parallels){
            var lcbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
            var lcbLines = [];
            for(id in par.ids){
              lcbArgs.push({ name: '_'+id, type: null, opt: false, value: null });
              lcbLines.push(EBinop(OpAssign, id.ident().p(), ('_'+id).ident().p()).p());
            }
            lcbLines.push(
              ECall('afterParallel'.ident().p(), [
                ERROR_NAME.ident().p()
              ]).p()
            );
            var lcb;
            if(par.ids.length == 0){
              lcb = 'afterParallel'.ident().p();
            }
            else{
              var lcbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
              var lcbLines = [];
              for(id in par.ids){
                lcbArgs.push({ name: '_'+id, type: null, opt: false, value: null });
                lcbLines.push(EBinop(OpAssign, id.ident().p(), ('_'+id).ident().p()).p());
              }
              lcbLines.push(
                ECall('afterParallel'.ident().p(), [
                  ERROR_NAME.ident().p()
                ]).p()
              );
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
              //~ case EBlock(blines): //TODO

              default: throw 'not a function call';

            }
          }
          lines = newLines;


      }
      /*
      state.async = true;
      var oldPos = Macro.getPos();
      realFunc.pos.set();
      var cbArgs = [{ name: ERROR_NAME, type: null, opt: false, value: null }];
      for(par in asyncParams) cbArgs.push({
        name:par.extractIdent(),
        type:null,
        opt:false,
        value:null
      });
      var newLines = [];
      var ebArgs = [ERROR_NAME.ident().p()];
      ebCallArgsArray.push(ebArgs); // we'll add nulls and zeros later
      var cb = EFunction(null, {
            args: cbArgs,
            //~ expr: expr(EBlock(newLines), pos),
            expr: EIf(
              EBinop(OpEq, ERROR_NAME.ident().p(), 'null'.ident().p()).p(),
              EBlock(newLines).p(),
              cbIdent.p().call(ebArgs).p()
            ).p(),
            params: [],
            ret: null,
          }).p();
      args.push(cb);
      //~ trace(MacroHelpers.dump(realFunc));
      lines.push(realFunc);
      lines = newLines;
      oldPos.set();
      */
    }

    inline function processAsyncRawCall(realFunc:Expr, args:Array<Expr>, asyncParams:Array<Expr>){
      state.async = true;
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

    var sources = [{src:src, pos:0}];
    var pos, len, run = true;

    //~ while(sources.length > 0 && run){
      //~ var tmp = sources.pop();
      //~ src = tmp.src;
      //~ pos = tmp.pos;
      pos = 0;
      len = src.length;
      while(pos < len && run){
        var line = src[pos++];
        line.pos.set();

        switch(line.expr){
          //~ case EBlock(blines):{
            //~ sources.push({src:src, pos:pos});
            //~ src = blines;
            //~ pos = 0;
            //~ len = src.length;
          //~ }

          case ECall(func, args):{
            var id = func.extractIdent();
            if(id == ASYNC_CALL_FUN && args.length != 0){
              var calls = [];
              var ids = [];
              for(arg in args){
                switch(arg.expr){
                  case EBinop(op, left, right):
                    switch(op){
                      case OpLte:
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
                  //~ case ECall(func, callArgs): processAsyncCall(realFunc, callArgs, args);
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
            else lines.push(line);
          }

          case EIf(econd, etrue, efalse):{
            var tstate = convertTree(cbIdent, ghostPos, etrue, state);
            if(efalse == null){
              if(tstate.async) state.async = true;
              if(tstate.open){
                if(tstate.async){
                  var contlines = [];
                  var contName = AFTER_BRANCH_FUN;
                  var cont = EFunction(contName, {
                        expr: EBlock(contlines).p(),
                        args: [],
                        ret: null,
                        params: [],
                      }).p();
                  lines.push(cont);
                  lines.push(EIf(econd, EBlock(tstate.rootLines).p(), contName.ident().p().call([]).p()).p());
                  tstate.lines.push(contName.ident().p().call([]).p());
                  lines = contlines;
                }
                else{
                    lines.push(EIf(econd, EBlock(tstate.rootLines).pos(etrue.pos), null).p());
                }
              }
              else{
                var newlines = [];
                var newif = EIf(econd, EBlock(tstate.rootLines).p(), EBlock(newlines).p()).p();
                lines.push(newif);
                lines = newlines;
              }
            }
            else{
              var fstate = convertTree(cbIdent, ghostPos, efalse, state);

              if(tstate.async || fstate.async) state.async = true;
              if(tstate.open == fstate.open){
                if(tstate.open){
                  if(tstate.async || fstate.async){
                    var contlines = [];
                    var contName = AFTER_BRANCH_FUN;
                    var cont = EFunction(contName, {
                          expr: EBlock(contlines).p(),
                          args: [],
                          ret: null,
                          params: [],
                        }).p();
                    lines.push(cont);
                    lines.push(EIf(econd,
                      EBlock(tstate.rootLines).p(),
                      EBlock(fstate.rootLines).p()
                    ).p());
                    tstate.lines.push(contName.ident().p().call([]).p());
                    fstate.lines.push(contName.ident().p().call([]).p());
                    lines = contlines;
                  }
                  else{
                    lines.push(EIf(econd, EBlock(tstate.rootLines).pos(etrue.pos), EBlock(tstate.rootLines).pos(efalse.pos)).p());
                  }
                }
                else{
                  lines.push(EIf(econd, EBlock(tstate.rootLines).pos(etrue.pos), EBlock(tstate.rootLines).pos(efalse.pos)).p());
                  state.open = false;
                  run = false;
                  break;
                }
              }
              else{
                lines.push(EIf(econd, EBlock(tstate.rootLines).p(), EBlock(fstate.rootLines).p()).p());
                lines = (tstate.open ? tstate : fstate).lines;
              }
            }
          }

          case EWhile(econd, expr, normal):{
            var nstate = convertTree(cbIdent, ghostPos, expr, state, true);
            if(nstate.async){
              state.async = true;
              //~ if(nstate.open){ //TODO closed async loop, isnt actually loop
                var loopIdent = LOOP_FUN.ident();
                var afterLoopIdent = AFTER_LOOP_FUN.ident();
                var afterLoopLines = [];
                var loopExpr = if(normal){
                      nstate.lines.push(loopIdent.p().call([]).p());
                      //~ EIf(econd,
                        //~ EBlock(nstate.rootLines).p(),
                        //~ afterLoopIdent.p().call([]).p()
                      //~ ).p();
                      EBlock([EIf(econd,
                        EBlock(nstate.rootLines).p(),
                        afterLoopIdent.p().call([]).p()
                      ).p()]).p();
                    }
                    else{
                      nstate.lines.push(EIf(econd,
                        loopIdent.p().call([]).p(),
                        afterLoopIdent.p().call([]).p()
                      ).p());
                      EBlock(nstate.rootLines).p();
                    };
                var loop = EFunction(LOOP_FUN, {
                      expr: loopExpr,
                      args: [],
                      ret: null,
                      params: [],
                    }).p();
                var afterLoop = EFunction(AFTER_LOOP_FUN, {
                      expr: EBlock(afterLoopLines).p(),
                      args: [],
                      ret: null,
                      params: [],
                    }).p();
                lines.push(afterLoop);
                lines.push(loop);
                lines.push(loopIdent.p().call([]).p());
                lines = afterLoopLines;
                replaceExpressionsWithCalls(nstate.loopBreaks, afterLoopIdent);
                replaceExpressionsWithCalls(nstate.loopConts, loopIdent);
              //~ }
              //~ else{
              //~ }
            }
            else{
              if(nstate.open){
                lines.push(line);
              }
              else{
                //TODO
              }
            }
          }

          case EBreak:{
            loopBreaks.push(lines.accessor(lines.length));
            lines.push(line);
            state.open = false;
            run = false;
            break;
          }

          case EContinue:{
            loopConts.push(lines.accessor(lines.length));
            lines.push(line);
            state.open = false;
            run = false;
            break;
          }

          case EReturn(e):{
            var retArgs =
              (e == null) ?
                [NULL.p()] :
                switch(e.expr){
                  case ECall(func, args):
                    if(func.extractIdent() == 'many'){
                      args.unshift(NULL.p());
                      args;
                    }
                    else [NULL.p(), e];
                  default: [NULL.p(), e];
                };
            trySetupEbArgs(retArgs);
            lines.push(cbIdent.p().call(retArgs).p());
            state.open = false;
            run = false;
            break;
          }

          case EThrow(e):{
            var ebArgs = [e];
            ebCallArgsArray.push(ebArgs); // we'll add nulls and zeros later
            lines.push(cbIdent.p().call(ebArgs).p());
            state.open = false;
            run = false;
            break;
          }

          default: lines.push(line);
        }
      }

    //~ }

    state.lines = lines;
    return state;
  }

  static function syncToAsync(cbArg:FunctionArg, e:Expr){
    var ebCallArgsArray = [];
    var addEbArgs = null;
    //~ trace(cbArg);
    if(cbArg.type != null){
      addEbArgs = [];
      switch(cbArg.type){
        case TFunction(args, _):
          var first = true;
          for(arg in args){
            if(first) first = false;
            else{
              addEbArgs.push((switch(arg){
                case TPath(path): (path.name == 'Int' && path.pack.length == 0) ? ZERO : NULL;
                default: NULL;
              }).pos(e.pos));
            }
          }
        default:
      }
    };

    //~ var lines =  switch(e.expr){
          //~ case EBlock(blines): blines;
          //~ default: [e];
        //~ };
    var state = {
      rootLines: null,
      lines: null,
      async: false,
      open: true,
      addEbArgs: addEbArgs,
      ebCallArgsArray: ebCallArgsArray,
      loopBreaks: [],
      loopConts: [],
    };
    var cbIdent = cbArg.name.ident();

    var newstate = convertTree(
          cbIdent,
          e.pos,
          e,
          state
        );
    if(newstate.open){
      newstate.open = false;
      var args = [NULL.pos(e.pos)];
      var cb = cbIdent.pos(e.pos).call(args).pos(e.pos);
      newstate.lines.push(cb);
      ebCallArgsArray.push(args);
    }

    if(state.addEbArgs != null){
      for(args in ebCallArgsArray){
        for(arg in state.addEbArgs) args.push(arg);
      }
    }

    return EBlock(newstate.rootLines).pos(e.pos);
    //~ return switch(newstate.rootLines.length){
      //~ case 0: [].block().pos(e.pos);
      //~ case 1: newstate.rootLines[0];
      //~ default: newstate.rootLines.block().pos(e.pos);
    //~ };
  }

  static function convertClassFunction(fun:Function, whole){
    if(whole){
      var cbArg = fun.args[fun.args.length - 1];
      var newexpr = syncToAsync(cbArg, fun.expr);
      fun.expr = newexpr;
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
