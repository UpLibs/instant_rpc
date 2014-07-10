
//import 'package:InstantRPC:instantrpc_client.dart'

import '../lib/instantrpc_client.dart';

import 'testirpc-commons.dart';

class TestProxy extends IRPCProxy implements FooInterface { }

void test1( InstantRPC<FooInterface> irpc ) {
  
  Future<String> ret = irpc.call.test(10, 1.1, 't1', check: true, name: 'joe', id: 'u1') ;
  ret.then((v) {
    print('returned value: $v') ;
    
    test2(irpc) ;
  }) ;
 
  
}

void test2( InstantRPC<FooInterface> irpc ) {
    
  Future<int> ret2 = irpc.call.test2(20, 2.2) ;
  ret2.then((v) => print('returned value2: $v') ) ;


  Future<double> ret3 = irpc.call.test3(10, 2.2, [1,2] , {'a':1 , 'b': 2}) ;
  ret3.then((v) => print('returned value3: $v') ) ;
    
    
  Future.wait( [ ret2 , ret3 ] ).then( (l) {
    print('wait ret> $l') ;
    irpc.call.test4(10) ;  
  } ) ;
  
  
  irpc.call.test4(20) ;
  
  irpc.call.test4(30) ;
  
  irpc.call.test4(40) ;
  
  String longString = 'a' ;
  
  while (longString.length < 1024*32) {
    longString += longString.length.toString() ;
  }
  
  irpc.call.testLongString(longString) ;
  
  irpc.listenToEvent( (e) {
    print("LISTEN EVENT>> $e") ;
  } ) ;
  
  irpc.listenToEventType( 'test', (e) {
    print("LISTEN EVENT TYPE TEST>>>>>>>>>>>>>>>>>>>>>>>>> $e") ;
  } ) ;
  
  irpc.updateEvents() ;
  
}

main() {

  InstantRPC irpc = new InstantRPC<FooInterface>('http://127.0.0.1:8181/foo', TestProxy, new IRPCRequesterClient() ) ;
   
  test1(irpc) ;
  
}

