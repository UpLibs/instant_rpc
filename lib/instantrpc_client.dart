library DistributedDataProvider.client ;

import 'dart:async' ;
import 'dart:io';
import 'dart:convert' ;

import 'dart:math' as Math ;

import 'instantrpc_core.dart' ;
export 'instantrpc_core.dart' ;

export 'dart:async' ;

class IRPCRequesterClient extends IRPCRequester {
  
  HttpClient httpClient ;
  
  IRPCRequesterClient() {
    httpClient = new HttpClient() ;
  }
  
  Future<String> getURL(Uri url) {
      return httpClient.getUrl(url)
        .then( (HttpClientRequest request) => _processRequest(request) )
          .then( (HttpClientResponse response) => _processResponse(response) );
  }
  
  Future<String> getURLPost(Uri url, Map<String,String> postParams) {
      return httpClient.openUrl('POST' , url)
        .then( (HttpClientRequest request) => _processRequestPost(request, postParams) )
          .then( (HttpClientResponse response) => _processResponse(response) );
  }
  
  void _setRequestCookies(HttpClientRequest request) {

    for ( Cookie c in _cookies ) {
      request.cookies.add( new Cookie(c.name, c.value) ) ;
    }
    
  }
  
  Future<HttpClientResponse> _processRequest( HttpClientRequest request ) {
    _setRequestCookies(request) ;
    
    return request.close() ;
  }
  
  static Math.Random rand = new Math.Random() ;
  
  String _createBoundary() {
    String boundary = '------------------------' ;
    for (int i = 0 ; i < 20 ; i++) {
      boundary += rand.nextInt(10).toString() ;
    }
    return boundary ; 
  }
  
  Future<HttpClientResponse> _processRequestPost( HttpClientRequest request , Map<String,String> postParams ) {
    _setRequestCookies(request) ;
    
    String boundary = _createBoundary() ;
    
    String body = "" ;
    
    for (String key in postParams.keys) {
      String val = postParams[key] ;
      
      body += "$boundary\r\n" ;
      body += 'Content-Disposition: form-data; name="$key"\r\n' ;
      body += 'Content-Type: text/plain\r\n' ;
      body += '\r\n' ;
      
      body += val ;
      body += '\r\n' ;
    }
    

    body += "$boundary--\r\n" ;
    

    request.headers.contentType = ContentType.parse('multipart/form-data; charset=UTF-8"; boundary=$boundary') ;
    request.headers.contentLength = body.length ;
    
    request.add(body.codeUnits) ;
    
    return request.close() ;
  }
  
  List<Cookie> _cookies = [] ;
  
  void _updateCookies( List<Cookie> cookies ) {
    for ( Cookie c in cookies ) {
      _updateCookie(c) ;
    }
  }
  
  void _updateCookie( Cookie cookie ) {
    
    for ( Cookie c in _cookies ) {
    
      if ( c.name == cookie.name ) {
        
        _cookies.remove(c) ;
        _cookies.add(cookie) ;
        
        return ;
      }
      
    }
    
    _cookies.add(cookie) ;
  }
  
  Future<String> _processResponse(HttpClientResponse response) {
    if (response == null) return null ;
    
    _updateCookies(response.cookies) ;
    
    HttpHeaders header = response.headers ;
    
    String chartSet = header.contentType != null ? header.contentType.charset : null ;
  
    if (chartSet == null) {
      return response.transform( LATIN1.decoder ).join() ;
    }
    
    chartSet = chartSet.toUpperCase() ;
    
    if ( chartSet == 'ISO-8859-1' || chartSet == 'LATIN-1') {
      return response.transform( LATIN1.decoder ).join() ;
    }
    else if ( chartSet == 'UTF-8' ) {
      return response.transform( UTF8.decoder ).join() ;
    }
    else if ( chartSet == 'US-ASCII' || chartSet == 'ASCII' ) {
      return response.transform( ASCII.decoder ).join() ;
    }
    else {
      return response.transform( LATIN1.decoder ).join() ;
    }
    
  }
  
  Future<String> doRequestSimple(Uri url) {
    return getURL(url) ;
  }
  
  Future<String> doRequestComplex(IRPCRequest request) {
    
    if (request.methodPost) {
      return getURLPost(request.url, request.postParams) ; 
    }
    else {
      return getURL(request.url) ;  
    }
    
  }
  
}





