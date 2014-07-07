library DistributedDataProvider.browser ;

import 'dart:async' ;
import 'dart:html';

import 'instantrpc_core.dart' ;
export 'instantrpc_core.dart' ;

export 'dart:async' ;

class IRPCRequesterBrowser extends IRPCRequester {
  
  Future<String> doRequest(Uri url) {
    return HttpRequest.getString(url.toString()) ;
  }
  
  Future<String> doRequestComplex(IRPCRequest request) {
    
    if (request.methodPost) {
      return HttpRequest.postFormData(request.url.toString() , request.postParams).then((xhr) => xhr.responseText) ;
    }
    else {
      return HttpRequest.getString(request.url.toString()) ;  
    }
    
  }
  
}





