# / / / / / / / / / / / / / / / /
# We currently need this hack
# to allow xorb libraries to
# be sourced on-demand during
# first-time initialisation
# of the server instance.
# This could be handled by 
# a more powerful package require
# facility in the xotcl-core.
# if {[apm_first_time_loading_p]} {
#   set self [info script]
#   set segs [split [string trim $self /] /]
#   set package_key [lindex $segs end-2]
#   set script [lindex $segs end]
#   ns_log debug HERE(packages/$package_key/tcl/$script)
#   if {![nsv_exists apm_library_mtime packages/$package_key/tcl/$script]} {
#     #set prefix [acs_root_dir]/packages/$package_key
#     set prefix [ns_info tcllib]/../packages/$package_key
#     set files [apm_get_package_files \
# 		   -package_key $package_key \
# 		   -file_types tcl_procs]
# #     nsv_set apm_library_mtime packages/$package_key/tcl/$script \
# # 	[file mtime $self]  
#     ns_log debug files=$files
#     foreach file $files {
#       ns_log debug $prefix/$file==$self=>[expr {"$prefix/$file" eq $self}]
#       if {"$prefix/$file" eq $self} { 
# 	ns_log debug BREAKING
# 	break
#       } 
#       ns_log debug PASSTHROUGH
#       apm_source $prefix/$file
#       ns_log debug SOURCED=$file
#     }
#   }
# } 


::xo::library doc {
    
  xorb-specific exception types,
  extending xoexception facilities
  
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date December 1, 2006
  @cvs-id $Id$
  
}



namespace eval xorb::exceptions {

  namespace import -force ::xoexception::*
  
  ::xotcl::Class Loggable -parameter {
    logCmd
    mode
    {category {}}
    contentType
  }

  Loggable instproc write args {
    my instvar node origin
    foreach p [[self class] info parameter] {
      if {[my exists $p]} {
	my instvar $p
      } else {
	[my info class] instvar $p
      }
    }
    set msg [my getLogMessage]
    $logCmd $mode $msg
    next
  }

  Loggable instproc getLogMessage {} {
    my instvar node origin
    # -- stack trace available?
    if {[$origin exists stackNode]} {
      set sNode [$origin set stackNode]
      set document [$node ownerDocument]
      $node appendChild $sNode
      set msg [$node asXML]
      $node removeChild $sNode
    } else {
      set msg [$node asXML]
    }
    return $msg
  }
  
  Loggable instproc destroy args {
    if {[my exists node]} {
      [[my set node] ownerDocument] delete
      my unset node
    }
    next
  }
  
  ::xotcl::Class LoggableException -superclass Class -parameter {
    {logCmd "ns_log"}
    {mode "notice"}
    {contentType "text/plain"}
  }
  LoggableException instproc init args {
    #
    # default __classDoc__ to empty
    # string to avoid errors due
    # to non-init variable
    #
    if {![my exists __classDoc__]} {
      my set __classDoc__ ""
    }
    my superclass ::xoexception::Exception
    my instproc init {{message "n/a"}} {
      [self class] instvar __classDoc__
      if {[::xotcl::Object isclass [[my info class] info parent]]} {
	my category [namespace tail [[my info class] info parent]]
      }
      my instvar node origin
      # / / / / / / / / / / / / / / / / / / /
      # allow for nesting of throwable objects
      # as message: extract message
      if {[::xoexception::Throwable isThrowable $message]} {
	set document [[$message set node] ownerDocument]
	set node [$document createElement exception]
	$node setAttribute type [self class]
	$node appendChild [$message set node]
	if {[$message exists origin]} {
	  set origin [$message set origin]
	}
      } else {
	if {![info exists node]} {
	  set document [dom createDocument exception]
	  set node [$document documentElement]
	} else {
	  set document [$node ownerDocument]
	}
	$node setAttribute type [self class]
	set msgNode [$document createElement message]
	$msgNode appendChild [$document createTextNode $message]
	$node appendChild $msgNode
	set origin [self]
	#
	# preserve error stack
	#
	global errorInfo
	my instvar stackNode
	set stackNode [$document createElement errorStack]
	$stackNode appendChild [$document createTextNode $errorInfo]
      }
      if {[info exists __classDoc__]} {
	set descNode [$document createElement description]
	$descNode appendChild [$document createTextNode $__classDoc__]
	$node appendChild $descNode
      }
      next
    }
    my instmixin add ::xorb::exceptions::Loggable
    next
  }
  LoggableException instproc ad_doc {doc} {
    my set __classDoc__ $doc
    next
  }
  # / / / / / / / / / / / / / / / / / / / / / / / / /
  # Exception types + documentation
  LoggableException SkeletonGenerationException -ad_doc {
    The generation of a skeleton (implementation plus contract) failed.
  }
  
  LoggableException InterfaceDescriptionNotFound -ad_doc {
    There was no interface description (service contract) 
    found for this name.
  }
  
  LoggableException CalleeInterfaceNotFound -ad_doc {
    There was no calle interface (service implementation) found 
    for this name.
  }

  LoggableException InvocationException -ad_doc {
    An error occurred in the Invoker
  }

  LoggableException ReturnValueTypeMismatch -ad_doc {
    The value(s) returned from the invocation call do not
    correspond to the type constraints stipulated by the
    contract
  }

  LoggableException ArgumentTransformationException -ad_doc {
    Mapping non-positional arguments to positional ones failed.
  }

  LoggableException LifeCycleException -ad_doc {
    An error in the lifecycling of servants, i.e. XOTcl objects,
    occurred
  }

  LoggableException BreachOfPolicyException -ad_doc {
    A breach of policy was reported
  }

  LoggableException NonConformanceException -ad_doc {
    An implementation was reported to be non-conformant to the contract
    it is supposed to implement
  }

  LoggableException PolicyException -ad_doc {
    Checking the ruling access policy caused an exception
  }

  LoggableException UnknownNonConformanceException -ad_doc {
    An unknown exception was caught when trying to verify an
    implementation's conformance
  }

  LoggableException ServantDispatchException -ad_doc {
    When forwarding the call dispatch to the actual servant,
    an exception occurred.
  }

  LoggableException NoTransportProvider -ad_doc {
    The is no transport handler registered/ available
    to serve the given protocol request.
  }

  LoggableException TransportProviderFailed -ad_doc {
   The actual delivery/ transport of the given
    protocol request failed. 
  }

  LoggableException ViolationOfReturnTypeConstraint -ad_doc {
    The call return a value of type different to the expected/ 
    required returntype
  }

  LoggableException RequestorException -ad_doc {
    Requestor failed dispatching your invocation request
  }

  LoggableException NonBlockingRequestorException -ad_doc {
    Requestor failed dispatching your invocation request 
    in asynchronous/ non-blocking mode. 
  }

  LoggableException ClientRequestHandlerException -ad_doc {
    Passing invocation request through client request handler
    failed
  }
  
  LoggableException TypeViolationException -ad_doc {
    The value supplied violates the type constraint
  }

  LoggableException PackageException -ad_doc {
    An exception related to a package instance occurred
  }

  # LoggableException UnknownException -ad_doc {
  #   An unspecified exception was caught
  # }
  namespace export SkeletonGenerationException LoggableException\
      InvocationException NoTransportProvider TypeViolationException \
      InterfaceDescriptionNotFound CalleeInterfaceNotFound RequestorException \
      ClientRequestHandlerException PackageException
}
