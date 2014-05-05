
import '../lib/instantrpc_client.dart';

void sleep(num delay) {
  
  if (true) return ;
  
  int init = new DateTime.now().millisecondsSinceEpoch ;

  while (true) {
    int now = new DateTime.now().millisecondsSinceEpoch ;
    
    if ( now - init >= delay ) return ;
  }
  
}


///////////////////////////

class FooDataProviderServer implements FooDataProviderInterface {

  Future<String> getName(String userID) {
    return new Future<String>.microtask( () => _getName(userID) ) ;
  }
  
  String _getName(String userID) {
    // .........
    String name = 'fulano' ;
    // ....
    return name ;
  }

}


abstract class FooDataProviderInterface {
  
  Future<List<String>> getNames(List<String> userIDs) ;
  
  Future<String> getName(String userID) ;
  
  Future<String> getPhoto(String userID, { bool small }) ;
  
  void foo() ;
  
  Future<String> bar() ;
  
  String noAsync() ;
  
}

@proxy
class TestProxy extends IRPCProxy implements FooDataProviderInterface { }

void main() {
  
  print('---------------------------------------------------------------------');
  
  if (true) {
     
    InstantRPC ddp = new InstantRPC<FooDataProviderInterface>('http://localhost:8080/ddptest/', TestProxy, new IRPCRequesterClient() ) ;
    
    print('>>>> $ddp') ;
    
    ddp.call.foo() ;
    
    ddp.call.getNames( ['u1' , 'u2' , 'u3'] ) ;
    
    ddp.call.getName('user123') ;
    
    ddp.call.getPhoto('user123', small: false) ;
    
    Future<String> ret = ddp.call.bar() ;
    ret.then( (v) => print('bar ret: $v') ) ;
    
    Future<String> ret2 = ddp.callDynamic(#bar, []) ;
    ret2.then( (v) => print('bar ret2: $v') ) ;
    
    /*
    String barRet = ddp.call.bar() ;
    
    print('bar ret: $barRet') ;
    
    Future ret = ddp.async( #bar , [] ) ;
    
    print('future to wait: $ret') ;
    
    ret.then( (v) => print('future: $v')  ) ;
    */
    
    return ;
  }
  
  /*
  if (true) {
    
    FooDataProvider t = new TestProxy() ;
    
    t.getName('123') ;
    
    t.foo() ;
    
    return ;
  }
  */
  
  /*
  DistributedDataProvider ddp = new DistributedDataProvider("") ;
  
  InstanceMirror im = reflect( ddp ) ;
  
  im.invoke(#foo, []) ;
  
  ClassMirror cm = im.type ;
  */
  
  /*
  ClassMirror cm = reflectClass( DistributedDataProviderInterface ) ;
  
  Map<Symbol , MethodMirror> members = cm.instanceMembers ;
  
  for( Symbol member in members.keys ) {
    MethodMirror val = members[member] ;
    
    String name = MirrorSystem.getName( member ) ;
    
    if ( val.isRegularMethod ) {
      print(">> $member >> $name >> $val") ;  
    }
    
    
  }
  */
  
}

