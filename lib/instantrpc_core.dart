library DistributedDataProvider.core ;

import 'dart:mirrors';
import 'dart:async';
import 'dart:convert';

typedef void IRPCEventListener(IRPCEvent event);

class InstantRPC<T> {
  
  Uri _webserviceURI ;
  IRPCRequester _requester ;
  Type _providerType ;
  ClassMirror _providerClassMirror ;
  InstanceMirror _providerInstanceMirror ;
  
  T _provider ;
  
  InstantRPC( dynamic webserviceURL , this._providerType , [ this._requester ] ) {
    
    if ( webserviceURL is Uri ) {
      this._webserviceURI = webserviceURL ;   
    }
    else {
      this._webserviceURI = Uri.parse(webserviceURL.toString()) ;  
    }
    
    this._webserviceURI = new Uri(
        scheme: _webserviceURI.scheme ,
        userInfo: _webserviceURI.userInfo ,
        host: _webserviceURI.host ,
        port: _webserviceURI.port ,
        path: _webserviceURI.path.replaceFirst(new RegExp(r'/*$'), '/') ,
        query: _webserviceURI.query ,
        fragment: _webserviceURI.fragment
    ) ;
    
    ////
    
    _providerClassMirror = reflectClass( _providerType ) ;
    
    if ( _providerClassMirror.superclass.reflectedType != IRPCProxy ) {
      throw new ArgumentError("Provider Type should extends IRPCProxy!") ;
    }
    
    _providerInstanceMirror = _providerClassMirror.newInstance(new Symbol('') , [] , {}) ;
    
    Object providerObj = _providerInstanceMirror.reflectee ;
    
    _provider = providerObj ;
    
    IRPCProxy asProxy ;
    
    if ( providerObj is IRPCProxy ) {
      asProxy = providerObj ;
    }
    else {
      throw new StateError('Provider is not an IRPCProxy object! '+ providerObj) ;
    }
    
    asProxy._irpc = this ;
    
    ////
    
    if ( this._requester == null ) {
      if ( IRPCRequester._IRPCRequester_instantiator == null ) {
        throw new StateError('IRPCRequester default instantiator not set!') ;
      }
      
      this._requester = IRPCRequester._IRPCRequester_instantiator( this.webserviceURL ) ;
    }
    
  }
  
  Future callDynamic( Symbol functionName , List positionalArguments, [Map<Symbol,dynamic> namedArguments] ) {
    
    return new Future.microtask(() {
      InstanceMirror mirror ;
      
      if ( (positionalArguments == null || positionalArguments.isEmpty ) && ( namedArguments == null || namedArguments.isEmpty ) ) {
        
        mirror = _providerInstanceMirror.invoke(functionName, []) ;
        
      }
      else {
        
        mirror = _providerInstanceMirror.invoke(functionName, positionalArguments, namedArguments) ;
        
      }
      
      if ( mirror.hasReflectee ) {
        return mirror.reflectee ;  
      }
    }) ;
    
  }
  
  T get call => _provider ;
  
  T getCall() {
    return _provider ;
  }
  
  String get webserviceURL => _webserviceURI.toString() ;
  
  Uri get webserviceURI => _webserviceURI ;
  
  IRPCRequester get requester => _requester ;
  
  ////////////////////////////
  
  IRPCEventTable _eventTable = new IRPCEventTable() ;

  List<IRPCEventListener> _listeners = [] ; 
  
  bool get hasEventListeners => _listeners.isNotEmpty || _eventTypeListeners.isNotEmpty ;
  
  void listenToEvent( IRPCEventListener listener ) {
    
    if ( !_listeners.contains(listener) ) {
      _listeners.add(listener) ;
      
      scheduleMicrotask( _notifyEvents ) ;
    }
    
  }
  
  Map<String , List<IRPCEventListener>> _eventTypeListeners = {} ;
  
  void listenToEventType( String type , IRPCEventListener listener ) {
    
    List<IRPCEventListener> list = _eventTypeListeners[type] ;
    
    if (list == null) {
      list = [] ;
      _eventTypeListeners[type] = list ;
    }
    
    bool added = false ;
    
    if ( !list.contains(listener) ) {
      list.add(listener) ;
      added = true ;
    }
    
    if (added) {
      scheduleMicrotask( _notifyEvents ) ;
    }
    
  }
  
