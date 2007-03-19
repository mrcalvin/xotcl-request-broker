ad_library {

  
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date July, 25 2006
  @cvs-id $Id: xorb-broker-procs.tcl 11 2006-07-25 01:59:33Z ssoberni $

}


namespace eval xorb::client {

  # # # # # # # # # # # #
  # # # # # # # # # e# # #
  # # Stub infrastructure
  # # # # # # # # # # # #
  # # # # # # # # # # # #

  ::xotcl::Class ProtocolStub -superclass ::xotcl::Class -slots {
    Attribute prefix
  }

  ::xotcl::Object do -proc invoke {
    {-contract ""}
    {-operation:required}
    {-impl ""}
    {-impl_id ""}
    {-call_args {}}
    {-error:switch}
  } {} {
    # / / / / / / / / / / /
    # pack call information
    array set call [list]
    foreach v [info vars] {
      set call($v) [set $v]
    }
    TclListener initialise [array get call]
    TclListener redirect
  }


  # +---------------------------+
  # | meta class                |
  # | Stub                      |
  # | -realising "object stubs"|
  # |                           |
  # +---------------------------+


  ::xotcl::Class Stub -superclass ::xotcl::Class -parameter {bind} -ad_doc {

    Stub serves as factory of "object stubs", i.e. the case
    of RMI in its proper sense of the word. While RPC, as implemented
    at the instproc level (ad_instproc), allows for stubbing of single
    remote methods / remote procedures, object stubs as represented by 
    Stub classes reflect entire remote objects. The dynamic stub-argument-
    declarations (as realised by InvocationProxy + StubBuilders) and the
    stub-wide declaration of binding information adhere to a clear order 
    of precedence: The level of method stubs overrules the stub-wide scope, 
    this allows for more flexibility at the level of stub delcaration.
  }

  Stub ad_proc unknown {name args} {

    This overridden unknown mechanism for Stub classes allows for creating 
    custom subtypes of Stubs with protocol-specific parameter sets, e.g.
    
    Stub s -bind "soap://Some-URI" -uri "Some-URI" -schemas "Some-Schemas" 
    
    returns a sub-meta-class of Stub with adapted / extended parameters 
    implementing the protocol-specific stub building / calling interface.

  } {

    set idx [lsearch [lindex $args 0] "-bind"]
    if {$idx ne "-1"} {
      set bind [lindex $args [expr {$idx + 1}]]
      if {[string first "-" $bind] != 0} {
	#set builder [InvocationProxy getStubBuilder -reference $bind]
	set x [Class new -superclass [self]]
	set plugin [RemotingProtocolPlugin getClass -uri $bind]
	#	set pList [list]
	#	foreach c [concat $plugin [$plugin info heritage]] {
	#foreach p [$plugin info parameter] {
	#	lappend pList $p
	#   }
	#	}
	#	$x parameter [lsort -unique $pList]
	$x parameter [$plugin info parameter]
	uplevel [self callinglevel] eval $x create $name $args
      } else {
	uplevel [self callinglevel] eval [self] create $name
      }
    }	
  }

  Stub ad_proc new {-bind:required args} {
    
    The same as the Stub-specific unknown mechanism, but in the sense of new semantics.
  } {

    set x [Class new -superclass [self]]
    set plugin [RemotingProtocolPlugin getClass -uri $bind]
    #	set pList [list]
    #	foreach c [concat $plugin [$plugin info heritage]] {
    #	    foreach p [$c info parameter] {
    #		lappend pList $p
    #	    }
    #	}
    #	$x parameter [lsort -unique $pList]
    $x parameter [$plugin info parameter]
    eval $x new -bind $bind $args
    
    
  } 


  # +---------------------------+
  # | Mixin class               |
  # | InvocationProxy           |
  # | -realising "method stubs" |
  # |                           |
  # +---------------------------+
  
  ::xotcl::Class InvocationProxy 
  
