::xo::library doc {
  
  This library collection provides the basic request
  handler infrastructure. We, ontop, introduce a 
  generic extension facility, based on interceptors organised
  in chains of interceptors. Interceptors are meant
  to realise a specific kind of 'aspect weaving'.

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date September 13, 2007
  @cvs-id $Id$
  }

namespace eval ::xorb {

  # / / / / / / / / / / / / / /
  # Meta class HandlerManager
  
  Class HandlerManager -parameter {
    chain
    transport
  } -superclass Class

  HandlerManager instproc handle {context} {
    # -1- / / / / process request flow / / / /
    my plug $context
    set requestFlow [my handleRequest $context]
    if {![my isobject $requestFlow] || \
	    ![$requestFlow istype ::xorb::context::InvocationInformation]} {
      my debug "===RequestFlow=== WARNING: Fallback to original context object"
      set requestFlow $context
    }
    # -3- / / / / dispatch / / / /
    my switch $context $requestFlow
    my dispatch $requestFlow
    # -4- / / / / clear context data / / / /
    $requestFlow clearContext
    # / / / / / / / / / / / / / / / / / / / 
    # Only continue for blocking calls
    # TODO: This should be handled more elegantly 
    # by a state-machine implementation of
    # the request handler ...
    if {![$context asynchronous]} {
      # -5- / / / / process response flow / / / /
      set responseFlow [my handleResponse $requestFlow]
      if {![my isobject $responseFlow] || \
	      ![$responseFlow istype ::xorb::context::InvocationInformation]} {
	my debug "===ResponseFlow=== WARNING: Fallback to original context object"
	set responseFlow $requestFlow
      }
      # -6- / / / / deliver / / / /
      my switch $requestFlow $responseFlow
      my deliver $responseFlow
      # / / / / / / / / / / / /
      # in a non-blocking scenario
      # $responseFlow might not exist
      # after deliver!
      # my unplug $responseFlow
      # $responseFlow clearContext
      return $responseFlow
    }
  }
  HandlerManager instproc handleRequest {context} {
    set i [my getInstance $context]
    my debug "load requestflow"
    # / / / / / / / / / / / / / / / / / / / / / / / /
    # initialise a configuration, i.e. linearised sequence,
    # of interceptors
    my instvar chain
    set pkg [$context package]
    set c [$pkg get_parameter $chain ::xorb::$chain]
    $i mixin [$c children -[self proc] $context]
    return [$i [self proc] $context]
  }

  HandlerManager instproc handleResponse {context} {
    set i [my getInstance $context]
    my debug "load responseflow"
    my instvar chain
    set pkg [$context package]
    set c [$pkg get_parameter $chain ::xorb::$chain]
    #my debug "---CONFIG=$c,children=[$c children -[self proc] $context]"
    $i mixin [$c children -[self proc] $context]
    return [$i [self proc] $context]
  }

  HandlerManager instproc getInstance {context} {
    if {![my isobject [self]::instance]} {
      my create [self]::instance -destroy_on_cleanup
    }
    return "[self]::instance"
  }

  HandlerManager abstract instproc dispatch {context}
  HandlerManager abstract instproc deliver {context}
  HandlerManager abstract instproc plug {context} 
  HandlerManager abstract instproc unplug {context}
  HandlerManager instproc switch {old new} {
    my unplug $old
    my plug $new
  }
  # / / / / / / / / / / / / / / / / / / /
  # Base class BasicRequestHandler

  Class BasicRequestHandler -parameter {
    {requestHandler {[my info parent]}}
  }
  BasicRequestHandler instproc handleRequest {context} {
    return $context
  }
  BasicRequestHandler instproc handleResponse {context} {
    return $context
  }

  # / / / / / / / / / / / / / / / / / / /
  # Main provider-side handler class
  HandlerManager ServerRequestHandler \
      -superclass BasicRequestHandler \
      -chain "provider_chain"
  
  ServerRequestHandler proc handle {context listener} {
    my transport $listener
    next $context
  }
  
  ServerRequestHandler proc dispatch {context} {
    set invoker [Invoker new -context $context]
    $invoker destroy_on_cleanup
    $context result [$invoker invoke]
  }
  
  ServerRequestHandler proc deliver {context} {
    # do nothing
  }
  
  ServerRequestHandler proc plug {context} {
    my mixin add [$context protocol] end
  } 
  
  ServerRequestHandler proc unplug {context} {
    my mixin delete [$context protocol]
  }

  # / / / / / / / / / / / / / / / / / / /
  # Main consumer-side handler class
  ::xorb::HandlerManager ::xorb::client::ClientRequestHandler \
      -superclass ::xorb::BasicRequestHandler \
      -chain "consumer_chain"

  ::xorb::client::ClientRequestHandler proc dispatch {invocationContext} {
    # PASSIFIED: TransportProvider only takes over, if no
    # marshalled response is present!
    if {![$invocationContext exists marshalledResponse]} {
      ::xorb::client::TransportProvider handle $invocationContext
    }
  }
  ::xorb::client::ClientRequestHandler proc deliver {invocationContext} {
    # do nothing
  }
  ::xorb::client::ClientRequestHandler proc plug {context} {
    my mixin add [$context protocol]::Client end
  } 
  ::xorb::client::ClientRequestHandler proc unplug {context} {
    my mixin delete [$context protocol]::Client
  }

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # # # 

  # / / / / / / / / / / / / / / / / / / / / /
  # Class ChainOfInterceptors
  # - - - - - - - - - - - - - - - - - - - - - 
  # A simple ordered composite with some
  # extras
  # - - - - - - - - - - - - - - - - - - - - - 
  
  ::xotcl::Class ChainOfInterceptors -slots {
    Attribute extends -multivalued true
  } -superclass ::xo::OrderedComposite

  ChainOfInterceptors instproc children {
    {-handleRequest:switch false}
    {-handleResponse:switch false}
    context
  } {
    my instvar extends 
    set __children__ [next --noArgs]
    # / / / / / / / / / / / / / / / / /
    # 1-) concatenate heritage levels
    if {[info exists extends]} {
      foreach heritor $extends {
	set __children__ [concat [$heritor children] $__children__]
      }
    }
    # / / / / / / / / / / / / / / / / / / /
    # 2-) evaluate guard/weaving conditions
    # on mixin classes and prepare the mixin 
    # list.
    # - - - - - - - - - - - - - - - - - - - - - 
    # Basic idea taken from Zdun et al. (2007)
    # p. 362, but adapted both to XOTcl
    # capabilities and being more generic
    set temp [list]
    foreach c $__children__ {
      if {[$c procsearch checkPointcuts] eq {} || \
	      [$c checkPointcuts $context]} {
	set temp [expr {$handleRequest?[concat $temp $c]:[concat $c $temp]}]
      }
    }
    return $temp
  }
  ChainOfInterceptors create provider_chain
  ChainOfInterceptors create ::xorb::client::consumer_chain

  namespace export ChainOfInterceptors HandlerManager BasicRequestHandler \
      provider_chain ServerRequestHandler
}
