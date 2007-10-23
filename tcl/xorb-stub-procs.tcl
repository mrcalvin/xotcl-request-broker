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
  namespace import -force ::xorb::aux::*
  namespace import -force ::xorb::datatypes::*
  namespace import -force ::xorb::exceptions::*
  namespace import -force ::xoexception::try
  # / / / / / / / / / / / / / / / / / / /
  # merry with ::xorb::InvocationContext

  ::xotcl::Class ContextObjectClass -slots {
    Attribute clientPlugin
  } -superclass ::xotcl::Class

  ::xotcl::Class ContextObject \
      -superclass ::xorb::context::InvocationContext \
      -slots {
	# / / / / / / / / / / / / / / / / / /
	# Setting the property 'asynchronous'
	# to 'true' will switch to an async
	# invocation mode at the consumer
	# side, either using poll
	# objects or result callbacks.
	Attribute asynchronous -default false
	Attribute callback
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

  ContextObject instproc getSubstified {attribute} {
    # / / / / / / / / / /
    # This escapes
    # procentage chars
    # specified like: '%%'
    set value [my set $attribute]
    set value [string map {%% % % \$} $value]
    return [my subst $value]
  }

  # # # # # # # # # # # # #
  # # # # # # # # # # # # #

  ::xotcl::Class Requestor -slots {
    #Attribute earlyBoundContext -default {}
    #Attribute stubObject
    Attribute contextObject
    Attribute protocol
    Attribute callName
    Attribute signatureMask
    Attribute returntype -default {}
  }
  Requestor instproc setup {} {
    next
  }

  Requestor instproc cleanup {} {
    # / / / / / / / / / / / / / /
    # A generic cleanup hook,
    # meant to be called after
    # sinks have been informed etc.
    my debug "[self] is going to be destroyed."
    my destroy
  }
    
  Requestor instproc call args {
   if {[catch {
      my instvar earlyBoundContext stubObject callName \
	  signatureMask returntype contextObject protocol
      # / / / / / / / / / / / / /
      # derive from context object
      # prototype!
      
      $contextObject copy [self]::co
      set contextObject [self]::co
      
      # / / / / / / / / / / / / /
      # turn context object into
      # proper invocation context?
      # populate invocation context
      
      $contextObject virtualCall $callName
      # / / / / / / / / / / / / /
      # simulate xotcl nonposArgs
      # parser, i.e. enforce both
      # typing (checkoption-enhanced)
      # signature
      # - upon init of requestor?
      # - upon handle call?
      my debug signatureMask=$signatureMask
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
      set contextClass [$contextObject info class]
      set plugin [$contextClass clientPlugin]
      set protocol [$contextObject protocol]

      my debug ARGS-TO-PARSE=[lindex $args 0]
      ::xotcl::nonposArgs mixin add \
	  ::xorb::datatypes::Anything::CheckOption+Uplift
      set r [eval my __parse__ [lindex $args 0]]
      ::xotcl::nonposArgs mixin delete \
	  ::xorb::datatypes::Anything::CheckOption+Uplift
      
      $contextObject virtualArgs $r
      my debug REQUEST-CTX=[$contextObject serialize]

      try {
	#::xorb::client::ClientRequestHandler mixin add $plugin
	::xorb::client::ClientRequestHandler mixin add $plugin end
	::xorb::client::ClientRequestHandler handleRequest $contextObject
	::xorb::client::ClientRequestHandler mixin {}
      } catch {Exception e} {
	# -- re-throws
	error $e
      } catch {error e} {
	#global errorInfo
	error [::xorb::exceptions::ClientRequestHandlerException new $e]
      }
      #my debug RESULT=[$r serialize]
    } e]} {
      if {[::xoexception::Throwable isThrowable $e]} {
	error $e
      } else {
	error [::xorb::exceptions::RequestorException new $e]
      }
    }
  }
  Requestor instproc unwrap {any} {
    my instvar contextObject returntype protocol
    # / / / / / / / / / / / / /
    # verify returntype constraint
    # introducing anythings:
    # unmarshalledResponse is of 
    # type Anything
    if {![$any isVoid__] && $returntype eq "void"} {
      set value [$contextObject unmarshalledResponse]
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
    my debug isvoid=[$any isVoid__]
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
      #my debug RESULT=[$r serialize]
      
    }
  }

  Requestor proc resolveContext {{-earlyBoundContext {}} -stubObject args} {
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

    if {$earlyBoundContext ne {}} {
      set contextObj $earlyBoundContext
    } elseif {[$stubObject istype ::xorb::stub::ContextObject]} {
      set contextObj $stubObject
    } elseif {[catch {set contextObj [$stubObject glueobject]}] || \
		  ![info exists contextObj] || \
		  $contextObj eq {}} {
      error "Requestor cannot resolve any context ('glue') object."
    }
    return $contextObj
  }
  
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Per-object method 
  # Requestor->getInstance
  # - - - - - - - - - - - - - - - - - - 
  # It serves as a factory method that
  # returns a concrete instance of
  # Requestor or its sub classes.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  Requestor proc getInstance {-contextObject args} {
    if {![info exists contextObject]} {
      set contextObject [eval my resolveContext $args]
    }
    return [BlockingRequestor new \
		-destroy_on_cleanup \
		-contextObject $contextObject]
  }

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Mixin class Requestor::Asynchrony
  # - - - - - - - - - - - - - - - - - - 
  # A small manager mixin that allows
  # for enabling/disabling asynchrony
  # support at will.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  Class Requestor::Asynchrony 
  Requestor::Asynchrony instproc getInstance {-contextObject args} {
    if {![info exists contextObject]} {
      set contextObject [eval my resolveContext $args]
    }
    if {[$contextObject asynchronous]} {
      return [::xorb::stub::NonBlockingRequestor new \
		  -mixin ::xorb::stub::NonBlockingRequestor::ConnectionThread \
		  -destroy_on_cleanup \
		  -contextObject $contextObject]
    } else {
      next -contextObject $contextObject $args
    }
  }
  
  # / / / / / / / / / / / / / / / / / /
  # To disable asynchrony support,
  # comment out the following line:
  Requestor mixin add Requestor::Asynchrony

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Class BlockingRequestor
  # - - - - - - - - - - - - - - - - - - 
  # The blocking flavour of Requestor.
  # Blocking refers both to program
  # flow (ClientProxy -> Requestor) and 
  # transport (Http, for instance).
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  ::xotcl::Class BlockingRequestor -superclass Requestor
  BlockingRequestor instproc call args {
    next;# Requestor->call
    my instvar contextObject
    # / / / / / / / / / / / / /
    # verify returntype constraint
    # introducing anythings:
    # unmarshalledResponse is of 
    # type Anything
    set any [$contextObject unmarshalledResponse]
    return [my unwrap $any]
  }

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Class Sink
  # - - - - - - - - - - - - - - - - - - 
  # Base class for the two non-blocking
  # strategies currently supported: poll
  # objects and result callbacks.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  Class Sink -slots {
    Attribute realm -default ::XorbManager
    Attribute object
  }
  Sink instproc init args {
    my instvar object realm
    if {![info exists object]} {
      set object [$realm do [my info class] new -noinit]
    }
  }
  Sink instproc do args {
    my instvar realm object
    eval $realm do $object $args
  }
  Sink instproc inform {state result {requestor {}}} {
    if {[my isobject $requestor]} {
      $requestor cleanup
    }
  }
  
  Class ResultCallback -slots {
    Attribute command
  } -superclass Sink
  ResultCallback instproc inform {state result {requestor {}}} {
    my instvar command
    eval ${command}.$state [list $result]
    next
  }
  
  Class PollObject -slots {
    Attribute data
  } -superclass Sink
  PollObject instproc inform {state result {requestor {}}} {
    my data $result
  }

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Sub class NonBlockingRequestor
  # - - - - - - - - - - - - - - - - - - 
  # Realises non-blocking support. It needs
  # to take two roles in the current connection
  # (thread) and background (thread) scope.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  Class NonBlockingRequestor -slots {
    Attribute sink
  } -superclass Requestor 

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Mixin class 
  # NonBlockingRequestor::ConnectionThread
  # - - - - - - - - - - - - - - - - - - 
  # Encapsulates the behaviour of the
  # role taken by the NonBlockingRequestor
  # in the scope of the current connection
  # thread. This involves:
  # -1- setting-up an environment in the
  # background thread (sink, delegate
  # requestor, delegate context object)
  # -2- delegating the actual call to
  # the background thread.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  Class NonBlockingRequestor::ConnectionThread
  NonBlockingRequestor::ConnectionThread instproc call args {
    # / / / / / / / / / / / / / /
    # Enforce synchrony or asynchrony
    # at the application level
    # (program flow)
    my instvar contextObject
    $contextObject instvar callback
    # / / / / / / / / / / / / /
    # 1-) Prepare a delegate
    # requestor in the broker
    # thread to take over.
    # We, therefore, stream the
    # requestor and context object
    # into the broker thread.
    # - - - - - - - - - - - - - 
    # 1.1-) the context object
    $contextObject mixin add ::xorb::aux::Streamable
    append script [subst {
      set context \[[$contextObject info class] new [join [$contextObject stream {
	messageStyle
	protocol
	virtualObject
	asynchronous
	callNamespace
	httpHeader
      }] "\\\n "]\]
    }]
    $contextObject mixin delete ::xorb::aux::Streamable
    # - - - - - - - - - - - - - 
    # 1.2-) provide for sinks,
    # either a resultcallback
    # or a poll object.
    if {[info exists callback]} {
      # init a result callback object
      set sink [::xorb::stub::ResultCallback new]
      $sink do command $callback
    } else {
      # init a poll object
      set sink [::xorb::stub::PollObject new]
    }
    # - - - - - - - - - - - - - 
    # 1.3-) the requestor
    my mixin add ::xorb::aux::Streamable
    append script [subst {
      [my info class] new  [join [my stream {
	callName 
	signatureMask 
	returntype 
	protocol
      }] "\\\n "] -contextObject \$context -sink [$sink object] \
	  -mixin [my info class]::BackgroundThread
    }]

    my mixin delete ::xorb::aux::Streamable
    # - - - - - - - - - - - - - 
    # 1.4-) some cleanup ?
    # my debug SCRIPT=$script
    set delegate [::thread::send [::XorbManager get_tid] $script]
    eval ::XorbManager do -async $delegate call $args
    return ""
  }

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Mixin class 
  # NonBlockingRequestor::BackgroundThread
  # - - - - - - - - - - - - - - - - - - 
  # Encapsulates the behaviour of the
  # role taken by the NonBlockingRequestor
  # in the scope of the persistent background
  # thread. This involves:
  # -1- the provision of completion/failure
  # callbacks for the non-blocking transport
  # infrastructure (onSuccess, onFailure).
  # -2- injecting some specific behaviour
  # into the ClientRequestHandler.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  
  Class NonBlockingRequestor::BackgroundThread
  NonBlockingRequestor::BackgroundThread instproc onSuccess {
    contextObj 
    transportProvider
  } {
    my instvar sink
    # 1-) pass payload through 
    # the response flow
    set contextClass [$contextObj info class]
    set plugin [$contextClass clientPlugin]
    # - cleanup - - - - - - 
    $transportProvider destroy
    # - - - - - - - - - - -
    ::xorb::client::ClientRequestHandler mixin \
	[list ::xorb::client::ClientRequestHandler::[namespace tail [self class]] $plugin]
    set ctx [::xorb::client::ClientRequestHandler handleResponse $contextObj]
    ::xorb::client::ClientRequestHandler mixin {}
  }

  NonBlockingRequestor::BackgroundThread instproc onFailure {
    exceptionObject 
    transportProvider
  } {
    my instvar sink
    set exception [::xorb::exceptions::NonBlockingRequestorException new \
		       $exceptionObject]
    
    # - TODO: $exception write
    
    # - cleanup - - - - - - 
    $transportProvider destroy
    # - - - - - - - - - - -
    $sink inform [self proc] [$exception getLogMessage] [self]
  }

  NonBlockingRequestor::BackgroundThread instproc call args {
    my instvar contextObject sink
    $contextObject set requestor [self]
    # / / / / / / / / / / / / / / / / / / / 
    # need to catch errors/exceptions
    # and deliver them (faults for instance)
    if {[catch {
      ::xorb::client::ClientRequestHandler mixin add \
	  ::xorb::client::ClientRequestHandler::[namespace tail [self class]]
      next;#Requestor->call
      # / / / / / / / / / / / / / / / / / / / /
      # The post-next block is not called under
      # default conditions, as we also use
      # non-blocking transport. HOWEVER, if some
      # extension (i.e. interceptor) indirects
      # to the response flow, it might get
      # called.
    } msg]} {
      if {[::xoexception::Throwable isThrowable $e]} {
	$e write
      } else {
	[::xorb::exceptions::NonBlockingRequestorException new \
	     -volatile $e] write
      }
    }
  }
  
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # Mixin class 
  # ::xorb::client::ClientRequestHandler::BackgroundThread
  # - - - - - - - - - - - - - - - - - - 
  # Groups some injectable behaviour for
  # the ClientRequestHandler in the scope
  # of the background thread.
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  Class ::xorb::client::ClientRequestHandler::BackgroundThread \
      -instproc handleResponse {context} {
	$context instvar requestor
	$requestor instvar sink
	set ctx [next];#::xorb::RequestHandler->handleResponse
	# Finally, store the payload with
	# the sink object (poll object
	# or request callback)
	$sink inform onSuccess \
	    [$requestor unwrap [$ctx unmarshalledResponse]] $requestor
      } -instproc getInstance {context} {
	$context instvar requestor
	# / / / / / / / / / / / / / / / / / / /
	# replaces HandlerManager->getInstance
	# - this helps to provide per-roundtrip
	# statefullness in a asynchronous/non-blocking
	# setting. Roundtrips are encapsulated by
	# instances of AsyncRequestor, the interceptor
	# chain is therefore bound to this entity.
	if {![my isobject ${requestor}::instance]} {
	  my create ${requestor}::instance -destroy_on_cleanup
	}
	${requestor}::instance requestHandler [self]
	return ${requestor}::instance
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
      set innerSignature "{$innerSignature}"
    }
    my debug "argList=argList"

    set body [subst -nocommands {
      set requestor \[eval ::xorb::stub::Requestor getInstance \
	  -stubObject $self $context\]
      eval \$requestor configure -callName $methName \
	  [list -signatureMask $innerSignature] \
	  $voidness

      ::xoexception::try {
	my debug INNER-ARGS=\$args
	#\$requestor setup
	\$requestor call \$args
      } catch {Exception e} {
	my debug EXCEPTION=[\$e serialize]
	\$e write
	error [subst {
	  Exception caught. Please, consult the log file for details: 
	  [\$e message]
	}]
      } catch {error e} {
	#global errorInfo
	#ns_log notice ERROR=\$errorInfo
	error \$e
      }
    }]
    return $body
  }

  Object ad_instproc glue {
    -glueobject:contextobject
    -returns
    methType 
    methName 
    argList
  } {
    <p>The method allows to enrich any ::xotcl::Object by
    proxy client features in the sense of the XOTcl Request
    Broker. It realises a modifier/keyword to ordinary
    proc/ instproc declarations. 
    For details specific on the OpenACS-specific breed
    of this method, please, have a look at  <a href="/api-doc/proc-view?proc=::xotcl::Object+instproc+ad_glue">::xotcl::Object->ad_glue</a>
    The overall idea is modeled after XOTcl's <a href="http://media.wu-wien.ac.at/langRef-xotcl.html#Object-abstract">abstract keyword</a>, which 
    allows for specifying somewhat 'abstract' methods 
    (either at the per-object or per-instance level) on ::xotcl::Objects.
    Similarily, glue adopts this notational form and in addition,
    provides means to provide proxy client information in terms
    of 'glue objects' and return type constraints. 
    For details, please, refer to the parameter descriptions below.
    </p>

    <p>
    A simplistic example:
    <pre>
    ::xotcl::Object o 
    
    o glue \
	-returns string \
	-glueobject $someGlueObject \
	proc helloWorld {
			 -arg1:string
		       }
    </pre>
    </p>


    @param glueobject The non-positional argument takes
    the reference to a 'glue object' to be used to
    process proxy invocations (see e.g., <a href="/api-doc/proc-view?proc=Class+%3a%3axosoap%3a%3aclient%3a%3aSoapGlueObject">SoapGlueObject</a> or <a href="/api-doc/show-object?show%5fmethods=1&show%5fsource=0&object=%3a%3axorb%3a%3astub%3a%3aContextObject">ContextObject</a>, in more general).
    @param returns Stipulates a return type constraint
    that will be enforced by xorb. One may provide 
    any 'type code' provided either by xorb, e.g. string, integer, boolean,
    or one of its protocol plug-ins (e.g. xsString, xsInteger, xsBoolean).
    
    @author stefan.sobernig@wu-wien.ac.at

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
  
  Object ad_instproc ad_glue {
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
    <p>The method allows to enrich any ::xotcl::Object by
    proxy client features in the sense of the XOTcl Request
    Broker. It realises a modifier/keyword to ordinary
    proc/ instproc declarations. ad_glue is the OpenACS-
    specific variant of <a href="/api-doc/proc-view?proc=::xotcl::Object+instproc+glue">::xotcl::Object->glue</a> and allows, in addition,
    to provide inline documentation and some environment
    switches, as known from <a href="/api-doc/proc-view?proc=ad%5fproc">::ad_proc</a> or ::xotcl::Object->ad_proc. For details specific
    to its role regarding client proxies, please, watch out
    for the inline documentation on <a href="/api-doc/proc-view?proc=::xotcl::Object+instproc+glue">::xotcl::Object->glue</a>.</p>

    <p>
    A simplistic example:
    <pre>
    ::xotcl::Object o 
    
    o ad_glue \
	-private \
	-returns string \
	-glueobject $someGlueObject \
	proc helloWorld {
			 -arg1:string
		       } {
	  Some inline doc
	} 
    </pre>
    </p>

    @param glueobject The non-positional argument takes
    the reference to a 'glue object' to be used to
    process proxy invocations (see e.g., <a href="/api-doc/proc-view?proc=Class+%3a%3axosoap%3a%3aclient%3a%3aSoapGlueObject">SoapGlueObject</a> or <a href="/api-doc/show-object?show%5fmethods=1&show%5fsource=0&object=%3a%3axorb%3a%3astub%3a%3aContextObject">ContextObject</a>, in more general).
    @param returns Stipulates a return type constraint
    that will be enforced by xorb. One may provide 
    any 'type code' provided either by xorb, e.g. string, integer, boolean,
    or one of its protocol plug-ins (e.g. xsString, xsInteger, xsBoolean).

    @author stefan.sobernig@wu-wien.ac.at
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

  ::xotcl::Class ProxyObject -ad_doc {
    <p>The class can be used to create XOTcl objects that
    serve as client proxies. While on generic XOTcl objects,
    one needs to adopt the <a href="/api-doc/proc-view?\proc=::xotcl::Object+instproc+ad_glue">glue</a> or <a href="api-doc/proc-view?proc=::xotcl::Object+instproc+glue">ad_glue</a> modifiers to proc
    declarations to provide a client proxy, instances of 
    ProxyObject come with adapted <a href="/api-doc/proc-view?proc=%3a%3axorb%3a%3astub%3a%3aProxyObject+instproc+ad%5fproc">ad_proc</a> semantics.
    On top of ::xotcl::Object->ad_proc, one can provide necessary proxy
    information such as glue objects, return type constraints etc. 
    Moreover, 'proxying' ad_proc's take a body declaration that allows to put 
    template code around the actual abstracted invocation represented by
    ::xotcl::next. Please, refer to xorb's manual for more details and
    examples on this feature. The inline documentation of <a href="/api-doc/proc-view?proc=%3a%3axorb%3a%3astub%3a%3aProxyObject+instproc+ad%5fproc">ad_proc</a> provides a little introductory example.</p>
  } -superclass ::xotcl::Object
  ProxyObject ad_instproc ad_proc {
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
    <p>This specialised/overloaded variant of ad_proc provides
    for declaring proxy methods on a per-object level. While it 
    supports all features of ::xotcl::Object->ad_proc (inline
						       documentation etc.), it also allows to specify 'proxy templates'.
    Proxy templates simply describe the usage pattern when a
    body script is provided (instead of an empty string). The ability
    to provide a body is the key difference to <a href="api-doc/proc-view?proc=::xotcl::Object+instproc+lue">glue</a>/<a href="api-doc/proc-view?proc=::xotcl::Object+instproc+ad_glue">ad_glue</a> that
    are mere 'abstract' modifiers. If you provide a body script,
    make sure that you keep the following in mind:</p>
    <ol>
    <li>You must place ::xotcl::next in the body script. 
    ::xotcl::next is responsible to proceed with
    the actual proxy invocation.</li>
    <li>You, furthermore, need to distinguish between two
    types of non-positional arguments declared on the proxy method,
    i.e. those that will be part of the proxy invocation (denoted by an mandatory 'glue' as checkoption) and those that will simply be available in the method
    body's local scope.
    </li>
    </ol>
    <p>
    A simplistic example:
    <pre>
    ProxyObject po 
    
    po ad_proc \
	-returns string \
	-glueobject $someGlueObject \
	helloWorld {
	  -innerArgument:string,glue
	  -outerArgument
	  positionalArgument
	} {
	  Some inline doc
	} {
	  # all three arguments, provided that
	  # a (default) value is given, will be
	  # available in this local scope, however
	  # only innerArgument will be used for
	  # the proxy invocation.
	  
	  set result [next];# execute actual proxy invocation

	  # 'result' refers to the return value of
	  # the proxy invocation.
	}
    </pre>
    </p>
    <p>The following arguments may be provided to calls on ad_proc:</p>

    @param private This correponds to ::ad_proc's and 
    ::xotcl::Object->ad_proc's private
    @param deprecated This correponds to ::ad_proc's and 
    ::xotcl::Object->ad_proc's deprecated
    @param warn This correponds to ::ad_proc's and 
    ::xotcl::Object->ad_proc's warn
    @param debug This correponds to ::ad_proc's and 
    ::xotcl::Object->ad_proc's debug
    @param glueobject The non-positional argument takes
    the reference to a 'glue object' to be used to
    process proxy invocations (see e.g., <a href="/api-doc/proc-view?proc=Class+%3a%3axosoap%3a%3aclient%3a%3aSoapGlueObject">SoapGlueObject</a> or <a href="/api-doc/show-object?show%5fmethods=1&show%5fsource=0&object=%3a%3axorb%3a%3astub%3a%3aContextObject">ContextObject</a>, in more general).
    @param returns Stipulates a return type constraint
    that will be enforced by xorb. One may provide 
    any 'type code' provided either by xorb, e.g. string, integer, boolean,
    or one of its protocol plug-ins (e.g. xsString, xsInteger, xsBoolean).
    @methName The name of the proxy method
    @argList A list of positional/non-positional arguments representing
    the proxy method's signature. Please, note that you must distinguish 
    between providing a method body (see below) or simply an empty string
    to the body argument. As soon as you declare a body on the proxy method,
    you need to distinguish between two type of arguments, i.e. those that 
    will be part of the proxy invocation (denoted by an mandatory 'glue' 
					  as checkoption) and those that will simply be available in the method
    body's local scope.
    @doc The inline documentation string
    @body The body declaration. Note, that you can either provide an empty
    tcl string or a body script to a method call on ad_proc. However, some
    semantics change as soon as a body is provided. See the object
    for some initial hints.

    @author stefan.sobernig@wu-wien.ac.at
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

  ::xotcl::Class ProxyClass -ad_doc {
    <p>The meta class can be used to create XOTcl objects that
    serve as classes that client proxies can be instantiated
    from. While on generic XOTcl classes,
    one needs to adopt the <a href="api-doc/proc-view?proc=::xotcl::Object+instproc+glue">glue</a> or <a href="api-doc/proc-view?proc=::xotcl::Object+instproc+ad_glue">ad_glue</a> modifiers to instproc
    declarations, instances of 
    ProxyClass come with adapted <a href="/api-doc/proc-view?proc=%3a%3axorb%3a%3astub%3a%3aProxyClass+instproc+ad%5finstproc">ad_instproc</a> semantics.
    On top of ::xotcl::Class->ad_instproc, one can provide necessary proxy
    information such as glue objects, return type constraints etc. 
    Moreover, 'proxying' ad_instproc's take a body declaration that allows 
    to put template code around the actual abstracted invocation represented by
    ::xotcl::next. Please, refer to xorb's manual for more details and
    examples on this feature. The inline documentation of <a href="/api-doc/proc-view?proc=%3a%3axorb%3a%3astub%3a%3aProxyClass+instproc+ad%5finstproc">ad_instproc</a> provides a little introductory example.</p>
    <p>Note, that instances of ProxyClass are themselves <a href="show-object?show%5fmethods=1&show%5fsource=0&object=::xorb::stub::ProxyObject">ProxyObjects</a>!
    </p>
  } -superclass {
    ::xorb::stub::ProxyObject
    ::xotcl::Class
  }
  #ProxyClass instforward with %self glueobject
  ProxyClass instproc init args {
    my superclass add ProxyObject
    next
  }
  ProxyClass ad_instproc ad_instproc {
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
    <p>This specialised/overloaded variant of ::xotcl::Class->ad_instproc 
    provides for declaring proxy methods on a per-instance level. While it 
    supports all features of ::xotcl::Class->ad_instproc (inline
							  documentation etc.), it also allows to specify 'proxy templates'.
    Proxy templates simply describe the usage pattern when a
    body script is provided (instead of an empty string). The ability
    to provide a body is the key difference to <a href="api-doc/proc-view?proc=::xotcl::Object+instproc+glue">glue</a>/<a href="api-doc/proc-view?proc=::xotcl::Object+instproc+ad_glue">ad_glue</a> that
    are mere 'abstract' modifiers. If you provide a body script,
    make sure that you keep the following in mind:</p>
    <ol>
    <li>You must place ::xotcl::next in the body script. 
    ::xotcl::next is responsible to proceed with
    the actual proxy invocation.</li>
    <li>You, furthermore, need to distinguish between two
    types of non-positional arguments declared on the proxy method,
    i.e. those that will be part of the proxy invocation (denoted by an mandatory 'glue' as checkoption) and those that will simply be available in the method
    body's local scope.
    </li>
    </ol>
    <p>
    A simplistic example:
    <pre>
    ProxyClass pc 
    
    pc ad_instproc \
	-returns string \
	-glueobject $someGlueObject \
	helloWorld {
	  -innerArgument:string,glue
	  -outerArgument
	  positionalArgument
	} {
	  Some inline doc
	} {
	  # all three arguments, provided that
	  # a (default) value is given, will be
	  # available in this local scope, however
	  # only innerArgument will be used for
	  # the proxy invocation.
	  
	  set result [next];# execute actual proxy invocation

	  # 'result' refers to the return value of
	  # the proxy invocation.
	}
    </pre>
    </p>
    <p>
    The following arguments may be provided to calls on ad_proc:
    </p>

    @param private This correponds to ::ad_proc's and 
    ::xotcl::Class->ad_instproc's private
    @param deprecated This correponds to ::ad_proc's and 
    ::Xotcl::Class->ad_instproc's deprecated
    @param warn This correponds to ::ad_proc's and 
    ::Xotcl::Class->ad_instproc's warn
    @param debug This correponds to ::ad_proc's and 
    ::Xotcl::Class->ad_instproc's debug
    @param glueobject The non-positional argument takes
    the reference to a 'glue object' to be used to
    process proxy invocations (see e.g., <a href="/api-doc/proc-view?proc=Class+%3a%3axosoap%3a%3aclient%3a%3aSoapGlueObject">SoapGlueObject</a> or <a href="/api-doc/show-object?show%5fmethods=1&show%5fsource=0&object=%3a%3axorb%3a%3astub%3a%3aContextObject">ContextObject</a>, in more general).
    @param returns Stipulates a return type constraint
    that will be enforced by xorb. One may provide 
    any 'type code' provided either by xorb, e.g. string, integer, boolean,
    or one of its protocol plug-ins (e.g. xsString, xsInteger, xsBoolean).
    @methName The name of the proxy method
    @argList A list of positional/non-positional arguments representing
    the proxy method's signature. Please, note that you must distinguish 
    between providing a method body (see below) or simply an empty string
    to the body argument. As soon as you declare a body on the proxy method,
    you need to distinguish between two type of arguments, i.e. those that 
    will be part of the proxy invocation (denoted by an mandatory 'glue' 
					  as checkoption) and those that will simply be available in the method
    body's local scope.
    @doc The inline documentation string
    @body The body declaration. Note, that you can either provide an empty
    tcl string or a body script to a method call on ad_proc. However, some
    semantics change as soon as a body is provided. See the object
    for some initial hints.

    @author stefan.sobernig@wu-wien.ac.at
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
      ContextObjectClass BlockingRequestor NonBlockingRequestor
}
