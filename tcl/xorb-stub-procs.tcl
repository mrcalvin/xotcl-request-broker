ad_library {

  Basic Stub infrastructure, implementing the
  Client Proxy pattern. The current state of the concept 
  owes its origin to contributions by Gustaf Neumann.

  @author stefan.sobernig@wu-wien+.ac.at
  @author gustaf.neumann@wu-wien.ac.at
  @creation-date April, 12 2007
  @cvs-id $Id$

}


namespace eval ::xorb::stub {

  namespace import -force ::xorb::client::*
  namespace import -force ::xorb::datatypes::*
  namespace import -force ::xorb::exceptions::*
  namespace import -force ::xoexception::try
  # / / / / / / / / / / / / / / / / / / /
  # merry with ::xorb::InvocationContext

  ::xotcl::Class ContextObjectClass -slots {
    # / / / / / / / / / / / / / /
    # TODO: Need to unify this somehow.
    Attribute clientPlugin
    Attribute clientProtocol
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
    Attribute callback
    Attribute protocol -default ::xorb::protocols::Tcl
  } -ad_doc {
    <p>The class ContextObject realises a specific pattern
    of parameter passing which is used in xorb's client-side
    interfaces. Instances (of refining sub-classes) serve as
    generic container for parameters that are handed down the 
    various layers of the stub/ client proxy infrastructure.</p>
    
    <p>The class provides the following properties (attribute slots):
    <ul>
    <li>virtualObject: The non-canonical object identifier as passed
    through from the respective protocol plug-in, e.g. acs/FtsContentProvider
    </li>
    <li>virtualCall: The name of the abstracted operation called. 
    In an OO setting, we rather refer to the abstracted method.
    </li>
    <li>virtualArgs: List of parameter/value pairs delegated to the invoker of
    xorb. Depending on various stages of a dispatch run-through, these might
    either be XOTcl objects of type <a href="show-object?show%5fmethods=1&show%5fsource=0&object=::xorb::datatypes::Anything">Anything</a> or a streamed list
    representation containing non-positional argument pairs.
    </li>
    <li>protocol: Name of the main class representing the underlying
    protocol plug-in, e.g. <a href="show-object?show%5fmethods=1&show%5fsource=0&object=::xosoap::Soap">::xosoap::Soap</a>
    </li>
    </ul>
    </p>

    <p>For an important refinement, providing a couple of protocol-specific
    property extensions, see <a href="show-object?show%5fmethods=1&show%5fsource=0&object=::xosoap::client::SoapGlueObject">::xosoap::client::SoapGlueObject</p>
  
    @author stefan.sobernig@wu-wien.ac.at
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
    Attribute protocol
  }
  Requestor abstract instproc call args
  Requestor instproc stream {{obj {}}} {
    set vars [list]
    if {$obj eq {}} {set obj [self]}
    foreach v [$obj info vars] {
      if {[$obj exists $v]} {
	lappend vars "-set $v [$obj set $v]"
      }
    }
    return $vars
  }
  Requestor instproc setup {} {
    # / / / / / / / / / / / / / /
    # Enforce synchrony or asynchrony
    # at the application level
    # (program flow)
    my instvar contextObj
    if {[$contextObj exists callback]} {
      set cbObj [$contextObj callback]
      my mixin add [self class]::NonBlocking
      my instvar worker attach
      set attach ::Requestor
      if {[$cbObj exists worker]} {
	set worker [$cbObj set worker]
      } else {
	set worker [::xorb::WorkerPool acquire]
      }
      $contextObj callback [list [$cbObj getCallback]]
      ns_log notice HERE2
      set script [subst {
	set context \[[$contextObj info class] new [join [my stream $contextObj]]\]
	[my info class] $attach [join [my stream]] -set contextObj \$context
	$attach proc call args {
	  my instvar callback callName contextObj
	  if {\[catch {
	    set r \[next\]
	    eval \$callback \$callName.onComplete \$r
	  } msg\]} {
	    ns_log notice CALL-INNER=\$msg
	  } 
	       
	  \$contextObj destroy
	  my destroy
	}
      }]
      my debug SCRIPT=$script
      $worker do $script
    }
  }

