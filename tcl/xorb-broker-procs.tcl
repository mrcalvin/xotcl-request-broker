ad_library {

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
	my unset bindings
      }
      # current state of bindings
      my instvar bindings
      db_foreach init_bindings {
	select contract_id, impl_id
	from acs_sc_bindings;
      } {
	set l [list]
	if {[info exists bindings($contract_id)]} {
	  set l $bindings($contract_id)
	}
	set bindings($contract_id) [lappend l $impl_id] 
      }
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
      my log "[self proc] called"
      # 1.
      if {[info exists $cMiddle] && [subst $$cMiddle] ne {}} {
	eval set cName $$cMiddle
      } elseif {[info exists $iMiddle] && [subst $$iMiddle] ne {}} {
	eval set iName $$iMiddle
	set iObj [IRepository resolve -name $iName]
	set cName [$iObj implements]
      }
      # / / / / / / / / / / / / 
      if {[info exists cName] && $cName ne {}} {
	my log cName=$cName
	set grep($cMiddle) [CRepository resolve -name $cName]
      }
      my log next=[self next]
      next 
    }

    ServiceImplementation instproc grep {-contract -impl} {
      my instvar grep
      namespace import ::xorb::manager::*
      set iMiddle "impl"
      my log "[self proc] called"
      if {[info exists $iMiddle]} {
	# 3.
	eval my log iName=$$iMiddle
	set grep($iMiddle) [eval IRepository resolve -name $$iMiddle]
      }
      my log next=[self next]
      next
    }

    # / / / / / / / / / / / / /
    # conditions
    # / / / / / / / / / / / / /
    ::xotcl::Class Boundness -instproc grep args {
      my instvar grep bindings
      set verified false
      my log grep=[array get grep]
      # only contract requested
      if {[array size grep] == 1 && [info exists grep(contract)]} {
	set id [$grep(contract) id]
	set verified [info exists bindings($id)]
      } elseif {[array size grep] == 1 && [info exists grep(impl)]} {
	set iid [$grep(impl) id]
	set contract [$grep(impl) implements]
	set cObj [CRepository resolve -name $contract]
	my log "STREAM-CHECK: cid=[$cObj id],iid=$iid,binds=[array get bindings]"
	set verified [expr {
			    [info exists bindings([$cObj id])] 
			    && [lsearch $bindings([$cObj id]) $iid] != -1
			  }]
      } elseif {[array size grep] == 2} {
	set iid [$grep(impl) id]
	set cid [$grep(contract) id]
	set verified [expr {
			    [info exists bindings($cid)] 
			    && [lsearch $bindings($cid) $iid] != -1
			  }]
      }
      my log verified=$verified
      if {$verified} {
	next
      }
    }
    
    # / / / / / / / / / / / / /
    
    Broker proc grep args {
      my instvar grep
      if {[info exists grep]} {
	set r [array get grep]
	my log +++GREP-RETURN=$r
	array unset grep
	return $r
      }
    }
    Broker proc lookup {-what:required {-conditions ""} args} {
      set mixinList [list $what $conditions]
      my log mixinList=[join $mixinList]
      my mixin [join $mixinList]
      # my log mixinList=$mixinList
      set r [eval my grep $args]
      my mixin {}
      return $r
    }
    Broker proc stream args {
      array set retrieval [eval my lookup $args]
      array set stream [list]
      # provide for streaming
      foreach item [array names retrieval] {
	set stream($item) [eval Serializer deepSerialize $retrieval($item) \
			       [list -map [list $retrieval($item) "\[self\]::[$retrieval($item) name]"]]]
      }
      my log "+++STREAM-RETURN:[array get stream]"
      return [array get stream]
    } 
    Broker proc event {call args} {
      set c [my info class]
      if {[lsearch -exact [$c info instprocs] $call] != -1} {
	my log "==calling==> $call $args"
	eval my $call $args
      }
    }

    # / / / / / / / / / / / / /

    Broker proc save {type id} {
      if {$type eq "::xorb::ServiceImplementation"} {
	my init
      }
    }
    Broker proc delete {type id} {
      my init
    }
    Broker proc update {type oldId newId} {
      my instvar bindings
      if {$type eq "::xorb::ServiceContract"} {
	# get bindings
	# iterate over bindings > conformance check
	# insert valid once
	my log old=$oldId,newId=$newId,bindings=([array get bindings])
	if {[info exists bindings($oldId)]} {
	  set binds $bindings($oldId)
	  my log "binds=$binds"
	  foreach iid $binds {
	    # TODO:introduce conformance check here
	    set insert {select acs_sc_binding__new($newId,$iid);}
	    lappend sql [subst $insert]
	  }
	  if {[info exists sql] && $sql ne {}} {
	    my log inserts=[join $sql]
	    db_exec_plsql update_binds [join $sql]
	  }
	}
      }
      my init
    }
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # Base Class: Respository
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    
    ::xotcl::Class Repository -superclass IDepository -slots {
      Attribute itemType
    }
    Repository proc which {type} {
      foreach i [my allinstances] {
	if {[$i itemType] eq $type || \
		[$type info superclass [$i itemType]]} {return $i}
      }
    }
    Repository proc event {call type args} {
      
      set c [my info superclass]
      set target [my which $type]
      my log "ENTER_MANAGER=>call=$call, type=$type, args=$args, target=$target, c=$c"
      if {$target ne {} && [lsearch -exact [$c info instprocs] $call] != -1} {
	my log "==calling==> $target $call $args"
	eval $target $call $args
      }
    }
    Repository proc getAction {type name sig} {
      set target [my which $type]
      if {$target ne {}} {
	return [$target [self proc] $name $sig]
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
      set item [array get items $name,$id]
      if {$item ne {}} {
	my log "==item==> $item"
	return [lindex $item 1]
      }  
    }
    Repository instproc update {oldId newId} {
      # recreate existing one
      set recreatee [my resolve -id $oldId]
      my log recreatee=$recreatee,oldId=$oldId,newId=$newId
      if {$recreatee ne {}} {
	[$recreatee info class] mixin add ::xorb::Persistent::Recreate
	[$recreatee info class] $recreatee $newId
	[$recreatee info class] mixin delete ::xorb::Persistent::Recreate
      }
    }
    Repository instproc save {id} {
      my log "SAVE=>id=$id"
      if {$id ne {}} {
	[my itemType] fetch -container [self] -id $id
      }
      # notify Broker >> bindings
      Broker event [self proc] [my itemType] $id
    }
    Repository instproc delete {id} { 
      my instvar items
      set victim [my resolve -id $id] 
      my log "DELETE=>id=$id,victim=$victim"
      if {$victim ne {}} {
	set name [$victim name]
	$victim destroy
	unset items($name,$id)
      }
      # notify Broker >> bindings
      Broker event [self proc] [my itemType] $id
    }
    Repository instproc getAction {name sig} {
      set o [my resolve -name $name]
      my log "o=$o, name=$name, orig-sig: $sig"
      array set status [list]
      # 1> does not exist?
      if {$o eq {}} {
	set status(action) save
	# 2> exists and modified?
      } elseif {$o ne {} && [$o getSignature] ne $sig} {
	my log "==comp-stream==> [$o stream], comp-sig: [$o getSignature]"
	set status(action) update
	set status(id) [$o id]
	#3> exists and unmodified?
      } elseif {$o ne {} && [$o getSignature] eq $sig} {
	set status(action) ""
	set status(id) [$o id]
      }
      my log "==status==> [array get status]"
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
    
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    # # # # # # # # # # # # # # # #
    
    namespace export CRepository IRepository Broker
    
  }

} -persistent 1