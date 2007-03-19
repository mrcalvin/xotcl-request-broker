ad_library {

  xorb transport infrastructure

  @author stefan.sobernig@wu-wien.ac.at	
  @creation-date March 7, 2007			
  @cvs-id $Id: xorb-procs.tcl 17 2006-09-26 14:34:40Z ssoberni $
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
    # create context object
    # / / / / / / / / / / / / / / / / / /
    # clear ad_conn, require a context 
    # object (::xo::ic)
    ad_conn -reset
    [my contextClass] require \
	-user_id [acs_magic_object "unregistered_visitor"]
    if {![my isobject [self]::listener]} {
      my create [self]::listener 
    } else {
      #[self]::listener configure 
    }
    next
  }
  ListenerClass instproc redirect {} {
    if {[my isobject [self]::listener]} {
      my log "---2---,class=[[self]::listener procsearch processRequest]"
      [self]::listener processRequest
    }
    next
  }
  
  ListenerClass TransportListener
  TransportListener instproc processRequest {requestObj} {
    ::xorb::rhandler handleRequest $requestObj
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