  InvocationProxy ad_instproc ad_instproc {-stub:switch -bind args} {} {
    
    
    if {$stub || [my istype Stub]} {
      if {![info exist bind] && [my istype Stub]} { my instvar bind }
      
      # substitute util_url_valid_p for a more 
      # powerful checker at some point
      set pKeys [join [RemotingProtocolPlugin getProtocolKeys] "|"]
      set rExpr [subst {^($pKeys)://\[^ \].+}]	
      my log pKeys=$pKeys,rExpr=$rExpr
      if {[regexp -nocase $rExpr [string trim $bind]]} {
	RemotingStubBuilder new -volatile -bind $bind -args [list $args]
      } else {
	LocalStubBuilder new -volatile -bind $bind -args [list $args]
      }
    } else {
      next
    }
  }

  InvocationProxy instproc getInfo {{-method {}}} {
    
    array set info [list]
    if {[my exists __lastcall__]} { 
      my instvar __lastcall__ stubHandlers
      my log lastcall=$__lastcall__,stubHandlers=[array get stubHandlers]
      set handler $stubHandlers($__lastcall__)
      if {$method ne {} && [info exists stubHandlers($method)]} {
	set handler $stubHandlers($method)
      }
      foreach i [list lastRequest lastResponse totalTime connectionTime] {
	set info($i) [$handler $i]
      }
      
    }
    return [array get info]
  }

  
  ###################
  # inject mixin
  #
  ::xotcl::Class instmixin ::xorb::client::InvocationProxy
  
  # +---------------------------+
  # |class                      |
  # |StubBuilder                |
  # | -LocalStubBuilder         |
  # |                           |
  # +---------------------------+
  
  ::xotcl::Class StubBuilder -parameter {bind args method {arguments ""} {doc {}} {body ""}}
  
  StubBuilder ad_instproc init args {} {
    my set __signature [list method arguments doc body]
    my parse [lindex [my args] 0]
    next

  }

  StubBuilder ad_instproc parse args {} {
    my instvar __my__
    $__my__ instvar __config__
    set idx end
    array set config [list] 
    # parsing stub-wide params (lowest precedence, are
    # overwritten by operation-specific settings
    if {[$__my__ istype Stub]} {
      if {![info exists __config__]} {
	my log "params=[[$__my__ info class] info parameter]"
	foreach p [[$__my__ info class] info parameter] {
	  if {[$__my__ exists $p]} {
	    set __config__(-$p) [$__my__ $p]
	  }
	}
      }
      array set config [array get __config__]
    }
    #parsing nonpos args, take precedence over stub-wide settings
    foreach {k v} [lindex $args 0] {
      # np-arg?
      if {[string first "-" $k] != -1} {
	set config($k) $v
      } else {
	set idx [lsearch [lindex $args 0] $k]
	break
      }
    }
    # parsing pos args
    set posArgs [lrange [lindex $args 0] $idx end]
    foreach k [my set __signature] {
      my $k [lindex $posArgs [lsearch [my set __signature] $k]]
    } 
    # passing formerly pos-args as config for stub handler
    set config(-operation) [my method]
    my args [array get config]
    # create/ inject mixin responsible for stub-editing, provided
    # that a body is given
    if {[my body] ne {}} {
      set x [Class new]
      $x ad_instproc [my method] [my arguments] [my doc] [my body]
      $__my__ instmixin add $x
    }
  }


  ::xotcl::Class LocalStubBuilder -superclass StubBuilder -parameter {{impl ""}} -instproc init args {
    my instvar __my__
    set __my__ [self callingobject]
    next 
    $__my__ instforward [my method] ::xorb::SCInvoker invoke -operation %proc -contract [my bind] -impl [my impl]

  }

  ::xotcl::Class RemotingStubBuilder -superclass ::xorb::client::StubBuilder 
  RemotingStubBuilder instproc init args  { 
    my instvar __my__
    set __my__ [self callingobject]
    next
    $__my__ instvar stubHandlers
    if {![info exists stubHandlers([my method])]} {
      set stubHandlers([my method]) [::xorb::client::Requestor new -childof $__my__]
    }
    set handler $stubHandlers([my method])
    # goes to filter instproc for protocol identifaction
    $handler bindingURI [my bind]
    my log +++args=[my args]
    $handler configuration [my args]
    $__my__ instforward [my method] $handler requests
  }

  # # # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # # #
  # protocol plugin infrastructure
  # (transitive mixins)
  # # # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # # #

  ::xotcl::Class ProtocolPlugin -superclass ::xotcl::Class
  ProtocolPlugin instproc load {-uri:switch protocol} {
    
    if {$uri} {
      set protocol [lindex [split $protocol "://"] 0]
    }
    set protocolClass [my getClass $protocol]
    
    if {$protocolClass ne {}} {
      my instmixin $protocolClass 
    } else {
      error "There is no [namespace tail [self]] '$protocol' defined."
    }
  } 

  ProtocolPlugin instproc getClass {-uri:switch protocolKey} {
    if {$uri} {
      set protocolKey [lindex [split $protocolKey "://"] 0]
    }
    set protocolKey [string toupper $protocolKey 0 0]
    return [lsearch -inline -glob [my info subclass] *${protocolKey}Plugin]
  }

  ProtocolPlugin instproc getProtocolKeys {} {
    set keys [list]

    my log self=[self],subcl=[my info subclass]
    foreach c [my info subclass] {
      lappend keys [string tolower [string trimright [namespace tail $c] "Plugin"] 0 0]
    }

    return $keys
  }

  # # # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # # #

  ProtocolPlugin RemotingProtocolPlugin -parameter {operation}

  RemotingProtocolPlugin instproc requests args {
    
    #puts "does plugin fundamentals"
    next
  }

  # # # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # # #

  ::xotcl::Class Requestor -parameter {
    bindingURI 
    configuration
    lastRequest
    lastResponse
    connectionTime
    totalTime
  }
  Requestor instmixin RemotingProtocolPlugin
  Requestor instproc protocolFilter args {
    set r [self calledproc]
    if {$r eq "requests"} {
      my instvar bindingURI
      # load protocols
      RemotingProtocolPlugin load -uri $bindingURI
      # load handler configuration
      eval my configure [my configuration]
      # perform actuall call
      set startTime [clock clicks]
      set r [next]
      set endTime [clock clicks]
      # notify parent
      my log lastcall-set=[my operation]
      [my info parent] set __lastcall__ [my operation]
      my totalTime [expr {($endTime-$startTime)/1000000.0}]
      # cleanup
      RemotingProtocolPlugin instmixin {}
      return $r
    } else {
      next
    }
    
  }
  Requestor instfilter add protocolFilter

  Requestor instproc requests args {
    next
  } 

  namespace export ProtocolStub
}