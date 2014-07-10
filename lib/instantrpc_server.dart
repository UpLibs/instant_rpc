library DistributedDataProvider.server ;

import 'package:worker/worker.dart' ;

import 'dart:io' ;
import 'dart:async' ;

import 'instantrpc_core.dart' ;
export 'instantrpc_core.dart' ;

export 'dart:async' ;

class IRPCHTTPDaemon {
  
  int _listen ;
  String _addressMask ;
  
  IRPCResponder _responder ;
  
  HttpServer _server ;
  
  Worker _worker ;
  
  bool _multiThread = true ;
  
  IRPCHTTPDaemon( this._listen , [ this._addressMask = '0.0.0.0' , this._responder ] ) {
     
    if ( this._responder == null ) this._responder = new IRPCResponder() ;
  
    this._worker = new Worker(poolSize: 100, spawnLazily: true);
  }

  IRPCResponder get responder => _responder ;
  
  Map<String, dynamic> _dataProviders = {} ;
  
  Map<String, dynamic> get dataProviders => _dataProviders ;
  
  void clearRegisteredDataProviders() {
    _dataProviders.clear() ;
  }
  
  void unregisterDataProvider(String path) {
    _dataProviders.remove(path) ;
  }
  
  void registerDataProvider(String path , dynamic dataProvider) {
    _dataProviders[path] = dataProvider ;
  }
  
  void start() {

    HttpServer.bind(_addressMask , _listen).then(
        (server) {
          print('** Started ${ this.runtimeType } at port $_listen...') ;
          
          server.listen( _processRequest );
        }
        ,
        onError: (e) {
          print('** $e') ;
        }
    );
    
    
   
  }
  
  IRPCEventTable _getEventTable( HttpRequest request ) {
    IRPCEventTable eventTable = request.session[SESSION_IRPC_EVENT_TABLE] ;
    
    if (eventTable == null) {
      eventTable = new IRPCEventTable() ;
      request.session[SESSION_IRPC_EVENT_TABLE] = eventTable ;
    }
    
    return eventTable ;
  }
  
  void _processEventTableUpdate( HttpRequest request , int lastEventId ) {
    IRPCEventTable eventTable = _getEventTable(request) ;
    
    eventTable.consumeUntilEventID(lastEventId) ;
    
    request.response.write( eventTable.toString() ) ;

    request.response.close() ;
  }
  
  static const String SESSION_IRPC_EVENT_TABLE = '__IRPC_EVENT_TABLE__';
  
  void _processRequest( HttpRequest request ) {
    Uri uri = request.uri ;
    
    if (request.method == 'POST') {
      //print('PROCESS REQUEST POST> $uri > ${ request.connectionInfo.remoteAddress }') ;

      request.listen((List<int> buffer) {
        String postData = new String.fromCharCodes(buffer) ;
        
        Map<String,String> postParams = _parsePostData(request, postData) ;
        
        //print('POST DATA> $postData > $postParams') ;
        
        _processRequest_FullyReceived(request , uri.path , postParams) ;
      });
    }
    else {
      //print('PROCESS REQUEST> $uri > ${ request.connectionInfo.remoteAddress }') ;

      _processRequest_FullyReceived(request , uri.path , uri.queryParameters) ;
    }
    
  }
  
  List<String> _splitOnce(String s, String delimiter) {
    int i = s.indexOf(delimiter) ;
    return [ s.substring(0 , i) , s.substring(i+delimiter.length) ] ;
  }
  
  Map<String,String> _parsePostData(HttpRequest request, String postData) {
    
    String mimeType = request.headers.contentType.mimeType.toLowerCase() ;
    
    if ( mimeType == 'multipart/form-data' ) {
      return _parsePostData_Multipart(request, postData) ;
    }
    else if ( mimeType == 'application/x-www-form-urlencoded' ) {
      return _parsePostData_UrlEncoded(request, postData) ;
    }
    else {
      throw new ArgumentError("Can't parse POST data of type: $mimeType") ;
    }
  }
  
  Map<String,String> _parsePostData_UrlEncoded(HttpRequest request, String postData) {
    return Uri.splitQueryString(postData) ;
  }
  
  Map<String,String> _parsePostData_Multipart(HttpRequest request, String postData) {
    
    String boundary = request.headers.contentType.parameters['boundary'] ;
    
    List<String> parts = postData.split('$boundary\r\n') ;
    
    parts[ parts.length-1 ] = _splitOnce(parts.last, '$boundary--')[0] ;
    
    Map<String, String> postParams = {} ;
    
    for (String part in parts) {
      if (part.isEmpty) continue ;
      
      List<String> headerAndContent = _splitOnce(part, '\r\n\r\n') ; 
      
      String partHeader = headerAndContent[0] ;
      String content = headerAndContent[1] ;
      
      String contentEnd = content.substring(content.length-2) ;
      
      if (contentEnd == '\r\n') {
        content = content.substring(0, content.length-2) ;
      }
      else {
        throw new FormatException('Content not ending with \\r\\n') ;
      }
      
      List<String> headersLines = _splitOnce(partHeader, '\r\n') ;
      Map<String,String> headers = {} ;

      for (String line in headersLines) {
        List<String> split = _splitOnce(line, ': ') ;
        String name = split[0] ;
        String val = split[1] ;
        headers[name] = val ;
      }
      
      String contentDisp = headers['Content-Disposition'] ;
      
      String fieldName = _splitOnce(contentDisp, 'name=')[1].split(new RegExp('[\'"]'))[1] ;
      
      //print('PART> $fieldName > $headers > <<<$content>>>') ;
      
      postParams[fieldName] = content ;
    }
    
    return postParams ;
  }
  
