ad_library {

  Deployment infrastructure for xorb services,
  including access policies
  
  @creation-date 2007-03-09
  @author stefan.sobernig@wu-wien.ac.at
  @cvs-id $Id$
  
}

namespace eval ::xorb::deployment {

  namespace import -force ::xorb::*
  namespace import -force ::xoexception::try
  
  ::xotcl::Class Policy -superclass ::xo::Policy -parameter {
    {default_permission {}}
  }
  
  Policy instproc check_permissions {object method} {
    set granted 0
    set is [catch {
      set implementation [namespace tail $object]
      #set pClass [::xorb::PluginClass set registry([::xo::ic protocol])]
      set hasPolicyLevelDefaults [expr {![my isobject [self]::$implementation] \
					    && [my default_permission] ne {}}]
      if {$hasPolicyLevelDefaults} {
	# inject default policy rule object
	set cmd [subst {
	  ::xotcl::Object $implementation \
	      -set default_permission [my default_permission]
	}]
	my log "policy=[self],dp=[my default_permission],cmd=$cmd"
	my contains $cmd
	$object mixin add [self class]::PolicyLevelSubject
      }
      
      $object mixin add [self class]::Subject
      set granted [next]
      my log "---6,GRANTED($object,$method)=$granted"
      $object mixin delete [self class]::Subject
      
      if {$hasPolicyLevelDefaults} {
	# cleanup
	[self]::$implementation destroy
	$object mixin delete [self class]::PolicyLevelSubject
      }
      my log "---7,FINISH"
      
    } e]
    my log "===is=$is"
    if {$is} {
      if {[::xoexception::Throwable isThrowable $e]} {
	#re-throw
	error $e
      } else {
	global errorInfo
	my log "---ERROR=$errorInfo,msg=$e message"
	error [::xorb::exceptions::PolicyException new $errorInfo]
      }
    }
    return $granted
  }
  

  # # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # # 
  # # conformance checks
  # # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # # 
  
  ::xotcl::Class Checkable
  Checkable instproc deploy args {
    if {[my check]} {
      next; #ServiceImplementation->deploy
    }
  }
  Checkable instproc check {} {
    set verified 0
    try {
      foreach clause [[self class] info children] {
	eval $clause [self proc] [self]
      }
     set verified 1 
    } catch {Exception e} {
      $e write
    } catch {error e} {
      global errorInfo
      [::xorb::exceptions::UnknownNonConformanceException new $errorInfo] write
    }
    return $verified
  }
  
  ::xotcl::Object Checkable::Containment -proc check {obj} {
    set contract [$obj implements]
    set c [lsearch -glob -inline \
	       [::xorb::ServiceContract allinstances] \
	       *$contract]
    if {$c eq {}} {
      # # # # # # # # # # # # # #
      # retrieve contract info
      # from db, when check is 
      # issued during server initialisation
      # Is manager thread available?
      if {![nsv_exists ::xotcl::THREAD ::XorbManager]} {
	# managing thread not available, revert
	# to db call
	set uqSet [db_list ops_for_contract_name {
	  select	ops.operation_name  
	  from   	acs_sc_operations ops
	  where  	ops.contract_name = :contract 
	}]
      } else {
	set c [::xorb::Skeleton getContract -lightweight -name $contract]
	set uqSet [$c info instprocs]
      }
    } elseif {$c eq "::xorb::Skeleton::$contract"} {
      set uqSet [$c info instprocs]
    } else {
      foreach a [$c info slots] {
	lappend uqSet [namespace tail $a]
      }
    }
    set aliases [list] 
    foreach a [$obj info slots] {lappend aliases [$a name]}
    my log "++c=$c,uqSet=$uqSet,aliases=$aliases"
    foreach uq $uqSet {
      if {[lsearch -exact $aliases $uq] == -1} {
	  error [::xorb::exceptions::NonConformanceException new [subst {
	    Contract '$contract' is not fully contained by Implementation 
	    '[$obj name]': An alias (delegate) for operation '$contract->$uq' 
	    is missing.}]]
	}
    }
  }
  
  
  ServiceImplementation instmixin add Checkable

  # # # # # # # # # # # # # # #
  # deployment facility