  void _notifyTypedListeners(IRPCEvent e) {
    
    List<IRPCEventListener> list = _eventTypeListeners[e.type] ;
    
    if (list == null || list.isEmpty) return ;
    
    for ( IRPCEventListener listener in list ) {
      listener(e) ;
    }
    
  }
  
  void _notifyEvents() {
    
    if ( _eventTable.hasEventToConsume && hasEventListeners ) {
      
      while ( _eventTable.hasEventToConsume ) {
        IRPCEvent event = _eventTable.consumeEvent() ;
        
        for (IRPCEventListener listener in _listeners) {
          listener(event) ;
        }
        
        _notifyTypedListeners(event) ;
      }
      
    }
    
  }
 
  updateEvents() {
    
    Future<String> response = _requester.createEventUpdateRequest(_webserviceURI, _eventTable.maxKnownEventId) ;
    
    response.then( _updateEventTable ) ;
    
  }
  
  _updateEventTable(String eventTableString) {
    
    IRPCEventTable eventTable = new IRPCEventTable.string(eventTableString) ;
    
    this._eventTable.merge(eventTable) ;
    _notifyEvents() ;
  }
   
}

typedef IRPCRequester IRPCRequesterInstantiatorFunction(String webserviceURL) ;

abstract class IRPCRequester {

  static IRPCRequesterInstantiatorFunction _IRPCRequester_instantiator ;

  static void set_IRPCRequester_instantiator( IRPCRequesterInstantiatorFunction function ) {
    _IRPCRequester_instantiator = function ;
  }
  
  //////////////////////////////////////////////////
  
  Future<String> doRequest(Uri url) ;
  
  Future<String> createEventUpdateRequest( Uri webserviceURI , int lastReceivedEvent ) {
    Uri url = buildEventUpdateRequestURL(webserviceURI, lastReceivedEvent) ;
    
    print("EVTUP REQUEST>> $url") ;
        
    return doRequest(url) ;
  }
  
  Future<String> createRequest( Uri webserviceURI, String memberName , List params , Map<Symbol, dynamic> namedParams , int lastReceivedEvent ) {
    Uri url = buildRequestURL(webserviceURI, memberName, params, namedParams, lastReceivedEvent) ;
    
    print("REQUEST>> $url") ;
    
    return doRequest(url) ;
  }
  
  static const String REQUEST_EVENT_UPDATE = '__IRPC_EVT__' ;
  
  static Uri buildEventUpdateRequestURL( Uri webserviceURI , int lastReceivedEvent  ) {

    Uri uri = webserviceURI.scheme == 'https' ?
        new Uri.https( webserviceURI.authority , webserviceURI.path + REQUEST_EVENT_UPDATE , {'id': '$lastReceivedEvent'} )
        :
        new Uri.http( webserviceURI.authority , webserviceURI.path + REQUEST_EVENT_UPDATE , {'id': '$lastReceivedEvent'} ) ;
        ;
    
    return uri ;
  }
  

  static const String REQUEST_EVENT_SYNCH_ID = '__IRPC_EVT_ID__' ;
  
  
  static Uri buildRequestURL( Uri webserviceURI, String memberName , List params , Map<Symbol, dynamic> namedParams , int eventTableLastId ) {

    Map<String,String> query = {} ;
    
    query.addAll( webserviceURI.queryParameters ) ;
    
    if ( params != null && params.isNotEmpty ) {
      for (int i = 0 ; i < params.length ; i++) {
        var val = params[i] ;
        if (val != null) {
          
          String s ;
          
          if ( val is Map || val is List ) {
            s = JSON.encode(val) ;
          }
          else {
            s = val.toString() ;
          }
          
          query['$i'] = s ; 
        }
      }
    }
    
    if ( namedParams != null && namedParams.isNotEmpty ) {
      namedParams.forEach( (k,v) => query[ MirrorSystem.getName(k) ] = v.toString() ) ;
    }
    
    query[REQUEST_EVENT_SYNCH_ID] = eventTableLastId.toString() ;
    
    Uri uri = webserviceURI.scheme == 'https' ?
        new Uri.https( webserviceURI.authority , webserviceURI.path + memberName , query )
        :
        new Uri.http( webserviceURI.authority , webserviceURI.path + memberName , query ) ;
        ;
    
    return uri ;
  }
  
}