  void _processRequest_FullyReceived( HttpRequest request , String path , Map<String,String> queryParameters) {
    Uri uri = request.uri ;
    
    List ret = IRPCResponder.parseRequest( path, queryParameters ) ;
    
    String providerPath = ret[0] ;
    String methodName = ret[1] ;
    
    if ( methodName == IRPCRequester.REQUEST_EVENT_UPDATE ) {
      int id = ret[2] ;
      _processEventTableUpdate(request, id) ;
      return ;
    }
    
    List<String> positionalParams = ret[2] ;
    Map<String,String> namedParams = ret[3] ;
    
    int lastEventTableId = ret[4] ;
    
    dynamic dataProvider = _dataProviders[providerPath] ;
    
    if ( dataProvider == null ) {
      request.response.statusCode = 404 ;
      request.response.close() ;
      return ;
    }
    
    ///////////////
    
    List<String> headerOriginList = request.headers['Origin'] ;
    
    String headerOrigin = headerOriginList != null && headerOriginList.isNotEmpty ? headerOriginList[0] : null ;
    
    if (headerOrigin != null && headerOrigin.isNotEmpty ) {
      request.response.headers.set('Access-Control-Allow-Origin' , headerOrigin) ;
    }

    //////////////
    
    IRPCEventTable eventTable = _getEventTable(request) ;
    
    //////////////
    
    _CallTask task = new _CallTask(
        dataProvider ,
        methodName , positionalParams , namedParams ,
        request.session , request.session.id , 
        _multiThread ? eventTable.toString() : eventTable
    ) ;
    
    //Future callRet = _multiThread ? _worker.handle(task) : task.execute() ;
    
    Future callRet = task.execute() ;
    
    callRet.then( (v) {
      
      _CallReturn r = v ;
      
      _CallTask.copyMapTo( r._sessionMap , request.session ) ;
      
      eventTable.update( r.eventTable ) ;
      
      eventTable.consumeUntilEventID(lastEventTableId) ;
      
      String eventTableStr = eventTable.toString() ;
      
      request.response.write("${ eventTableStr.length }\n$eventTableStr\n") ;
      
      if ( r._response != null ) {
        request.response.write( "${r._responseTypeName}\n" ) ;
        request.response.write( r._response ) ;
      }

      request.response.close() ;

    }) ;
    
  }
  
}

class _MyIRPCSession extends IRPCSessionWrapper {
  
  String _id ;
  bool _destroied = false ;
  
  _MyIRPCSession( String id, Map session ) : super( session ) {
    this._id = id ;
  }
  
  @override
  void destroy() {
    _destroied = true ;
  }
  
  @override
  String get id => _id ;
  
}

class _CallReturn {
  
  Map _sessionMap ;
  String _responseTypeName ;
  String _response ;
  
  
  IRPCEventTable _eventTable ;
  String _eventTableStr ;
    
  _CallReturn( this._sessionMap , this._responseTypeName, this._response , dynamic eventTable) {

    if ( eventTable is IRPCEventTable ) {
      this._eventTable = eventTable ;
    }
    else {
      this._eventTableStr = eventTable ;
    }
    
  }
  
  IRPCEventTable get eventTable => this._eventTable != null ? this._eventTable : new IRPCEventTable.string(this._eventTableStr) ;
  
}

class _CallTask implements Task {

  dynamic _dataProvider ;
  String _methodName ; 
  List<String> _positionalParams ;
  Map<String,String> _namedParams ;
  Map _sessionMap ;
  String _sessionId ;
  
  dynamic _eventTable ;
  String _eventTableStr ;
  
  
  _CallTask( this._dataProvider , this._methodName , this._positionalParams , this._namedParams , Map session , String sessionId , dynamic eventTable) {
    this._sessionId = sessionId ;
    this._sessionMap = copyMapTo(session, null) ;
    
    if ( eventTable is IRPCEventTable ) {
      this._eventTable = eventTable ;
    }
    else {
      this._eventTableStr = eventTable ;
    }
  }
  
  IRPCEventTable get eventTable => this._eventTable != null ? this._eventTable : new IRPCEventTable.string(this._eventTableStr) ;
  
  static Map copyMapTo(Map from, Map to) {
    if (to == null) to = {} ;
    
    for ( dynamic k in from.keys ) {
      to[k] = from[k] ;
    }
    
    return to ;
  }
  
  @override
  Future execute() {
    
    dynamic provider ;
    
    if ( _dataProvider is IRPCDataProviderInstantiator ) {
      IRPCDataProviderInstantiator instantiator = _dataProvider ;
      provider = instantiator.instantiate() ;
    }
    else {
      provider = _dataProvider ;
    }
    
    _MyIRPCSession irpcSession = new _MyIRPCSession( _sessionId, _sessionMap ) ;
    
    IRPCEventTable eventTable = this.eventTable ;
    
    IRPCResponderCallMethodReturn callRet = null ;
    try {
      callRet = IRPCResponder.callMethod(provider, _methodName, _positionalParams, _namedParams, irpcSession, eventTable) ;  
    }
    catch( error , trace ) {
      print(error) ;
      print(trace) ;
    }
    
    dynamic returnEventTable = this._eventTable != null ? eventTable : eventTable.toString() ;
    
    
    
    if (callRet.ret != null) {
      return callRet.ret.then((v) => new _CallReturn( _sessionMap , callRet.returnTypeGenericName , v.toString() , returnEventTable ) ) ;
    }
    else {
      return new Future.value( new _CallReturn( _sessionMap , callRet.returnTypeGenericName , null , returnEventTable ) ) ;
    }
     
  }
  
}
