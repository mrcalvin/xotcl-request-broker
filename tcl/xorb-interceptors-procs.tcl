ad_library {
  
  We introduce a generic extension facility,
  based on interceptors organised in chains
  of interceptors. Interceptors are meant
  to realise a specific kind of aspect
  weaving.

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date September 13, 2007
  @cvs-id $Id$
  
}

namespace eval ::xorb {
  
  # / / / / / / / / / / / / / / / / / / / / /
  # Class AspectInterceptor
  # - - - - - - - - - - - - - - - - - - - - - 
  # Basic idea taken from Zdun et al. (2007)
  # p. 362, but adapted both to XOTcl
  # capabilities and being more generic

  ::xotcl::Class Weavable
  Weavable instproc handleRequest {invocationContext} {
    if {[my checkPointcuts $invocationContext]} {
      my debug check=[self proc]\n
      next
    } 
  }
  Weavable instproc handleResponse {invocationContext} {
    if {[my checkPointcuts $invocationContext]} {
      my debug check=[self proc]\n
      next
    } 
  }

  ::xotcl::Class AspectInterceptor -instmixin Weavable
  AspectInterceptor abstract instproc checkPointcuts args

  # / / / / / / / / / / / / / / / / / / / / /
  # Class ChainOfInterceptors
  # - - - - - - - - - - - - - - - - - - - - - 
  # A simple ordered composite with some
  # extras

  ::xotcl::Class ChainOfInterceptors -slots {
    Attribute extends -multivalued true
  } -superclass ::xo::OrderedComposite
  ChainOfInterceptors instproc passThrough {flow invocationContext} {
    my debug childs=[my children $flow]\n
    foreach interceptor [my children $flow] {
      set inst [$interceptor new -destroy_on_cleanup]
      #ns_write prosearch=[$inst procsearch $flow]\n
      if {[$inst procsearch $flow] ne {}} {
	$inst $flow $invocationContext
      } 
    }
  }
  ChainOfInterceptors instproc children {{flow handleRequest}} {
    my instvar extends 
    set __children__ [next --noArgs]
    if {[info exists extends]} {
      foreach heritor $extends {
	set __children__ [concat [$heritor children] $__children__]
      }
    }
    if {$flow eq "handleResponse"} {
      return [my reverse $__children__]
    } else {
      return $__children__
    }
  }
  ChainOfInterceptors instproc reverse {input} {
    set temp [list]
    for {set i [ expr [ llength $input ] - 1 ] } {$i >= 0} {incr i -1} {
      lappend temp [ lindex $input $i ]
    }
    return $temp
  }

  ChainOfInterceptors instforward handleRequest %self passThrough %proc 
  ChainOfInterceptors instforward handleResponse %self passThrough %proc 
  
  ChainOfInterceptors create coi

  Class LoggingInterceptor

  LoggingInterceptor instproc handleRequest {context} {
    my debug [self]->[$context serialize]
    next
  }

  LoggingInterceptor instproc handleResponse {context} {
    my debug [self]->[$context serialize]
    next
  }

  coi add [LoggingInterceptor self]

  #ChainOfInterceptors create ExtendedCoI -extends CoI

  namespace export ChainOfInterceptors AspectInterceptor coi
}