@proxy
abstract class IRPCProxy {
  
  InstantRPC _irpc ;
  
  Map<String,List> _checkMethods = {} ;
  
  List _checkMethod(Invocation mirror) {
    String methodName = MirrorSystem.getName( mirror.memberName ) ;
    
    List alreadyOk = _checkMethods[methodName] ; 
    
    if ( alreadyOk != null ) {
      if (alreadyOk.isNotEmpty) {
        return alreadyOk ;
      }
      else {
        throw new StateError("Can't find method '$methodName' in superinterfaces declarations: ${ _irpc._providerClassMirror.superinterfaces }") ; 
      }
    }
    
    List<ClassMirror> superInterf = [ _irpc._providerClassMirror ] ;
    superInterf.addAll( _irpc._providerClassMirror.superinterfaces ) ;
    
    ClassMirror targetSuperInterface = null ;
    TypeMirror methodReturnType = null ;
    
    bool dartMirrorInstable = false ;
    
    for ( ClassMirror cm in superInterf ) {
      DeclarationMirror dm = cm.declarations[mirror.memberName] ;
      
      if (dm == null ) {
        dm = cm.instanceMembers[mirror.memberName] ;
      }
      
      if ( dm == null ) {
        continue ;
      }
      else if ( dm is! MethodMirror ) {
        //print('dm not MethodMirror: $dm') ;
        continue ;
      }
      
      targetSuperInterface = cm ;
      
      MethodMirror mm = dm as MethodMirror ;
      methodReturnType = mm.returnType ;
      
      if (methodReturnType == null) dartMirrorInstable = true ;
    }
    
    if ( !dartMirrorInstable ) {
      if ( methodReturnType == null ) {
        _checkMethods[methodName] = [] ;
        throw new StateError("Can't find method '$methodName' in superinterfaces declarations: $superInterf") ;
      }
      
      String typeName = MirrorSystem.getName( methodReturnType.qualifiedName ) ;
      
      if ( typeName != 'void' && typeName != 'dart.async.Future' ) {
        _checkMethods[methodName] = [] ;
        
        typeName = typeName.replaceFirst(new RegExp(r'^dart\.core\.', caseSensitive: true), '') ;
        throw new StateError("Can't call a method that doesn't return Future: $typeName ${ targetSuperInterface.reflectedType }.$methodName(...) >> Should return Future<$typeName> ") ;
      }  
    }
    
    List ret = [ methodName , methodReturnType != null ? methodReturnType.typeArguments : null ] ;
    
    _checkMethods[methodName] = ret ;
    
    return ret ;
  }
  
  noSuchMethod(Invocation mirror) {
    
    if ( mirror.isMethod ) {
      List ret = _checkMethod(mirror) ;
      
      String name = ret[0] ;
      List<TypeMirror> returnGenerics = ret[1] ;
      
      List params = mirror.positionalArguments ;
      Map<Symbol, dynamic> namedParams = mirror.namedArguments ;
      
      
      Symbol returnType = null ;
      
      if (returnGenerics != null && returnGenerics.isNotEmpty) {
        TypeMirror tm = returnGenerics[0] ;
        returnType = tm.simpleName ;
      }
      
      return _doRequest(name, params, namedParams, returnType) ;
    }
    
  }
  
  Future _doRequest( String memberName , List params , Map<Symbol, dynamic> namedParams , Symbol returnType ) {
    Future<String> response = _irpc.requester.createRequest(_irpc.webserviceURI, memberName, params, namedParams, _irpc._eventTable.maxKnownEventId) ;
    return response.then( (v) => _processResponse(v, returnType) ) ;
  }
  
  dynamic _processResponse(String requestResponse, Symbol returnType) {
    int splitIdx1 = requestResponse.indexOf('\n') ;
    
    int eventTableSz = int.parse( requestResponse.substring(0,splitIdx1) ) ;
    
    int splitIdx2 = splitIdx1+1 ;
    int splitIdx3 = splitIdx2+eventTableSz ;
    int splitIdx4 = splitIdx3+1 ;
    
    String eventTableStr = requestResponse.substring(splitIdx2 , splitIdx3) ;
    
    if ( requestResponse.substring(splitIdx3,splitIdx3+1) != '\n' ) {
      throw new StateError("Can't parse response") ;
    }
    
    _irpc._updateEventTable(eventTableStr) ;
    
    String responseData = requestResponse.substring(splitIdx4) ;
    
    int splitIdx5 = responseData.indexOf('\n') ;
    
    String responseTypeName = responseData.substring(0 , splitIdx5) ;
    String responseValue = responseData.substring(splitIdx5+1) ;
   
    if ( returnType != null ) {
      return IRPCResponder._toTypeBySymbol(responseValue, returnType) ; 
    }
    else {
      return IRPCResponder._toTypeByName(responseValue, responseTypeName) ;  
    }
    
  }
  
}

