::xo::library doc {

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date January 30, 2006
  @cvs-id $Id$
  
}


# # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # #
# Managing thread for xorb
# # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # #

::xotcl::THREAD create XorbManager { 
  namespace eval xorb::manager {

    namespace import ::xorb::*

    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # Staging
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # Broker
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #

    IDepository Broker -proc init args {
      # clear state
      if {[my exists bindings]} {
	my debug BEFORE-REFRESH-BINDINGS=[my array get bindings]
	my unset bindings
      }
      # current state of bindings
      my instvar bindings
      db_foreach [my qn init_bindings] {
	select contract_id, impl_id
	from acs_sc_bindings;
      } {

	lappend bindings($contract_id) $impl_id
	# 	set l [list]
	# 	if {[info exists bindings($contract_id)]} {
	# 	  set l $bindings($contract_id)
	# 	}
	#set bindings($contract_id) [lappend l $impl_id]
      }
      my debug AFTER-REFRESH-BINDINGS=[array get bindings]
    }
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # lookup semantics:
    # >> 1. ServiceContract + contract > contract given by contract id
    # >> 2. ServiceContract + impl > implemented contract of impl (id)
    # >> 3. ServiceImpl + impl > impl given by impl id
    # ? 4. ServiceImpl + contract > first impl for contract id
    # ? 5. ServiceContract / ServiceImpl + contract > 1. + 4.
    # >> 6. ServiceContract / ServiceImpl + impl > 2. + 3.
    # ? 7. ServiceContract / ServiceImpl + contract + impl
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #

    # # # # # # # # # # # # # # # # 
    # # # # # # # # # # # # # # # # 
    # # cleanup objects
    # # # # # # # # # # # # # # # # 
    # # # # # # # # # # # # # # # # 
    
    ServiceContract proc recreate {} {}
    ServiceImplementation proc recreate {} {}

    # # # # # # # # # # # # # # # # 
    # # # # # # # # # # # # # # # # 
    

    ServiceContract instproc grep {-contract -impl} {
      my instvar grep
      namespace import ::xorb::manager::*
      set cMiddle "contract"
      set iMiddle "impl"
      my debug "[self proc] called"
      # 1.
      if {[info exists $cMiddle] && [subst $$cMiddle] ne {}} {
	eval set cName $$cMiddle
      } elseif {[info exists $iMiddle] && [subst $$iMiddle] ne {}} {
	eval set iName $$iMiddle
	set iObj [::xorb::manager::IRepository resolve \
		      -name $iName]
	set cName [$iObj implements]
      }
      # / / / / / / / / / / / / 
      if {[info exists cName] && $cName ne {}} {
	my debug  cName=$cName
	set cObj [::xorb::manager::CRepository resolve \
		      -name $cName]
	if {$cObj ne {}} {
	  set grep($cMiddle) $cObj
	} else {
	  error "No contract named '$cName' found."
	}
      }
      my debug next=[self next]
      next 
    }

    ServiceImplementation instproc grep {-contract -impl} {
      my instvar grep
      namespace import ::xorb::manager::*
      set iMiddle "impl"
      my debug "[self proc] called"
      if {[info exists $iMiddle]} {
	# 3.
	eval set iName $$iMiddle
	if {![info exists contract]} {set contract ""}
	set obj [::xorb::manager::IRepository resolve \
		     -name $iName \
		     -contract $contract]
	if {$obj ne {}} {
	  my debug IMPLOBJ=$obj
	  set grep($iMiddle) $obj
	} else {
	  error "No implementation named '$iName' found."
	}
      }
      my debug next=[self next]
      next
    }

    # / / / / / / / / / / / / /
    # conditions
    # / / / / / / / / / / / / /
    ::xotcl::Class Boundness -instproc grep args {
      my instvar grep bindings
      set verified false
      my debug grep=[array get grep]
      # only contract requested
      if {[array size grep] == 1 && [info exists grep(contract)]} {
	set object_id [$grep(contract) object_id]
	set verified [info exists bindings($object_id)]
      } elseif {[array size grep] == 1 && [info exists grep(impl)]} {
	set iid [$grep(impl) object_id]
	set contract [$grep(impl) implements]
	set cObj [::xorb::manager::CRepository resolve -name $contract]
	set verified [expr {
			    [info exists bindings([$cObj object_id])] 
			    && [lsearch $bindings([$cObj object_id]) $iid] != -1
			  }]
      } elseif {[array size grep] == 2} {
	set iid [$grep(impl) object_id]
	set cid [$grep(contract) object_id]
	set verified [expr {
			    [info exists bindings($cid)] 
			    && [lsearch $bindings($cid) $iid] != -1
			  }]
      }
      my debug verified=$verified
      if {$verified} {
	next
      }
    }
    
    # / / / / / / / / / / / / /
    
    Broker proc grep args {
      my instvar grep
      if {[info exists grep]} {
	set r [array get grep]
	my debug +++GREP-RETURN=$r
	array unset grep
	return $r
      }
    }
    Broker proc lookup {-what:required {-conditions ""} args} {
      set mixinList [list $what $conditions]
      my debug LOOKUP=mixinList=[join $mixinList],args=$args
      my mixin [join $mixinList]
      # my debug mixinList=$mixinList
      set r [eval my grep $args]
      my mixin {}
      return $r
    }
    # / / / / / / / / / / / / / / / / / /
    # / / / / / / / / / / / / / / / / / /
    # NOTE: Finally, we identified the
    # reason for the mysterious bug
    # "wrong-#-args-should-be-stream"
    # encountered occasionally.
    # Background: We use ServiceImplementation
    # and ServiceContract as mixins for Broker.
    # These two mixin classes come with their own
    # zero-arg stream method. In cases of 
    # broker failures (look-up) due to a wrong
    # impl name etc., the mixin list of broker
    # might not get cleared. This causes follow-up
    # stream calls to the Broker to be first handled
    # by the mixin classes' methods.
    # Solution:
    # -1- We change the name of the former
    # Broker->stream method to Broker->get
    # -2- We provide for exception catching
    # and explicit cleanup.
    # / / / / / / / / / / / / / / / / / /
    # / / / / / / / / / / / / / / / / / /
    Broker proc cleanup {} {
      my mixin {}
    }
    Broker proc get args {
      array set stream [list]
      my cleanup
      if {[catch {
	array set retrieval [eval my lookup $args]
	# provide for streaming
	foreach item [array names retrieval] {
	# / / / / / / / / / / / / / / / / / / / /
	# free the item for the persistent mixin
	# for the purpose of streaming
	#$retrieval($item) mixin delete ::xorb::Persistent
	set stream($item) [eval Serializer deepSerialize $retrieval($item) \
			       [list -map [list $retrieval($item) "\[self\]::[$retrieval($item) canonicalName]"]]]
      }
	my debug "+++STREAM-RETURN:[array get stream]"
      } msg]} {
	global errorInfo
	# - explicit cleanup!
	my cleanup
	# - after cleanup, we provide for a re-throw.
	error $errorInfo
      }
      return [array get stream]
    } 
    Broker proc event {call args} {
      set c [my info class]
      if {[lsearch -exact [$c info instprocs] $call] != -1} {
	my debug "==calling==> $call $args"
	my debug "==info==> [my procsearch $call],[my serialize]"
	eval my $call $args
      }
    }

    # / / / / / / / / / / / / /

    Broker proc save {type id} {
      if {$type eq "::xorb::ServiceImplementation"} {
	my debug INIT=2
	my init
      }
    }
    Broker proc delete {type id} {
      my debug INIT=3
      my init
    }
    Broker proc update {type oldId newId} {
      my instvar bindings
      if {$type eq "::xorb::ServiceContract"} {
	# get bindings
	# iterate over bindings > conformance check
	# insert valid once
	my debug old=$oldId,newId=$newId,bindings=([array get bindings])
	if {[info exists bindings($oldId)]} {
	  set binds $bindings($oldId)
	  my debug "binds=$binds"
	  set refresh 0
	  foreach iid $binds {
	    # TODO:introduce conformance check here
	    set i [::xorb::manager::IRepository resolve -id $iid]
	    set ok [$i check]
	    my debug OK($iid)=$ok
	    if {$ok} {
	      ::xo::db::sql::acs_sc_binding new \
		  -contract_name [$i implements]\
		  -impl_name [$i impl_name]
	      set refresh 1
	    } else {
	      my debug [subst {
		WARNING: Implementation '[$i impl_name]' does not conform 
		to the referenced contract '[$i implements]' anymore
		after its contract's update.
	      }]
	    }
	  }
	  if {$refresh} {
	      my debug INIT=1c
	      my init
	  }
	}
      } elseif {$type eq "::xorb::ServiceImplementation"} {
	my debug INIT=1i
	my init
      }
    }
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # Base Class: Repository
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    
    ::xotcl::Class Repository -superclass IDepository -slots {
      Attribute itemType
    }
    Repository proc which {type} {
      foreach i [my allinstances] {
	if {[$i itemType] eq $type || \
		[$type info superclass [$i itemType]] ne ""} {return $i}
      }
    }
    Repository proc event {call type args} {
      
      set c [my info superclass]
      set target [my which $type]
      my debug "ENTER_MANAGER=>call=$call, type=$type, args=$args, target=$target, c=$c"
      if {$target ne {} && [lsearch -exact [$c info instprocs] $call] != -1} {
	my debug "==calling==> $target $call $args"
	eval $target $call $args
      }
    }
    Repository proc getAction {
	-type:required 
	-name:required 
	-sig:required 
	args
      } {
      set target [my which $type]
      if {$target ne {}} {
	return [$target [self proc] \
		    -name $name \
		    -sig $sig \
		    $args]
      }
    }
    Repository instproc init args {
      #my log "fetch=[my itemType] called"
      [my itemType] fetch -container [self] 
    }
    Repository instproc resolve {{-name *} {-id *}} {
      my instvar items
      if {$name eq "*" && $id eq "*"} {
	error "One accessor element, either 'name' or 'id', must be given."
      }
      
      set pairs [array get items $name,$id]
      my debug query=$name,$id/ITEM=$pairs/ITEMS=[array get items]
      set r [list]
      foreach {key object} $pairs {
	lappend r $object
      }
      return $r
    }
    Repository instproc update {oldId newId} {
      # recreate existing one
      set recreatee [my resolve -id $oldId]
      my debug recreatee=$recreatee,oldId=$oldId,newId=$newId
      if {$recreatee ne {}} {
	[$recreatee info class] mixin add ::xorb::Persistent::Recreate
	[$recreatee info class] $recreatee $newId
	[$recreatee info class] mixin delete ::xorb::Persistent::Recreate
      }
    }
    Repository instproc save {id} {
      my debug "SAVE=>id=$id"
      if {$id ne {}} {
	[my itemType] fetch -container [self] -id $id
      }
      # notify Broker >> bindings
      Broker event [self proc] [my itemType] $id
    }
    Repository instproc delete {id} { 
      my instvar items
      set victim [my resolve -id $id] 
      my debug "DELETE=>id=$id,victim=$victim"
      if {$victim ne {}} {
	set name [$victim name]
	$victim destroy
	unset items($name,$id)
      }
      # notify Broker >> bindings
      Broker event [self proc] [my itemType] $id
    }
    Repository instproc getAction {
      -name:required 
      -sig:required 
      args
    } {
      foreach {label value} $args break;
      switch -- $label {
	"-contract" {
	  set o [my resolve -name $name -contract $contract]
	}
	default {
	  set o [my resolve -name $name]
	}
      }

      my debug "o=$o, name=$name, orig-sig: $sig"
      array set status [list]
      # 1> does not exist?
      if {$o eq {}} {
	set status(action) save
	# 2> exists and modified?
      } elseif {$o ne {} && [$o getSignature] ne $sig} {
	my debug "==comp-stream==> [$o stream], comp-sig: [$o getSignature]"
	set status(action) update
	set status(object_id) [$o object_id]
	#3> exists and unmodified?
      } elseif {$o ne {} && [$o getSignature] eq $sig} {
	set status(action) ""
	set status(object_id) [$o object_id]
      }
      my debug "==status==> [array get status]"
      return [array get status]
    }
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # CRepository: persistent contracts
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #	
    
    Repository CRepository -itemType ::xorb::ServiceContract
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # CImplementation: persistent implementations
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #	
    
    Repository IRepository -itemType ::xorb::ServiceImplementation
    IRepository proc resolve {{-name *} {-id *} -contract} {
      set items [next -name $name -id $id];# Repository->resolve
      my debug RES-ITEMS=$items;
      if {[llength $items] > 0 && \
	      [info exists contract] && \
	      $contract ne {}} {
	foreach i $items {
	  my debug RES-i=$i,[$i implements]==$contract
	  if {[$i implements] eq $contract} {
	    return $i
	  }
	}
	error "Cannot resolve implementation unambiguously."
      } else {
	return $items
      }
    }
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    
    namespace export CRepository IRepository Broker
    
    }

} -persistent 1