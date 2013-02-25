package async.tools;

private typedef Access<T> = {a:Array<T>, p:Int};
class Various{
  public static inline function accessor<T>(a:Array<T>, p:Int) return {a:a, p:p};
  public static inline function get<T>(a:Access<T>) return a.a[a.p];
  public static inline function set<T>(a:Access<T>, v:T) a.a[a.p] = v;
}
