
import 'dart:async' ;

abstract class FooInterface {
  
  Future<String> test( int a , double b , String c , { bool check: false , String name: 'foo' , String id} ) ;
  
  Future<int> test2( int a , double b , [String c = 'moh' , String d]) ;
  
  Future<double> test3( int a , double b , List l , Map m) ;
  
  void test4( int a ) ;
  
  void testLongString( String longString ) ;
  
}
