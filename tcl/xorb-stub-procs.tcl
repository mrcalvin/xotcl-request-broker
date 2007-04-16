ad_library {

  Basic Stub infrastructure, implementing the
  Client Proxy pattern. The current state of the concept 
  owes its origin to contributions by Gustaf Neumann.

  @author stefan.sobernig@wu-wien.ac.at
  @author gustaf.neumann@wu-wien.ac.at
  @creation-date April, 12 2007
  @cvs-id $Id$

}


namespace eval ::xorb::stub {
  
  # / / / / / / / / / / / / / / / / / / /
  # merry with ::xorb::InvocationContext
  
  ::xotcl::Class ContextObject -slots {
    Attribute virtualObject
    Attribute virtualCall
    Attribute virtualArgs
  }
  ContextObject instproc contextualise {object} {
    # / / / / / / / / / / / / / / /
    # TODO: provide decoration with
    # object-wide context mixin, i.e.
    # construe a mixin class on the fly
    # that return the current instance
    # of a context object class
  }
  ContextObject instproc decontextualise {object} {
    # / / / / / / / / / / / / / / /
    # TODO: reverse a previously
    # realised decoration
  }

  # # # # # # # # # # # # #
  # # # # # # # # # # # # #
  # A context object class
  # for local Tcl invocations /
  # call abstractions
  # # # # # # # # # # # # #
  # # # # # # # # # # # # #

  ::xotcl::Class TclContextObject -slots {
    Attribute contract
  } -superclass ContextObject

  # # # # # # # # # # # # #
  # # # # # # # # # # # # #

  ::xotcl::Class Requestor -slots {
    Attribute earlyBoundContext -default {}
    Attribute stubObject
  }
  Requestor abstract instproc handle args

  # / / / / / / / / / / / / / / /
  # A specific Requestor class that
  # is capable of handling various
  # forms of 'call abstractions',
  # (local and remote, i.e RPC, RMI and
  # similar flavours)

  ::xotcl::Class CallAbstractionRequestor -slots {
    Attribute call
    Attribute signatureMask
  } -superclass Requestor  
  
  CallAbstractionRequestor instproc handle args {
    my instvar earlyBoundContext stubObject
    my log VARS=[info vars]
    my log SER=[my serialize]
    # / / / / / / / / / / / / /
    # early bound context available?
    set contextObj [expr {$earlyBoundContext ne {}?\
			      $earlyBoundContext:[$stubObject contextobject]}]
    set msg(cObj) $contextObj
    set msg(args) $args
    return [array get msg]
  }
  
  Requestor proc require {
	args		 
  } {
    # / / / / / / / / / / / / / / 
    # TODO: select abstraction style,
    # i.e. call or message (document)
    # style, for instance and return
    # specific instance of subclass
    my log REQUIRE:args=$args
    return [eval CallAbstractionRequestor new \
		-configure $args]
  }


  
  # # # # # # # # # # # # #
  # # # # # # # # # # # # #
  # 1) stub support for 
  # objects
  # # # # # # # # # # # # #
  # # # # # # # # # # # # #

  # / / / / / / / / / / / / / / / / 
  # We make use of context objects,
  # a specific pattern of argument
  # passing to provide adaptable/
  # extensible means of specifying
  # the generation of a stub method.
  # see Zdun (2005): Patterns of argument
  # passing.
  
  ::Serializer exportMethods {  
    ::xotcl::nonposArgs proc ContextObject
  }

  ::xotcl::nonposArgs proc ContextObject {args} {
    if {[llength $args] == 2} {
      foreach {name value} $args break
      if {![my isobject $value] \
	      || ![$value istype ::xorb::stub::ContextObject]} {
	error "The argument passed does not qualify as context object."
      }
    }
  }
  
  
  # / / / / / / / / / / / / / / / / / /
  # actual stub 'keywords'
  # resembles implementation of xotcl's
  # abstract procs and instprocs
  
  ::Serializer exportMethods {  
    ::xotcl::Object instproc stub
    ::xotcl::Object instproc ad_stub
    ::xotcl::Object instproc __makeStubBody__
  }
  
#   Object instproc __makeStubBody__ {
#     -stubName
#     -stubMask
#     {-contextObject {}}
#   } {
#     set context [expr {$contextObject ne {}?\
# 			   "-earlyBoundContext $contextObject":""}]
#     set self [self]
#     set body [subst -nocommands {
#       set requestor [::xorb::stub::Requestor require \
# 			 -call $stubName \
# 			 -signatureMask {$stubMask} \
# 			 -stubObject $self $context]
#       \$requestor handle \$args
#     }]
#     return $body
#   }
  