  ServiceImplementation instproc deploy {
    {-now:switch}
    {-requirePermission {}}
    {-defaultPermission {}}
    {-interceptors {}}
  } {

    # / / / / / / / / / / / / / / / / / /
    # 1) per-implementation interceptors
    if {$interceptors ne {}} {
      set cmds {}
      foreach entry $interceptors {
	switch [llength $entry] {
	  1 { 
	    append cmds [subst {
	      ::xorb::Configuration::Element new \
		  -interceptor $entry \
		  -array set properties {
		    position 1
		    protocol all
		    listen [namespace tail [self]]
		  }}]
	  }
	  2 {
	    foreach {protocol icpts} $entry break
	    foreach i $icpts {
	      append cmds [subst {
		::xorb::Configuration::Element new \
		    -interceptor $i \
		    -array set properties {
		      position 1
		      protocol $protocol
		      listen [namespace tail [self]]
		    }}]
	    }
	  }
	}
	
      }
      # register service-specific interceptors
      # with ::xorb::Extended configuration
      ::xorb::Extended contains $cmds
    }
    
    set rulingPolicy [parameter::get -parameter "per_instance_policy"]
    # TODO: no per-instance policy available at the time of server init!
    # solution: introduce PkgMgr, register the rule object there
    # and inject into per-instance default policy upon mount
    if {$rulingPolicy eq {}} {
      set rulingPolicy ::xorb::deployment::Default
    }
    set flags [list]
    # / / / / / / / / / / / / / / / / / /
    # 2) per-implementation access policy
    if {$requirePermission ne {}} {
      lappend flags "-array set require_permission {$requirePermission}"
    }
    if {$defaultPermission ne {}} {
      lappend flags "-set default_permission {$defaultPermission}"
    }
    if {[llength $flags] > 0} {
      set cmd [concat "::xotcl::Object [my name]" [join $flags]]
      $rulingPolicy contains $cmd
    }
    # finally, add impl to list of synchronizable
    # objects!!!!!!! ServiceImplementation proc sync
    # beware, recreation upon reload/ watch is also handled
    my log "sync,now=$now"
    if {$now || [my exists __recreated__]} {
      my log "sync-me"
      my mixin add ::xorb::Synchronizable
      my sync
      my mixin delete ::xorb::Synchronizable
      catch { my unset __recreated__ }
    } else {
      [self class] lappend __syncees__ [self] 
    }
  }

  # # # # # # # # # # # # # # #
  # privilege implementations

  ::xotcl::Class Policy::Subject
  Policy::Subject instforward privilege=public \
      %self modifier -type public
  Policy::Subject instforward privilege=private \
      %self modifier -type private
  
  Policy::Subject instproc modifier {
    -type:required
    {-login true}
    user_id
    package_id
    method
  } {
    my instvar registry
    # implies that servant have to be declared using ad_proc/
    # ad_instproc notation (if using the modifier tag)!
    my log "---subject-self=[self]([my info class])"
    #my log "ser=[my serialize]"
    
    foreach {servant t} $registry($method) break
    set inst [expr {$t == 2?"inst":""}]
    set scope [::xotcl::api scope]
   # my log "---1,scope=$scope"
    set obj [namespace qualifiers $servant]
    #my log "---2,obj=$obj"
    set procName [namespace tail $servant]
    #my log "---3,procName=$procName"
    set index [::xotcl::api proc_index $scope $obj ${inst}proc $procName]
    #my log "---4,index=$index"
    if {[nsv_exists api_proc_doc $index]} {
      array set doc [nsv_get api_proc_doc $index]
      my log "---5,index=$index"
      return $doc(${type}_p)
    } else {
      return 0
    }
  }

  
  Policy::Subject instproc privilege=deny {
    {-login true}
    user_id
    package_id
    method
  } {
    return 0
  }

  
   Policy::Subject instproc \
      condition=isProtocol {
	value
      } {
	set oughttobe $value
	set is [::xo::cc protocol]
	set compareWith [concat $is [$is info heritage]]
	#my log "compareWith=$compareWith, ought=$oughttobe"
	return [expr {[lsearch $compareWith $oughttobe] != -1}]
      }
   
  # policy-level semantics

  ::xotcl::Class Policy::PolicyLevelSubject
  Policy::PolicyLevelSubject instproc condition=isImplementation {value} {
    my log "[namespace tail [self]] eq $value? [expr {[namespace tail [self]] eq $value}]"
    return [expr {[namespace tail [self]] eq $value}]
  }

  # # # # # # # # # # # # # # #
  # default per-package policy
  
  Policy Default -default_permission {public}
}