abstract class IRPCSessionWrapper implements IRPCSession {
  
  Map _sessionMap ;
  
  IRPCSessionWrapper( this._sessionMap ) ;
  
  @override
  operator [](Object key) => _sessionMap[key] ;
  
  @override
  void operator []=(key, value) {
    _sessionMap[key] = value ;
  }
  
  @override
  void addAll(Map other) => _sessionMap.addAll(other) ;

  @override
  void clear() => _sessionMap.clear() ;

  @override
  bool containsKey(Object key) => _sessionMap.containsKey(key) ;

  @override
  bool containsValue(Object value) => _sessionMap.containsValue(value) ;

  @override
  void forEach(void f(key, value)) => _sessionMap.forEach(f) ;

  @override
  bool get isEmpty => _sessionMap.isEmpty ;

  @override
  bool get isNotEmpty => _sessionMap.isNotEmpty ;

  @override
  Iterable get keys => _sessionMap.keys ;

  @override
  int get length => _sessionMap.length ;

  @override
  putIfAbsent(key, ifAbsent()) => _sessionMap.putIfAbsent(key, ifAbsent) ;
  
  @override
  remove(Object key) => _sessionMap.remove(key) ;

  @override
  Iterable get values => _sessionMap.values ;
  
}

class IRPCEvent {
  int _id ;
  String _type ;
  Map<String , String> _parameters ;
  
  IRPCEvent.string(String str) {
    var splitIdx1 = str.indexOf(';');
    var splitIdx2 = str.indexOf('\n');
    
    this._id = int.parse( str.substring(0 , splitIdx1) ) ;
    this._type = str.substring(splitIdx1+1 , splitIdx2) ;
    
    String paramsStr = str.substring(splitIdx2+1) ;
    
    List<String> lines = paramsStr.split('\n') ;
    
    Map<String,String> params = {} ;
    
    lines.forEach( (l) {
      int idx = l.indexOf('=') ;
      
      if (idx >= 0) {
        String k = l.substring(0,idx) ;
        String v = l.substring(idx+1) ;
        params[k] = v ;
      }
    } ) ;
    
    this._parameters = params ;
  }
  
  IRPCEvent( this._type , [ this._parameters ] ) {
    this._id = 0 ;
    
    if (this._parameters == null) this._parameters = {} ;
    
    _check();  
  }
  
  void _check() {
    if ( this._type == null || this._type.contains('\n') || this._type.contains(IRPCEventTable._MARK_EVENT_DELIMITER) ) throw new ArgumentError('Invalid type: $_type') ;
       
    this._parameters.forEach( (k,v) {
      if ( k.contains('\n') || k.contains('=') || k.contains(IRPCEventTable._MARK_EVENT_DELIMITER) ) throw new ArgumentError('Invalid key: $k') ;
      if ( v.contains('\n') || k.contains(IRPCEventTable._MARK_EVENT_DELIMITER) ) throw new ArgumentError('Invalid value: $v') ;
    } ) ;
       
  }
  
  int get id => _id ;
  String get type => _type ;
  Map<String, String> get parameters => _parameters ;
  
  @override
  String toString() {
    String str = "$_id;$_type\n" ;
    
    _parameters.forEach( (k,v) {
      str += "$k=$v\n" ;
    } ) ;
    
    return str ;
  }
  
}

class IRPCEventTable {
  
  static const String _MARK_EVENT_DELIMITER = '!_EVT_!' ;
  
  static IRPCEventTable _currentEventTable ;
  
  static IRPCEventTable getCurrentEventTable() {
    return _currentEventTable ;
  }
  
  static void _setCurrentEventTable(IRPCEventTable eventTable) {
    _currentEventTable = eventTable ;
  }
    