  ::xotcl::Class Requestor::NonBlocking -slots {
    Attribute worker
    Attribute attach -default {::Requestor}
  }
  Requestor::NonBlocking instproc call args {
    my instvar worker attach
    $worker do -async $attach call $args
    my destroy_on_cleanup
  }
  
  # / / / / / / / / / / / / / / /
  # A specific Requestor class that
  # is capable of handling various
  # forms of 'call abstractions',
  # (local and remote, i.e RPC, RMI and
  # similar flavours)

  ::xotcl::Class CallAbstractionRequestor -slots {
    Attribute callName
    Attribute signatureMask
    Attribute returntype -default {}
  } -superclass Requestor  
  
  CallAbstractionRequestor instproc call args {
    my instvar earlyBoundContext stubObject callName \
	    signatureMask returntype contextObj protocol
    # / / / / / / / / / / / / /
    # derive from context object
    # prototype!
    
    $contextObj copy [self]::co
    set contextObj [self]::co
    
    # / / / / / / / / / / / / /
    # turn context object into
    # proper invocation context?
    # populate invocation context
    
    $contextObj virtualCall $callName
    # / / / / / / / / / / / / /
    # simulate xotcl nonposArgs
    # parser, i.e. enforce both
    # typing (checkoption-enhanced)
    # signature
    # - upon init of requestor?
    # - upon handle call?
    my log signatureMask=$signatureMask
    my proc __parse__ [lindex $signatureMask 0] {
      #foreach v [info vars] { uplevel [list set parsedArgs($v) [set $v]]}
      my debug INNER-PARSE=[info vars]
      if {[info exists returnObjs]} {
	return $returnObjs
      }
    }
    # call parser
    # / / / / / / / / / / / / /
    # set client protocol and
    # mix into requesthandler
    set contextClass [$contextObj info class]
    set plugin [$contextClass clientPlugin]
    set protocol [$contextClass clientProtocol]

    my debug ARGS-TO-PARSE=[lindex $args 0]
    ::xotcl::nonposArgs mixin add \
	::xorb::datatypes::Anything::CheckOption+Uplift
    set r [eval my __parse__ [lindex $args 0]]
    ::xotcl::nonposArgs mixin delete \
	::xorb::datatypes::Anything::CheckOption+Uplift
    
    $contextObj virtualArgs $r
    my debug REQUEST-CTX=[$contextObj serialize]

    try {
      ::xorb::client::crHandler mixin add $plugin
      ::xorb::client::crHandler handleRequest $contextObj
      ::xorb::client::crHandler mixin delete $plugin
    } catch {Exception e} {
      ns_log notice HERE1
      error $e
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
    if {![$any isVoid__] && $returntype eq "void"} {
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
    my log isvoid=[$any isVoid__]
    if {![$any isVoid__] && $returntype ne "void"} {
      # / / / / / / / / / / / / /
      # clear context obj
      # before new request 
      # procedure
      # options: manual clearance
      # our recreate mechanism
      #$contextObj reset
      #return
      return [$any as -protocol $protocol $returntype]
    }

  }
  CallAbstractionRequestor instproc setup {} {
    my instvar earlyBoundContext stubObject \
	contextObj

    namespace import -force ::xorb::exceptions::*
    # / / / / / / / / / / / / /
    # early bound context available?
    # lately bound context?
    # any ?
    # / / / / / / / / / / / / / / / / /
    # Order of precedence in resolution 
    # of a glue or context object:
    # 1-) early bound (at declaration time
    # of a method through ad_glue)
    # 2-) lately bound (at call time),
    # the stub object being the context
    # object itself! 
    # 3-) lately bound (at call time of
    # proxy method, assigned to the proxy
    # object through 'glueobject')
    my debug stub-class=[$stubObject info class],co?[$stubObject istype ::xorb::stub::ContextObject]

    if {$earlyBoundContext ne {}} {
      set contextObj $earlyBoundContext
    } elseif {[$stubObject istype ::xorb::stub::ContextObject]} {
      set contextObj $stubObject
    } elseif {[catch {set contextObj [$stubObject glueobject]}] || \
		  ![info exists contextObj] || \
		  $contextObj eq {}} {
      error "Requestor cannot resolve any context ('glue') object."
    }
    next;#Requestor->setup
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
  
  Object instproc __makeStubBody__ {{-filter false}} {
    # / / / / / / / / / / / / / / / / / / /
    # stub builder is only meant
    # to be called from within the
    # proc scope of glue, ad_glue,
    # ProxyClass->instproc and ProxyObject->proc
    upvar glueobject glueobject \
	returns returns \
	methName methName \
	argList argList
    set context [expr {[info exists glueobject]?\
			   "-earlyBoundContext $glueobject":""}]
    set voidness [expr {[info exists returns]?\
			    "-returntype $returns":""}]
    set self [self]
    set innerSignature $argList
    if {$argList ne {}} {
      # / / / / / / / / / / / / / /
      # parse argument list to seperate
      # between elements of the proxy
      # signature and the local method
      # signature
      if {$filter} {
	# / / / / / / / / / / / / / /
	# create a temporary proc
	# used for initial arg parsing
	my proc __tmpArgParser__ $argList {;}
	set npArgs [my info nonposargs __tmpArgParser__]
	set pArgs [my info args __tmpArgParser__]
	# / / / / / / / / / / / / / /
	# create a temporary proc
	# used for initial arg parsing
	set output(innerRecord) [list]
	set output(outerRecord) [list]
	foreach a $npArgs {
	  if {[regexp  {^-(.*):.*,?glue,?.*$} $a _ argName]} {
	    # / / / / / / / / / / / / / / / / / / /
	    # Elements annotated with virtual 
	    # check option 'glue' are
	    # 1-) added to the innerRecord (proxy method)
	    # 2-) added to the outerRecord (template method)
	    # as required elements but cleared from 
	    # xorb-specific check options not valid in
	    # non-xorb scopes.
	    lappend output(outerRecord) -$argName:required
	    lappend output(innerRecord) $a
	  } elseif {[regexp {^-([^:]+)(:(.+))?$} \
			 $a _ argName __ checkoptions]} {
	    # / / / / / / / / / / / / / / / / / / /
	    # Non-'glue'ed elements are filtered
	    # for the inner record:
	    # 1-) dupes are removed
	    # 2-) required check options are
	    # removed. this leaves just 'glue'ed
	    # elements required in the scope of
	    # inner record (= proxy method).
	    lappend output(outerRecord) $a
	    if {$checkoptions ne {}} {
	      set tmp [string map {, ,,} $checkoptions]
	      array set unique [split $tmp, ,]
	      if {[info exists unique(required)]} {unset unique(required)}
	      set checkoptions [join [array names unique] ,]
	      if {$checkoptions ne {}} {set checkoptions :$checkoptions} 
	    }
	    lappend output(innerRecord) -$argName$checkoptions
	  }
	}
	
	# / / / / / / / / / / / / / / / / / /
	# re-assemble the outer record
	# by adding the positional arguments
	# (if there were any)
	set output(outerRecord) [concat $output(outerRecord) $pArgs]
	# / / / / / / / / / / / / / / / / / /
	# re-assemble the inner record
	# by adding args as generic
	# container of all pos args
	# that might be passed through
	# from the outer record
	# TODO: append args only if
	# pos args are given?
	lappend output(innerRecord) args
	# / / / / / / / / / / / / / /
	# clear 
	my proc __tmpArgParser__ {} {}

	set innerSignature $output(innerRecord)
	set argList $output(outerRecord)
	# 	set glueArgs [lsearch \
	    # 			  -all \
	    # 			  -inline \
	    # 			  -regexp $argList {^-.*:(.*,)?glue(,.*)?$}]
	# 	set argList [lsearch \
	    # 			 -all \
	    # 			 -inline \
	    # 			 -not \
	    # 			 -regexp $argList {^-.*:(.*,)?glue(,.*)?$}]
	# 	my debug BEFORE-ARGS=$argList,glueArgs=$glueArgs
	# 	foreach targ $ar {
	
	# 	}
	
	# 	foreach garg $glueArgs {
	# 	  regexp {^-(.+):(.+)$} $garg _ argName checkoptions
	# 	  set argList [concat -$argName:required $argList]
	# 	}
      }
      # / / / / / / / / / / / /
      # The nasty embedding in
      # double brackets is necessary
      # due to 'list' not enclosing
      # non-whitespaced strings!!!!
      # TODO: escape in empty
      # arglist case, otherwise
      # MakeProc / nonposArgs
      # parser in xotcl.c segfaults
      #     set glueArgs "{{$glueArgs}}"
      set innerSignature "{{$innerSignature}}"
    } else {
      #set glueArgs "{$glueArgs}"
      set innerSignature "{$innerSignature}"
    }
    #set argList [expr {[llength $argList] == 1?"{{$argList}}":[list $argList]}]
    #set argList [list [list $argList]]
    my log "argList=argList"

    set body [subst -nocommands {
      set requestor [::xorb::stub::Requestor require \
			 -callName $methName \
			 -signatureMask $innerSignature \
			 -stubObject $self $context $voidness]
      ::xoexception::try {
	my debug INNER-ARGS=\$args
	\$requestor setup
	\$requestor call \$args
      } catch {Exception e} {
	\$e write
	error [subst {
	  Exception caught. Please, consult the log file for details: 
	  [\$e message]
	}]
      } catch {error e} {
	global errorInfo
	ns_log notice ERROR=\$errorInfo
	error \$e
      }
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
    if {[my isclass [self]::__indirector__] && \
	    [[self]::__indirector__ info instprocs $methName] ne {}} {
      [self]::__indirector__ instproc $methName {} {}
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
    set inst [expr {$methType eq "instproc"?"inst":""}]
    # / / / / / / / / / / / /
    # clear indirector method
    # when glue overwrites
    # previously defined proxy method
    # + indirector equivalent.
    if {[my isclass [self]::__indirector__] && \
	    [[self]::__indirector__ info instprocs $methName] ne {}} {
      [self]::__indirector__ instproc $methName {} {}
    }
    set body [my __makeStubBody__]
    uplevel [list [self] $methType $methName args $body]
    my __api_make_forward_doc $inst $methName
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

  ::xotcl::Class ProxyObject -superclass ::xotcl::Object
  #ProxyObject instforward with %self glueobject
  ProxyObject instproc ad_proc {
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
    set indirector [expr {$body ne {}?"true":"false"}]
    set stubBody [my __makeStubBody__ -filter $indirector]
    uplevel [list [self] proc $methName args $stubBody]
    my __api_make_doc "" $methName
    # / / / / / / / / / / / / /
    # TODO: Neophtos' 'next'
    # extension -> body
    if {![my isclass [self]::__indirector__]} {
      ::xotcl::Class create [self]::__indirector__
      my mixin add [self]::__indirector__
    }
    if {$indirector} {
      my debug INDIRECTOR-ARGLIST=$argList
      [self]::__indirector__ instproc $methName $argList $body
    }
  }

  ::xotcl::Class ProxyClass -superclass {
    ::xorb::stub::ProxyObject
    ::xotcl::Class
  }
  #ProxyClass instforward with %self glueobject
  ProxyClass instproc init args {
    my superclass add ProxyObject
    next
  }
  ProxyClass instproc ad_instproc {
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
    set indirector [expr {$body ne {}?"true":"false"}]
    set stubBody [my __makeStubBody__ -filter $indirector]
    uplevel [list [self] instproc $methName args $stubBody]
    my __api_make_doc inst $methName
    if {![my isclass [self]::__indirector__]} {
      ::xotcl::Class create [self]::__indirector__
      my instmixin add [self]::__indirector__
    }
    if {$indirector} {
      [self]::__indirector__ instproc $methName $argList $body
    }
  }
  
  namespace export ContextObject Requestor ProxyObject ProxyClass \
      ContextObjectClass
}
