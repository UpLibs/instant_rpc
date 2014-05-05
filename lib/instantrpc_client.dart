library DistributedDataProvider.client ;

import 'dart:async' ;
import 'dart:io';
import 'dart:convert' ;

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
  
  Future<HttpClientResponse> _processRequest( HttpClientRequest request ) {
    
    for ( Cookie c in _cookies ) {
      request.cookies.add( new Cookie(c.name, c.value) ) ;
    }
    
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
  
  Future<String> doRequest(Uri url) {
    return getURL(url) ;
  }
  
}





