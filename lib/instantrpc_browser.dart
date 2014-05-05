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
  
}





