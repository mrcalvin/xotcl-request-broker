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

  namespace import -force ::xorb::client::*
  namespace import -force ::xoexception::try
  # / / / / / / / / / / / / / / / / / / /
  # merry with ::xorb::InvocationContext

  ::xotcl::Class ContextObjectClass -slots {
    Attribute clientPlugin
  } -superclass ::xotcl::Class

#   ContextObjectClass instproc recreate {obj} {
#     # / / / / / / / / / / / / / /
#     # 1) save context info for
#     # subsequent calls
#     set objectId [$obj virtualObject] 
#     # / / / / / / / / / / / / / /
#     # 2) TODO: call history
#     next
#     # reset
#     $obj set virtualObject $objectId
#   }

  ::xotcl::Class ContextObject -slots {
    Attribute virtualObject
    Attribute virtualCall
    Attribute virtualArgs
    Attribute marshalledRequest
    Attribute marshalledResponse
    Attribute unmarshalledRequest
    Attribute unmarshalledResponse
  }

#   ContextObject instproc reset {} {
#     set c [my info class]
#     $c recreate [self]
#   }
  ContextObject instproc use {object} {
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

  ::xotcl::Class TclGlueObject -slots {
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
    Attribute returntype -default {}
  } -superclass Requestor  
  
  CallAbstractionRequestor instproc handle args {
    my instvar earlyBoundContext stubObject call \
	signatureMask returntype

    namespace import -force ::xorb::exceptions::*
    # / / / / / / / / / / / / /
    # early bound context available?
    # lately bound context?
    # any ?
    if {$earlyBoundContext ne {}} {
      set contextObj $earlyBoundContext
    } elseif {[$stubObject info methods glueobject] ne {}} {
      set contextObj [$stubObject glueobject]
    } else {
      error "Requestor cannot resolve any context ('glue') object."
    }
    
    # / / / / / / / / / / / / /
    # derive from context object
    # prototype!

    $contextObj copy [self]::co
    set contextObj [self]::co
    
    # / / / / / / / / / / / / /
    # turn context object into
    # proper invocation context?
    # populate invocation context
    
    $contextObj virtualCall $call

    # / / / / / / / / / / / / /
    # simulate xotcl nonposArgs
    # parser, i.e. enforce both
    # typing (checkoption-enhanced)
    # signature
    # - upon init of requestor?
    # - upon handle call?
    #my log signatureMask=$signatureMask
    my proc __parse__ $signatureMask {
      my log +++INSIDE=[info vars]
      foreach v [info vars] { uplevel [list set parsedArgs($v) [set $v]]}
    }
    my log +++OUTSIDE=[info vars]
    # call parser
    ::xotcl::nonposArgs mixin add ::xorb::datatypes::Anything::CheckOption
    eval my __parse__ [lindex $args 0]
    ::xotcl::nonposArgs mixin delete ::xorb::datatypes::Anything::CheckOption
    
    $contextObj virtualArgs [array get parsedArgs]

    # / / / / / / / / / / / / /
    # set client protocol and
    # mix into requesthandler
    set contextClass [$contextObj info class]
    set plugin [$contextClass clientPlugin]
    
    try {
      ::xorb::client::crHandler mixin add $plugin
      ::xorb::client::crHandler handleRequest $contextObj
      ::xorb::client::crHandler mixin delete $plugin
    } catch {Exception e} {
      $e write
    } catch {error e} {
      global errorInfo
      error $errorInfo
    }

    # / / / / / / / / / / / / /
    # verify returntype constraint
    # introducing anythings:
    # unmarshalledResponse is of 
    # type Anything
    set any [$contextObj unmarshalledResponse]
    if {![$any isVoid] && $returntype eq "void"} {
      set value [$contextObj unmarshalledResponse]
      error [::xorb::exceptions::ViolationOfReturnTypeConstraint new \
		 "We expected a void return value, but got: $value"]
    }

    # / / / / / / / / / / / / / / /
    # TODO: Validation of non-void types
    # / / / / / / / / / / / / / / /
    # TODO: support for two return modes:
    # 1) returns -> <type> as conventional proc return
    # 2) returns -> <name>:<type> set a variable
    # in upper scope
    my log isvoid=[$any isVoid]
    if {![$any isVoid] && $returntype ne "void"} {
      # / / / / / / / / / / / / /
      # clear context obj
      # before new request 
      # procedure
      # options: manual clearance
      # our recreate mechanism
      #$contextObj reset
      #return
      return [$any as $returntype]
    }

    #set msg(cObj) $contextObj
    #set msg(args) $args
    #return [array get msg]
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
    return [eval CallAbstractionRequestor new $args]
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
    ::xotcl::nonposArgs proc contextobject
  }

  ::xotcl::nonposArgs proc contextobject {args} {
    if {[llength $args] == 2} {
      foreach {name value} $args break
      if {![my isobject $value] \
	      || ![$value istype ::xorb::stub::ContextObject]} {
	error "The argument passed does not qualify as context object."
      }
    }
  }
  
  
  # / / / / / / / / / / / / / / / / / /
  # actual glue 'keyword'
  # resembles implementation of xotcl's
  # abstract procs and instprocs
  
  ::Serializer exportMethods {  
    ::xotcl::Object instproc glue
    ::xotcl::Object instproc ad_glue
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
    upvar glueobject glueobject \
	returns returns \
	methName methName \
	argList argList
    set context [expr {[info exists glueobject]?\
			   "-earlyBoundContext $glueobject":""}]
    set voidness [expr {[info exists returns]?\
			    "-returntype $returns":""}]
    set self [self]
    # / / / / / / / / / / / /
    # The nasty embedding in
    # double brackets is necessary
    # due to 'list' not enclosing
    # non-whitespaced strings!!!!
    # TODO: escape in empty
    # arglist case, otherwise
    # MakeProc / nonposArgs
    # parser in xotcl.c segfaults
    if {$argList ne {}} {
      set argList "{{$argList}}"
    } else {
      set argList "{$argList}"
    }
    #set argList [expr {[llength $argList] == 1?"{{$argList}}":[list $argList]}]
    #set argList [list [list $argList]]
    my log "argList=argList"
    set body [subst -nocommands {
      set requestor [::xorb::stub::Requestor require \
			 -call $methName \
			 -signatureMask $argList \
			 -stubObject $self $context $voidness]
      \$requestor handle \$args
    }]
    return $body
  }

  Object instproc glue {
    -glueobject:contextobject
    -returns
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
  
  Object instproc ad_glue {
    {-private:switch false} 
    {-deprecated:switch false} 
    {-warn:switch false} 
    {-debug:switch false}
    -glueobject:contextobject
    -returns
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
    Attribute glueobject -type ::xorb::stub::ContextObject
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

  ::xotcl::Class GObject -superclass ::xotcl::Object
  #GObject instforward with %self glueobject
  GObject instproc ad_proc {
    {-private:switch false} 
    {-deprecated:switch false} 
    {-warn:switch false} 
    {-debug:switch false}
    -glueobject:contextobject
    -returns
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

  ::xotcl::Class GClass -superclass ::xotcl::Class
  #GClass instforward with %self glueobject
  GClass instproc init args {
    my superclass GObject
    next
  }
  GClass instproc ad_instproc {
    {-private:switch false} 
    {-deprecated:switch false} 
    {-warn:switch false} 
    {-debug:switch false}
    -glueobject:contextobject
    -returns
    methName
    argList
    doc
    body
  } {
    # / / / / / / / / / / / / /
    # TODO: Neophytos' 'next'
    # extension -> body
    set stubBody [my __makeStubBody__]
    uplevel [list [self] instproc $methName args $stubBody]
    my __api_make_doc "" $methName
  }
  
  namespace export ContextObject Requestor GObject GClass \
      ContextObjectClass
}
