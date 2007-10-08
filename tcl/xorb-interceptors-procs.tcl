ad_library {
  
  This library collection provides the basic request
  handler infrastructure. We, ontop, introduce a 
  generic extension facility, based on interceptors organised
  in chains of interceptors. Interceptors are meant
  to realise a specific kind of 'aspect
  weaving'.

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date September 13, 2007
  @cvs-id $Id$
  }

namespace eval ::xorb {

  # / / / / / / / / / / / / / /
  # Meta class HandlerManager
  
  Class HandlerManager -parameter {
    chain
  } -superclass Class

  HandlerManager instproc handleRequest {context} {
    if {![my isobject [self]::instance]} {
      my create [self]::instance -destroy_on_cleanup
    }
    my debug "load requestflow"
    # / / / / / / / / / / / / / / / / / / / / / / / /
    # initialise a configuration, i.e. linearised sequence,
    # of interceptors
    my instvar chain
    set pkg [$context package]
    set c [$pkg get_parameter $chain ::xorb::$chain]
    [self]::instance mixin [$c children -[self proc] $context]
    #my debug "---CONFIG=$c,children=[$c children -[self proc] $context]"
    set result [[self]::instance [self proc] $context]
    # / / / / / / / / / / / / / / / / / / / / / / / / / 
    # fallback, if one of the interceptors did bounce
    # the flow incorrectly, without providing for a valid
    # context object.
    if {![my isobject $result] || \
	    ![$result istype ::xorb::context::InvocationContext]} {
      my debug "WARNING: Fallback to original context object"
      return $context
    }
    return $result
  }

  HandlerManager instproc handleResponse {context} {
    if {![my isobject [self]::instance]} {
      my create [self]::instance -destroy_on_cleanup
    }
    my debug "load responseflow"
    my instvar chain
    set pkg [$context package]
    set c [$pkg get_parameter $chain ::xorb::$chain]
    #my debug "---CONFIG=$c,children=[$c children -[self proc] $context]"
    [self]::instance mixin [$c children -[self proc] $context]
    [self]::instance [self proc] $context
  }

  # / / / / / / / / / / / / / / / / / / /
  # Joint base class BasicRequestHandler

  Class BasicRequestHandler -parameter {
    {requestHandler {[my info parent]}}
  }
  BasicRequestHandler instproc handleRequest {context} {
    my instvar requestHandler
    return [$requestHandler handleResponse $context]
  }
  BasicRequestHandler instproc handleResponse {context} {
    return $context
  }

  # / / / / / / / / / / / / / / / / / / /
  # Main provider-side handler class
  HandlerManager ServerRequestHandler \
      -superclass BasicRequestHandler \
      -chain "provider_chain"
  ServerRequestHandler instproc handleRequest {context} { 
    my instvar requestHandler
    set invoker [Invoker new -context $context]
    $invoker destroy_on_cleanup
    set r [$invoker invoke]
    # / / / / / / / / / / / / / / /
    # process result
    $requestHandler handleResponse $context $r
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
