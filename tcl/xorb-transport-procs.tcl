ad_library {

  xorb transport infrastructure

  @author stefan.sobernig@wu-wien.ac.at	
  @creation-date March 7, 2007			
  @cvs-id $Id$
}

namespace eval ::xorb::transport {
  
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  # # Class TransportListener
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  
  ::xotcl::Class ListenerClass -superclass Class -parameter {
    protocol
    plugin
    {contextClass "::xorb::context::InvocationContext"}
  }
  ListenerClass instproc terminate {} {
    [my plugin] unplug
    [self]::listener destroy
  }
  ListenerClass instproc initialise {} {
    # / / / / / / / / / / / / / / / /
    # NOTE: as long as we want to stick
    # with major compatibility to OpenACS
    # (templating etc.), we cannot reset
    # ad_conn here. For references, look
    # at returnPage of ::xosoap::Package.
    # - - - - - - - - - - - - - - - -
    # ad_conn -reset
    if {![my isobject [self]::listener]} {
      my create [self]::listener 
    } 
    next
  }
  ListenerClass instproc redirect {} {
    if {[my isobject [self]::listener]} {
      [self]::listener processRequest
    }
    next
  }
  
  ListenerClass TransportListener
  TransportListener instproc processRequest {requestObj} {
   # ::xorb::rhandler handleRequest $requestObj
    next
  }
  TransportListener instproc dispatchResponse args {next}
  TransportListener instproc terminate {} {
    [my info class] terminate
  }
  
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  # # TransportListener for
  # # internal abstract calls
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  
  ListenerClass TclListener -superclass TransportListener \
      -protocol "Tcl" \
      -plugin "::xorb::protocols::Tcl"
  TclListener proc intialise {envelope} {
    # protocol-specific init instructions?
    next --noArgs;# ListenerClass->initialise
    ::xo::cc marshalledRequest $envelope
  }
  TclListener proc redirect {} {
    # TODO: move to ListenerClass->redirect?
    [my plugin] plug -listener [self]::listener
    next;#ListenerClass->redirect
    my terminate;
  }
  TclListener instproc processRequest {} {
    # marshalledRequest -> ArrayList?
    next [::xo::cc marshalledRequest];#TransportListener->processRequest
  }
  TclListener instproc dispatchResponse {payload} {
    return $payload
  }
  
  namespace export ListenerClass TransportListener TclListener

}