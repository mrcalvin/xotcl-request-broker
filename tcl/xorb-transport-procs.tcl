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
    {contextClass "::xorb::context::InvocationInformation"}
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
    
  namespace export ListenerClass TransportListener

}