  Object instproc __makeStubBody__ args {
    # / / / / / / / / / / / / / / / / / / /
    # stub builder is only meant
    # to be called from within the
    # proc scope of stub, ad_stub,
    # StubClass->instproc, StubObject->proc
    upvar contextobject contextobject \
	returntype returntype \
	methName methName \
	argList argList
    set context [expr {[info exists contextobject]?\
			   "-earlyBoundContext $contextobject":""}]
    set self [self]
    set body [subst -nocommands {
      set requestor [::xorb::stub::Requestor require \
			 -call $methName \
			 -signatureMask {$argList} \
			 -stubObject $self $context]
      \$requestor handle \$args
    }]
    return $body
  }

  Object instproc stub {
    -contextobject:ContextObject
    -returntype
    methType 
    methName 
    argList
  } {
    if {$methType ne "proc" && $methType ne "instproc"} {
      error "Invalid method type '$methType' (required: 'proc' or 'instproc')"
    }
    set body [my __makeStubBody__]
    uplevel [list [self] $methType $methName args $body]
  }
  
  Object instproc ad_stub {
    {-private:switch false} 
    {-deprecated:switch false} 
    {-warn:switch false} 
    {-debug:switch false}
    -contextobject:ContextObject
    -returntype
    methType 
    methName 
    argList
    doc
  } {
    if {$methType ne "proc" && $methType ne "instproc"} {
      error "Invalid method type '$methType' (required: 'proc' or 'instproc')"
    }
    set body [my __makeStubBody__]
    uplevel [list [self] $methType $methName args $body]
    my __api_make_doc "" $methName
  }
  

  # / / / / / / / / / / / / / / /
  # TODO: replace getter/setter
  # by proper attribute slot?!
  

  # / / / / / / / / / / / / / / /
  
  ::xotcl::Class Stub -slots {
    Attribute contextobject -type ::xorb::stub::ContextObject
  }
  ::xotcl::Object instmixin add Stub

  set comment {
    Object instforward __stubContext__ \
      -default {__getStubContext__ __setStubContext__} %self %1
    
    Object instproc __getStubContext__ {} {
      my instvar __stubContext__
      if {[info exists __stubContext__]} {
	return $__stubContext__
      }
    }
    
    Object instproc __setStubContext__ {value} {
      my instvar __stubContext__
      if {[my isobject $value]} {
	set __stubContext__ $value
	return $__stubContext__
      } else {
	error "invalid value type"
      }
    }
  }

  # / / / / / / / / / / / / / / /
  # Some simplistic facades

  ::xotcl::Class StubObject -superclass ::xotcl::Object
  StubObject instforward context %self contextobject
  StubObject instproc ad_proc {
    {-private:switch false} 
    {-deprecated:switch false} 
    {-warn:switch false} 
    {-debug:switch false}
    -contextobject:ContextObject
    -returntype
    methName
    argList
    doc
    body
  } {
    # / / / / / / / / / / / / /
    # TODO: Neophtos' 'next'
    # extension -> body
    set stubBody [my __makeStubBody__]
    uplevel [list [self] proc $methName args $stubBody]
    my __api_make_doc "" $methName
  }

  ::xotcl::Class StubClass -superclass ::xotcl::Class
  StubClass instforward context %self contextobject
  StubClass instproc init args {
    my superclass StubObject
    next
  }
  StubClass instproc ad_instproc {
    {-private:switch false} 
    {-deprecated:switch false} 
    {-warn:switch false} 
    {-debug:switch false}
    -contextobject:ContextObject
    -returntype
    methName
    argList
    doc
    body
  } {
    # / / / / / / / / / / / / /
    # TODO: Neophtos' 'next'
    # extension -> body
    set stubBody [my __makeStubBody__]
    uplevel [list [self] instproc $methName args $stubBody]
    my __api_make_doc "" $methName
  }
  
  namespace export ContextObject Requestor StubObject StubClass
}
