::xo::library doc {

  A simplistic, xorb-based realisation
  of native ACS service contracts

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date August, 25 2007
  @cvs-id $Id$

}

namespace eval ::xorb {
  namespace import ::xorb::stub::*
  namespace import ::xorb::transport::*
  namespace import ::xorb::protocols::*
  namespace import ::xorb::context::*
  namespace import ::xorb::client::*

  # / / / / / / / / / / / / / / / /
  # A tentative package class for
  # the native ca plugin
  PackageMgr AcsScPackage -superclass ProtocolPackage
  AcsScPackage instproc acquireInvocationInformation {} {
    my instvar listener
    $listener instvar payload
    set ctx [next];# ProtocolPackage->acquireInvocatioContext
    $ctx virtualObject [list [$payload contract] [$payload virtualObject]]
    $ctx virtualCall [$payload virtualCall]
    $ctx virtualArgs [$payload virtualArgs]
    return $ctx
  }
  AcsScPackage instproc solicit=invocation {} {
    set context [my acquireInvocationInformation]
    $context package [self]
    next $context
  }

  # / / / / / / / / / / / / / / /
  # Invocation context sub-class

  ::xotcl::Class AcsScInvocationInformation -superclass InvocationInformation


  # / / / / / / / / / / / / / / /
  # 1-) provider-side facilities

  ListenerClass AcsScListener -superclass TransportListener \
      -protocol "AcsSc" \
      -plugin "::xorb::AcsSc"
  AcsScListener proc redirect {contextObject} {
    [self]::listener set payload $contextObject
    next --noArgs;# ListenerClass->redirect
  }
  AcsScListener instproc processRequest {} {
    # my instvar payload
    
    ::xorb::AcsScPackage initialize \
	-user_id [acs_magic_object "unregistered_visitor"]
    
    ::$package_id configure \
	-protocol [[my info class] plugin] \
	-listener [self]

    set r [::$package_id solicit invocation]
   #my debug solicit-response=$r
    
  }
  AcsScListener instproc dispatchResponse {payload} {


   #my debug dispatchResponse=[$payload serialize]
    my set payload $payload
  }


  # # # # # # # # # # # # # 
  # # # # # # # # # # # # # 
  # # AcsSc Protocol-Plugin
  # # # # # # # # # # # # # 
  # # # # # # # # # # # # # 
  
  PluginClass AcsSc -contextClass ::xorb::AcsScInvocationInformation
  
  AcsSc instproc handleRequest {invocationContext} {
    ::xorb::Invoker instmixin add [self class]::Invoker
    next;#::xorb::RequestHandler->handleRequest
    ::xorb::Invoker instmixin delete [self class]::Invoker
  }

  ::xotcl::Class AcsSc::Invoker -instproc init args {
    my instvar context contract
    foreach {contract impl} [$context virtualObject] break;
    $context virtualObject $impl
    next
  } -instproc resolve {objectId} {
    # -- clear from prefix
    return [string map {acssc:// ""} $objectId]
  }
  
  AcsSc instproc handleResponse {context returnValue} {
    $context marshalledResponse $returnValue
    set r [next $context];#::xorb::RequestHandler->handleResponse
    [my listener] dispatchResponse [$context marshalledResponse]
  }
  
  # / / / / / / / / / / / /
  # interceptors?


  # / / / / / / / / / / / / / / /
  # 1-) consumer-side facilities

  ::xotcl::Class AcsSc::Client 
  AcsSc::Client instproc handleRequest {invocationContext} {
    $invocationContext virtualObject acssc://[$invocationContext virtualObject]
        # / / / / / / / / / / / /
    # 2) forward to request handler
    next $invocationContext
  }
  AcsSc::Client instproc handleResponse {invocationContext} {
    # / / / / / / / / / / / /
    # 2) forward to request handler
    $invocationContext unmarshalledResponse \
	[$invocationContext marshalledResponse]
    next $invocationContext
  }

  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  # # TransportProvider for
  # # internal abstract calls
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #

  ::xotcl::Class AcsScTransportProvider \
      -superclass TransportProvider \
      -set key "acssc"

  AcsScTransportProvider instproc handle {invocationObject} {
    ::xorb::AcsScListener initialise
    ::xorb::AcsScListener redirect $invocationObject
   #my debug trace=[my stackTrace]
    set r [::xorb::AcsScListener::listener set payload]
   #my debug ===1===r=$r
    return $r
  }

  # # # # # # # # # # # # #
  # # # # # # # # # # # # #
  # A context object class
  # for local Tcl invocations /
  # call abstractions
  # # # # # # # # # # # # #
  # # # # # # # # # # # # #

  ContextObjectClass AcsScGlueObject -slots {
    Attribute contract
  } -superclass ContextObject \
      -clientPlugin ::xorb::AcsSc::Client

  AcsScGlueObject instforward impl %self virtualObject
  AcsScGlueObject instforward operation %self virtualCall
  AcsScGlueObject instforward call_args %self virtualArgs

  # TODO: impl_id forward

  # # # # # # # # # # # # #
  # # # # # # # # # # # # #
  # Public interface
  # `- ::xorb::invoke do
  # # # # # # # # # # # # #
  # # # # # # # # # # # # #

  ::xotcl::Object invoke
  invoke ad_proc do {
    -contract
    -impl
    -operation:required
    -impl_id
    -call_args
    -error:switch
  } {
    # -1- glue object
    
  } {
    
  }
  
  namespace export AcsScGlueObject AcsScTransportProvider \
      AcsScInvocationInformation AcsScPackage
}