  static void _clearCurrentEventTable() {
    _currentEventTable = null ;
  }
  
  List<IRPCEvent> _events = [] ;
  
  int _lastConsumedEvent = 0 ;
  
  int get lastConsumedEvent => _lastConsumedEvent ;
  
  int _lastCreatedEvent = 0 ;
  
  int _maxKnownEventId = 0 ;
  
  int get maxKnownEventId => _maxKnownEventId ;
  
  void addEvent(String type, [ Map<String,String> params ]) {
    add( new IRPCEvent(type, params) ) ;
  }
  
  void add(IRPCEvent event) {
    event._id = ++_lastCreatedEvent ;
    
    _events.add(event) ;
  
    updateMaxKnownEventId( event.id ) ;
  }
  
  void updateMaxKnownEventId(int id) {
    if (_maxKnownEventId < id) _maxKnownEventId = id ;
  }
  
  int getTotalEventsToConsume() => _events.length ;
  
  List<IRPCEvent> _consumedEvents = [] ;
  int _consumedEventsDeleteCount = 0 ;
  
  int getTotalConsumedEvents() => _consumedEvents.length + _consumedEventsDeleteCount ;
  int getTotalConsumedEventsDeleted() => _consumedEventsDeleteCount ;
  
  int deleteConsumedEvents( [ int maxEventsInList = 1000 ]) {
    if (maxEventsInList < 0) maxEventsInList = 0 ;
    
    int del = 0 ;
    
    while ( _consumedEvents.length > maxEventsInList ) {
      if ( deleteConsumedEvent() ) {
        del++ ;
      }
      else {
        break ;
      }
    }
    
    return del ;
  }
  
  bool deleteConsumedEvent() {
    if (_consumedEvents.isEmpty) return false ;
    
    _consumedEvents.removeAt(0) ;
    _consumedEventsDeleteCount++ ;
    
    return true ;
  }
  
  int consumeUntilEventID(int eventID) {
    int del = 0 ;
    
    while ( _events.isNotEmpty ) {
      IRPCEvent event = _events[0] ;
      
      if ( event.id <= eventID ) {
        _events.removeAt(0) ;
        del++ ;
      }
      else {
        break ;
      }
    }
    
    return del ;
  }
  
  bool get hasEventToConsume => _events.isNotEmpty ;
  
  IRPCEvent consumeEvent() {
    if (_events.isEmpty) return null ;
    
    IRPCEvent event = _events.removeAt(0) ;
    _consumedEvents.add(event) ;
    
    if ( _lastConsumedEvent+1 != event.id ) throw new StateError('Out of sync consumed events!') ;
    _lastConsumedEvent = event.id ;
    
    return event ;
  }

  void update( IRPCEventTable other ) {
    if ( identical(this, other) ) return ;
    
    this._lastConsumedEvent = other._lastConsumedEvent ;
    this._lastCreatedEvent = other._lastCreatedEvent ;
    this._consumedEventsDeleteCount = other._consumedEventsDeleteCount ;
    
    this._events = other._events ;
    this._consumedEvents = other._consumedEvents ;
    
    if ( _events.isNotEmpty ) updateMaxKnownEventId( _events.last.id ) ;
    if ( _consumedEvents.isNotEmpty ) updateMaxKnownEventId( _consumedEvents.last.id ) ;
    
    print("UPDATE EVT TBL<<<\n${ this.toString() }\n>>>") ;
  }
  
  void merge( IRPCEventTable other ) {
    if ( identical(this, other) ) return ;
    
    int lastId = this._events.isNotEmpty ? this._events.last.id : this._lastConsumedEvent ;
    
    for ( IRPCEvent e in other._events ) {
      
      if ( lastId+1 == e.id) {
        this._events.add(e) ;
        lastId = e.id ;
        
        updateMaxKnownEventId( lastId ) ;
      }
      else if ( e.id <= lastId ) {
        continue ;
      }
      else {
        throw new StateError('Out of sync event table!') ;
      }
      
    }
    
  }
  
  IRPCEventTable() {
  }
  
