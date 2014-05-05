
import 'dart:io' ;

import '../lib/instantrpc_server.dart';

import 'testirpc-commons.dart' ;

void sleep(num delay) {
  
  if (true) return ;
  
  print('sleep $delay...') ;
  
  int init = new DateTime.now().millisecondsSinceEpoch ;

  while (true) {
    int now = new DateTime.now().millisecondsSinceEpoch ;
    
    if ( now - init >= delay ) return ;
  }
  
}


class FooInstantiator implements IRPCDataProviderInstantiator<Foo> {
  
  static Foo _instante ;
  
  @override
  Foo instantiate() {
    if ( _instante == null ) {
      print('-- create foo instante!') ;
      _instante = new Foo() ;
    }
    else {
      print('-- reuse foo instante!') ;
    }
    return _instante ;
  }
  
}

class Foo implements FooInterface {
  
  Stream<List<int>> stream ;
  
  Foo() {
    stream = new File('/tmp/lsof.txt').openRead();
  }
  
  Future<String> test( int a , double b , String c , { bool check: false , String name: 'foo' , String id} ) {
    
    IRPCEventTable.getCurrentEventTable().addEvent('test') ;
    
    print('TEST>> $a > $b > $c > check: $check > name: $name > id: $id') ;
    sleep(10001) ;
    print('TEST>> end') ;
    return new Future.value('called test') ;
  }
  
  Future<int> test2( int a , double b , [String c = 'moh' , String d]) {
    
    IRPCEventTable.getCurrentEventTable().addEvent('test2') ;
    
    print('TEST2>> $a > $b > $c > $d') ;
    sleep(10002) ;
        print('TEST2>> end') ;
    return new Future.value(123) ;
  }
  
  Future<double> test3( int a , double b , List l , Map m) {
    
    IRPCEventTable.getCurrentEventTable().addEvent('test3') ;
    
    print('TEST3>> $a > $b > $l > $m') ;
    return new Future.value(3.333) ;
  }
  
  void test4(int a) {
    
    IRPCEventTable.getCurrentEventTable().addEvent('test4') ;
    
    IRPCSession session = IRPCSession.getCurrentSession() ;
    
    if ( session['count'] == null ) {
      session['count'] = 1 ;
    }
    else {
      session['count']++ ;
    }
    
    print('TEST4>> $a >> count: ${ session['count'] }') ;
  }
  
}

main() {
  
  var dataProvider = new FooInstantiator() ;
  
  IRPCHTTPDaemon httpd = new IRPCHTTPDaemon(8181) ;
  
  httpd.registerDataProvider('/foo', dataProvider) ;
  
  httpd.start() ;
  
}
