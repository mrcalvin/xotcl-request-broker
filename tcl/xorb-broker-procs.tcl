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
  
###############################
#
#	SCBroker
#
###############################

::xotcl::Object SCBroker 

  set comment {-ad_proc init args {} { 

		
		#my log "++++ init of [self] called."
		my instvar selector
		my set selector [eval ImplementationSelector new -childof [self] -set criterium [LabelBasedSelection new]]		
		
		
	      }}

SCBroker ad_proc getContract {-serialized:switch -name:required} {} {

	if { [db_0or1row select_contract {
			
				select distinct binds.contract_id        
		    		from   	acs_sc_bindings binds,
							acs_sc_contracts ctrs
					where   ctrs.contract_id = binds.contract_id
					and 		ctrs.contract_name = :name
					
			
			} ]} {
	
		if {$serialized} {

		    ServiceContractRepository::$contract_id mixin {}

		    my log ctr-children=[ServiceContractRepository::$contract_id info children]
			return [list $contract_id [eval ::Serializer deepSerialize "ServiceContractRepository::$contract_id"  [list -map {"ServiceContractRepository" ""}]]]
		
		} else {
		
			return $contract_id
		}
		
		
		}
		
		
	
	

}

SCBroker ad_proc getServant {-contractLabel:required -implLabel args} {} {

	my instvar selector
	
	# criterium selection / passing + fallback: $selector criterium 
	
	set contractID [my getContract -name $contractLabel]
	set boundImpls [list]
	
	db_foreach select_binding_impls_for_contract {
	
		select	binds.impl_id
		from		acs_sc_bindings binds
		where	binds.contract_id = :contractID
				
	} {
	
		lappend boundImpls $impl_id
		
	}

	
	
	
	set contract "ServiceContractRepository::$contractID"
	$selector contractLabel [$contract label]
	set impls	[$selector selectImpl -ids $boundImpls $implLabel]

	
	set itemsToSerialize [concat $contract $impls]
	set childrenAsList [list]
	
	
	set childrenAsList ""
	
	foreach item $itemsToSerialize {
		foreach child [$item info children] {
			append childrenAsList " " $child		
		}	
		
	
	}
	
	
	
	eval ::Serializer ignore $childrenAsList
	#my log "ignore list -> [::Serializer set skip]"
	set serializedCode	[eval ::Serializer deepSerialize $itemsToSerialize [list -map {"ServiceContractRepository" "" "ServiceImplRepository" ""}]]
	
	
	#my log "++++++ serializedCode (Broker) -> $serializedCode"
	return [list $contract $impls $serializedCode]
	

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
::xotcl::Object ServiceContractRepository 

  set comment {-ad_proc init {} {} {

	db_foreach defined_contracts_with_installed_binds {
	
			select distinct ctrs.contract_name, ctrs.contract_id, ctrs.contract_desc         
    		from   	acs_sc_contracts ctrs
    		
    		 
	
	} {

	set contrObj [eval ServiceContract [self]::$contract_id -mixin ::xorb::Retrievable -id $contract_id -label $contract_name -description {$contract_desc}]
	
	}

	# after all contracts have been processed, intialise all compound types declared in the contract
	# specifications (by calling CompoundTypeRepository)
	
	if {[::xorb::CompoundTypeRepository exists initCompounds]} {
		eval [::xorb::CompoundTypeRepository set initCompounds]
	}

}
  }

ServiceContractRepository ad_proc verify {-label:required -sig:required args} {} {

	# return code 0: simple synchronize
	# return code 1: synchronize (delete / re-insert)
	# return code 2: no need for sync
	
	set candidateObj ""
	
	foreach child [my info children] {
	
		if {[string equal [$child label] $label]} {
		
			set candidateObj $child
			break
		}  	
	}
	
	#my log "+++ candidate: $candidateObj"
	#my log "+++ candidate's id: [$candidateObj set id]"
	
	if {$candidateObj != ""} {
	
		set v [ArrayListBuilderVisitor new]
		$child accept $v
		set rightSig [$v getSignature]
		my log "RIGHT(stored): |[$v asString]| ===$rightSig=$sig===: [string equal $rightSig $sig]"
		return [expr {$rightSig eq $sig ? 1 : [$candidateObj set id]}]
		#return [expr {[expr {[$v getSignature] == $sig}] ? 1 : [$candidateObj set id]}]
		
	
	} else {
	
		return 0;
	}
	

}

ServiceContractRepository ad_proc synchronise {-id:required} {} {

	if {[my isobject [self]::$id]} {
		[self]::$id destroy	
	}
	
	if {![catch {db_1row sync_impl {
	
		select distinct ctrs.contract_name, ctrs.contract_id, ctrs.contract_desc         
    		from   	acs_sc_contracts ctrs
			where   ctrs.contract_id = :id
	
	}} msg]} {
	
		eval ServiceContract [self]::$contract_id -mixin ::xorb::Retrievable -id $contract_id -label $contract_name -description {$contract_desc}
	
	}	

}

ServiceContractRepository ad_proc show {obj} {} {

	$obj log [$obj info children]
	foreach child [$obj info children] {
	
		$obj log [::Serializer deepSerialize $child]
		#my show $child
	
	}

}






  ############################################
  #
  #
  #	Criterium: selection specifications
  #
  #
  ############################################


::xorb::aux::BottomUpComposite Criterium -parameter {contractLabel implLabel} 
#Criterium abstract instproc isSatisfiedBy {-impl:required}
Criterium addOperations "isSatisfiedBy"

::xotcl::Class LabelBasedSelection -superclass Criterium

LabelBasedSelection ad_instproc isSatisfiedBy {-impl:required} {} {


	if {[$impl istype ::xorb::ServiceImplementation]} {
	
			
			return [expr {[string equal [$impl contractName] [my contractLabel]] && [my exists implLabel] ? [string equal [my implLabel] [$impl label]] : false}]  
	
	} else {
	
			return false
	
	}
	
}
	

# fallback criterium

::xotcl::Class FirstComeFirstOut -superclass Criterium

FirstComeFirstOut ad_instproc init args {} {

	my set isdone false

}

FirstComeFirstOut ad_instproc isSatisfiedBy {-impl:required} {} {

	my instvar isdone

	if {!$isdone} {
	
	#	my log "impl to check: $impl"
		set result [ expr { [$impl istype ::xorb::ServiceImplementation] && [string equal [$impl contractName] [my contractLabel]] }]
		
		set isdone [expr {$result ? "true" : "false"}]
		
		return $result
	
	} else {
	
		return false
	
	}
	
}  

############################
#
#	ImplementationSelector
#
############################

::xotcl::Class ImplementationSelector -parameter {contractLabel} 

ImplementationSelector ad_instproc selectImpl {-ids:required implLabel} {} {
	
	my instvar criterium contractLabel
	
	set matchingImpl [list]	
	$criterium contractLabel $contractLabel
	$criterium implLabel $implLabel
	
	# test for binding state - ping db
	#my log "++++ ids: $ids"	
	if {[my exists criterium]} {
		
		
	
		foreach implClass $ids {
			
			
			#my log "++++ $criterium: [$criterium info methods]"
			set result [eval $criterium isSatisfiedBy -impl "::xorb::ServiceImplRepository::$implClass"]
			#my log "++++ selectImpl crit 3 ($implClass): $result"
			
			expr {$result ? [lappend matchingImpl "::xorb::ServiceImplRepository::$implClass"] : ""}
		
		} 
		
		
	
	} else {
	
		my log "Pre-conditions for impl selection not met."
	
	}
	
	# general fallback (first implementation of contract will be returned)
	
#	my log "impls found? [llength $matchingImpl]"
	#my log "matches: $matchingImpl"
	
	if {[llength $matchingImpl] == 0} {
	
		#my log "Iamhere"
		my set criterium [FirstComeFirstOut new]
		set matchingImpl [my selectImpl -ids $ids $implLabel]
	
	}
	 
	return $matchingImpl  

}


::xotcl::Object CompoundTypeRepository 

set comment {-ad_proc init {} {} {

	##########################
	#
	#	retrieve a list of compound types (and their ids) registered in the backend;
	#	will be used to initialise a compound type under the CompoundTypeRepository
	#	as soon as it is first declared / used in a contract specification; also available
	#	for an on-demand intialisation.
	#
	##########################
	
	db_foreach get_compounds_plus_ids {
		select distinct
			t.msg_type_name,
			t.msg_type_id
		from acs_sc_msg_type_elements e,
	 		acs_sc_msg_types t
		where 
			e.msg_type_id = t.msg_type_id
		and
			t.msg_type_name not like '%.InputType' 
		and
			t.msg_type_name not like '%.OutputType';
	} {
		my set compounds($msg_type_name) $msg_type_id
	}
	
	#if {[my exists compounds]} {
	#	my log "retrieved compounds: [my array get compounds]"
	#	
	#}
}
}
	
	
CompoundTypeRepository ad_proc retrieve {-name:required} {} {
	
	my instvar compounds 
	if {![my isobject [self]::$name]} {
		
		if {[info exists compounds($name)]} {
			::xorb::aux::Dict create ::xorb::CompoundTypeRepository::$name -mixin ::xorb::RetrievableType -id $compounds($name)
			return [::Serializer deepSerialize [self]::$name -map {"::xorb::CompoundTypeRepository::" "\[self\]::__"}]
		}
		
	} else {
	
		set s [::Serializer deepSerialize [self]::$name -map {"::xorb::CompoundTypeRepository::" "\[self\]::__"}]
		#my log "sType: $s"
		return $s
	}
}
	
CompoundTypeRepository ad_proc show {} {} {
	
	my log "Loaded CompoundTypes: [my info children]"

}
	

::xotcl::Class RetrievableType -parameter {id}

RetrievableType ad_instproc init args {} {

	my [namespace tail [my info class]]
	next
}

RetrievableType ad_instproc Dict {} {} {
			
				my instvar id
				CompoundTypeRepository instvar compounds
				
				array set container [list]
				set cmds ""
				db_foreach get_compound_elements_for_id {
					select 
						e.element_name,
						t.msg_type_name
					from 
						acs_sc_msg_type_elements e,
						acs_sc_msg_types t
					where 
						e.element_msg_type_id = t.msg_type_id
					and
						e.msg_type_id = :id
				} {
				
					set container($element_name) $msg_type_name
					
				}
				
			  foreach element_name [array names container] {
			  		
			  		set msg_type_name $container($element_name)
			  	#	my log "msg_type: $msg_type_name, label: $element_name, iscompound: [info exists compounds($msg_type_name)]"
					if {[info exists compounds($msg_type_name)]} {
							
						if {![my isobject ::xorb::CompoundTypeRepository::$msg_type_name]} {
							::xorb::aux::Dict create ::xorb::CompoundTypeRepository::$msg_type_name  -mixin ::xorb::RetrievableType -id $compounds($msg_type_name)
						}
						
						append cmds "::xorb::aux::Dict::__Pointer $element_name -substitute ::xorb::aux::Dict::$msg_type_name\n"
					
					} else {
					
						append cmds "::xorb::aux::[string toupper $msg_type_name 0 0] $element_name\n"
					
					} 
			  }
							
		#	  my log "cmds=$cmds, instmixins=[Object info instmixin]"	
			  my contains $cmds
			 
			

}


::xotcl::Object ServiceImplRepository 

set comment {-ad_proc init {} {} {	

	
	db_foreach boundImpl {
	
			select distinct ia.impl_name, ia.impl_id, impls.impl_pretty_name,
									impls.impl_owner_name,
									impls.impl_contract_name
									        
    		from   	acs_sc_bindings binds,
           			acs_sc_impl_aliases ia,
           			acs_sc_impls impls
    		where  	ia.impl_id = impls.impl_id 
    		
    		} {
	
	my log "impl_name: $impl_name, impl_id: $impl_id, impl_pretty_name: $impl_pretty_name, impl_owner_name: $impl_owner_name, impl_contract_name: $impl_contract_name"
	
	
	
	set implObj [eval ServiceImplementation [self]::$impl_id -mixin ::xorb::Retrievable -id $impl_id -label {$impl_name} -prettyName {$impl_pretty_name} -owner {$impl_owner_name} -contractName $impl_contract_name]
	
	#SCBroker add $implObj
		
	#my log "Created and nested $implObj"
	
	}
	
	
	
	

}
} 

ServiceImplRepository ad_proc verify {-label:required -implContract:required -sig:required args} {} {

	# return code 0: simple synchronize
	# return code 1: synchronize (delete / re-insert)
	# return code 2: no need for sync

	set candidateObj ""
	
	foreach child [my info children] {
	
		if {[string equal [$child label] $label] && [string equal [$child contractName] $implContract]} {
		
			set candidateObj $child
			break
		}  	
	}
	
	if {$candidateObj != ""} {
	
		set v [ArrayListBuilderVisitor new -volatile]
		$child accept $v
		my log "RIGHT(stored): [$v asString]"
		return [expr {[expr {[$v getSignature] == $sig}] ? 1 : [$candidateObj set id]}]
	
	} else {
	
		return 0;
	}
	

}

ServiceImplRepository ad_proc synchronise {-id:required} {} {

	if {[my isobject [self]::$id]} {
		[self]::$id destroy	
	}
	
	if {![catch {db_1row sync_impl {
	
		select distinct ia.impl_name, ia.impl_id, impls.impl_pretty_name,
									impls.impl_owner_name,
									impls.impl_contract_name          
    		from   	acs_sc_impl_aliases ia,
           			acs_sc_impls impls
    		where  	ia.impl_id = impls.impl_id
			and		impls.impl_id = :id
	
	}} msg]} {
	
		my log "impl_name: $impl_name, impl_id: $impl_id, impl_pretty_name: $impl_pretty_name, impl_owner_name: $impl_owner_name, impl_contract_name: $impl_contract_name"
	
		eval ServiceImplementation [self]::$impl_id -mixin ::xorb::Retrievable -id $impl_id -label {$impl_name} -prettyName {$impl_pretty_name} -owner {$impl_owner_name} -contractName $impl_contract_name
	
	}	

}

CompoundTypeRepository show

namespace export CRepository IRepository Broker

}

} -persistent 1