  IRPCEventTable.string(String str) {
    
    int splitIdx1 = str.indexOf('\n') ;
    
    String head = str.substring(0,splitIdx1) ;
    
    List<String> headValues = head.split(';');
    
    this._lastConsumedEvent = int.parse( headValues[0] ) ;
    this._lastCreatedEvent = int.parse( headValues[1] ) ;
    int eventsSz = int.parse( headValues[2] ) ;
    
    String strEvents = str.substring(splitIdx1+1) ;
    
    List<String> events = strEvents.split(_MARK_EVENT_DELIMITER) ;
    
    for (int i = 0 ; i < eventsSz ; i++) {
      this._events.add( new IRPCEvent.string(events[i]) ) ;
    }
    
    for (int i = eventsSz ; i < events.length ; i++) {
      String s = events[i] ;
      if (s.isEmpty) continue ;
      this._consumedEvents.add( new IRPCEvent.string(s) ) ;
    }
    
  }
  
  @override
  String toString() {
    
    String str = "$_lastConsumedEvent;$_lastCreatedEvent;${ _events.length }\n" ;
    
    str += _events.join( _MARK_EVENT_DELIMITER ) ;
    str += _MARK_EVENT_DELIMITER ;
    str += _consumedEvents.join( _MARK_EVENT_DELIMITER ) ;
    
    return str ;
  }
  
}

abstract class IRPCSession implements Map {

  static IRPCSession _currentSession ;
  
  static IRPCSession getCurrentSession() {
    return _currentSession ;
  }
  
  static void _setCurrentSession(IRPCSession irpcsession) {
    _currentSession = irpcsession ;
  }
  
  static void _clearCurrentSession() {
      _currentSession = null ;
  }
  
  //////////////////////////////////////
  
  /**
   * Gets the id for the current session.
   */
  String get id;

  /**
   * Destroys the session. This will terminate the session and any further
   * connections with this id will be given a new id and session.
   */
  void destroy();

  /*
  /**
   * Sets a callback that will be called when the session is timed out.
   */
  void set onTimeout(void callback());
  */
}

class IRPCResponderCallMethodReturn {
  
  TypeMirror returnType ;
  Future ret ;
  
  String returnTypeName ;
  
  TypeMirror returnTypeGeneric ;
  String returnTypeGenericName ;
  
  IRPCResponderCallMethodReturn( this.returnType , this.ret ) {
    this.returnTypeName = IRPCResponder.getTypeNameByMirror(returnType) ;
    
    if ( returnTypeName != 'void' && returnTypeName != 'dart.async.Future' ) {
      throw new StateError('Return not of type Future') ;
    }
    
    List<TypeMirror> generics = returnType.typeArguments ;
    
    this.returnTypeGeneric = generics != null && generics.isNotEmpty ? generics[0] : null ;
    
    this.returnTypeGenericName = IRPCResponder.getTypeNameByMirror(this.returnTypeGeneric) ; 
  }
  
}

class IRPCResponder {
  
  static final RegExp _REGEXP_digit = new RegExp(r'ˆ\d+$') ;
  
  static List parseRequest(String path , Map<String,String> query) {
    List<String> pathSplit = path.split('/') ;
    
    String methodName = pathSplit.removeAt( pathSplit.length-1 ) ;
    
    String providerPath = pathSplit.join('/') ;
    

    if ( methodName == IRPCRequester.REQUEST_EVENT_UPDATE ) {
      int id = query.containsKey('id') ? int.parse( query['id'] ) : 0 ;
      return [ providerPath , methodName , id ] ;
    }
    
    String lastEventTableIdStr = query[IRPCRequester.REQUEST_EVENT_SYNCH_ID] ;
    
    int lastEventTableId = lastEventTableIdStr != null ? int.parse(lastEventTableIdStr) : 0 ;
    
    List<String> positionalParams = [] ;
    
    int lastAddedIdx = -1 ;
    for (int i = 0 ; i <= 20 ; i++) {
      String val = query[ i.toString() ] ;
      
      if (val != null) {
        for (int j = lastAddedIdx+1 ; j < i ; j++) {
          positionalParams.add(null) ;  
        }
        
        positionalParams.add(val) ;
        
        lastAddedIdx = i ;
      }
    }
    
    Map<String,String> namedParams = {} ;
    
    query.forEach( (String k, String v) {
      if ( k.isNotEmpty ) {
        int c0 = k.codeUnitAt(0) ;
        
        if ( !(c0 >= 48 && c0 <= 57 && _REGEXP_digit.hasMatch(k)) ) {
          namedParams[k] = v ;  
        }
      }
    }) ;
    
    return [ providerPath , methodName , positionalParams , namedParams , lastEventTableId ] ;
  }
  
  
  
  static String getTypeNameByMirror(TypeMirror typeMirror) {
    return MirrorSystem.getName( typeMirror.qualifiedName ) ;  
  }
  
  static String getTypeNameBySymbol(Symbol type) {
    if (type == null) return null ;
    String typeName = MirrorSystem.getName(type) ;
    return typeName ;
  }
  
  static dynamic _toType( String val , dynamic type ) {
    if ( type is String ) {
      return _toTypeByName(val, type as String) ;
    }
    else {
      return _toTypeBySymbol(val, type as Symbol) ;
    }
  }
  
  static dynamic _toTypeBySymbol( String val , Symbol type ) {
    if (val == null || type == null) return null ;
        
    String typeName = MirrorSystem.getName(type) ;
    
    return _toTypeByName(val , typeName) ;
  }
  
  static const String DART_CORE_PREFIX = 'dart.core.';
  
  static dynamic _toTypeByName( String val , String typeName ) {
    
    if (typeName.startsWith(DART_CORE_PREFIX)) {
      typeName = typeName.substring( DART_CORE_PREFIX.length ) ;
    }
    
    switch (typeName) {
      case 'bool': return val.toLowerCase() == 'true' ;
      case 'int': return int.parse(val) ;
      case 'double': return double.parse(val) ;
      case 'num': return num.parse(val) ;
      case 'String': return val ;
      case 'List': return JSON.decode(val) ;
      case 'Map': return JSON.decode(val) ;
      default: throw new StateError("Can't convert String value to type: $val -> $typeName") ;
    }
    
  }
  
  static IRPCResponderCallMethodReturn callMethod( dynamic obj , String methodName , List<String> positionalParams , Map<String,String> namedParams , IRPCSession irpcsession , IRPCEventTable eventTable) {
    
    List<dynamic> positionalParamsTyped = [] ;
    Map<Symbol,dynamic> namedParamsTyped = {} ;
    
    Symbol methodSymbol = new Symbol(methodName) ;
    
    InstanceMirror im = reflect(obj) ;
    
    ClassMirror cm = im.type ;
    
    MethodMirror mm = cm.declarations[methodSymbol] ;
    
    TypeMirror mmReturnType = mm.returnType ;
    
    int posParamIdx = -1 ;
    
    for ( ParameterMirror p in mm.parameters ) {
      TypeMirror tm = p.type ;

      String name ;
      String param ;
      
      if ( p.isNamed ) {
        name = MirrorSystem.getName( p.simpleName ) ;
        param = namedParams[name] ;
      }
      else {
        posParamIdx++ ;
        param = posParamIdx < positionalParams.length ? positionalParams[posParamIdx] : null ;
      }
      
      dynamic val ;
      if (param == null) {
        if (p.hasDefaultValue && p.defaultValue.hasReflectee) {
          val = p.defaultValue.reflectee ; 
        }
        else {
          val = null ;
        }
      }
      else {
        val = _toTypeBySymbol(param, tm.simpleName) ;  
      }
      
      if ( p.isNamed ) {
        namedParamsTyped[ p.simpleName ] = val ;
      }
      else {
        
        if ( posParamIdx < positionalParamsTyped.length  ) {
          positionalParamsTyped[posParamIdx] = val ;
        }
        else {
          while( positionalParamsTyped.length < posParamIdx ) {
            positionalParamsTyped.add(null) ;  
          }
          
          positionalParamsTyped.add(val) ;
        }
         
      }
      
    }
    
    InstanceMirror retIm ;
    try {
      IRPCSession._setCurrentSession(irpcsession) ;
      IRPCEventTable._setCurrentEventTable(eventTable) ;
      
      retIm = im.invoke(methodSymbol, positionalParamsTyped , namedParamsTyped) ;  
    }
    finally {
      IRPCSession._clearCurrentSession() ;
      IRPCEventTable._clearCurrentEventTable() ;
    }
    
    return new IRPCResponderCallMethodReturn(
        mmReturnType ,
        retIm != null && retIm.hasReflectee ? retIm.reflectee : null
    ) ;
  }
  
}


abstract class IRPCDataProviderInstantiator<T> {

  T instantiate() ;
  
}


