ad_library {

	@author stefan.sobernig@wu-wien.ac.at
    @creation-date January 30, 2006
    @cvs-id $Id$

}


::xotcl::THREAD create XorbContainer { 


namespace eval xorb {

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

::xotcl::Class LabelBasedSelection -superclass ::xorb::Criterium

LabelBasedSelection ad_instproc isSatisfiedBy {-impl:required} {} {


	if {[$impl istype ::xorb::ServiceImplementation]} {
	
			
			return [expr {[string equal [$impl contractName] [my contractLabel]] && [my exists implLabel] ? [string equal [my implLabel] [$impl label]] : false}]  
	
	} else {
	
			return false
	
	}
	
}
	

# fallback criterium

::xotcl::Class FirstComeFirstOut -superclass ::xorb::Criterium

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
		my set criterium [::xorb::FirstComeFirstOut new]
		set matchingImpl [my selectImpl -ids $ids $implLabel]
	
	}
	 
	return $matchingImpl  

}

###############################
#
#	SCBroker
#
###############################

::xotcl::Object SCBroker -ad_proc init args {} { 

		
		#my log "++++ init of [self] called."
		my instvar selector
		my set selector [eval ::xorb::ImplementationSelector new -childof [self] -set criterium [::xorb::LabelBasedSelection new]]		
		
		
}

SCBroker ad_proc getContract {-serialized:switch -name:required} {} {

	if { [db_0or1row select_contract {
			
				select distinct binds.contract_id        
		    		from   	acs_sc_bindings binds,
							acs_sc_contracts ctrs
					where   ctrs.contract_id = binds.contract_id
					and 		ctrs.contract_name = :name
					
			
			} ]} {
	
		if {$serialized} {
			
			return [list $contract_id [eval ::Serializer deepSerialize "::xorb::ServiceContractRepository::$contract_id"  [list -map {"::xorb::ServiceContractRepository" ""}]]]
		
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

	
	
	
	set contract "::xorb::ServiceContractRepository::$contractID"
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
	set serializedCode	[eval ::Serializer deepSerialize $itemsToSerialize [list -map {"::xorb::ServiceContractRepository" "" "::xorb::ServiceImplRepository" ""}]]
	
	
	#my log "++++++ serializedCode (Broker) -> $serializedCode"
	return [list $contract $impls $serializedCode]
	

} 

::xotcl::Object CompoundTypeRepository -ad_proc init {} {} {

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
	
::xotcl::Class Retrievable -parameter {id}

Retrievable ad_instproc init {} {} {
		
		
		my instvar id {prettyName impl_pretty_name} {owner impl_owner_name} {contractName impl_contract_name} 
		
		
		switch [my info class] {
		
			"::xorb::ServiceContract" {  
			
				my instvar id 
				set cmd ""				
				#my log "Populated [self] with dbID: $id, description: [my description]"
				
				# populate contract object with affiliated operation objects
				
				db_foreach select_ops_for_contract {
				
					select	ops.operation_id, ops.operation_name, ops.operation_desc  
					from   	acs_sc_operations ops
					where  	ops.contract_id = :id
				
				} {
				
				
				append cmd "::xorb::Operation new -mixin ::xorb::Retrievable -label $operation_name -description {$operation_desc} -id $operation_id\n"
				
				}
				
				#my log "[self]'s cmd: $cmd"
				my contains $cmd				
			#	my log "[self]'s children: [my info children]"
			
			}
			"::xorb::Operation" {
			
				my instvar id 
				set cmd ""
				db_foreach select_sigelements_for_op {
				
					select	msgs.msg_type_id, msgs.msg_type_name 
					from   	acs_sc_operations ops,
							acs_sc_msg_types msgs
					where  	ops.operation_id = :id
					and		(ops.operation_inputtype_id = msgs.msg_type_id
					or		ops.operation_outputtype_id = msgs.msg_type_id)
				
				} {
				
				set typeToNest [expr {[expr {[string first "InputType" $msg_type_name] != -1}] ? "Input" : "Output"}]				
				append cmd "::xorb::$typeToNest new -mixin ::xorb::Retrievable -label $msg_type_name -id $msg_type_id\n"
					
					
				
				}
				
				#my log $cmd
				my contains $cmd
			
			}
			"::xorb::Input" {
			
				# set an ordering / sorting regime (argument position)
				
				my orderby -order "increasing" "position"
				
				# create nested and sorted subtree of argument objects
				my instvar id
				set cmd ""
				db_foreach select_args {
				
					select	el.element_name, msgs.msg_type_name, el.element_pos, el.element_msg_type_isset_p, el.element_constraints
					from   	acs_sc_msg_type_elements el,
							acs_sc_msg_types msgs
					where  	el.msg_type_id = :id
					and		el.element_msg_type_id = msgs.msg_type_id
				
				} {
				
					#my log "+++isset: $element_msg_type_isset_p, constraint: {$element_constraints}"
					
					if {$element_msg_type_isset_p && $element_constraints ne [db_null]} {
						set msg_type_name "$msg_type_name$element_constraints"
					}
					
					append cmd "::xorb::Argument new -label $element_name -datatype {$msg_type_name} -position $element_pos\n"
					
					::xorb::CompoundTypeRepository instvar compounds
					#my log "msg_type: $msg_type_name, label: $element_name, iscompound: [info exists compounds($msg_type_name)]"
					if {[info exists compounds($msg_type_name)]} {
						::xorb::CompoundTypeRepository append initCompounds "::xorb::aux::Dict create ::xorb::CompoundTypeRepository::$msg_type_name -mixin ::xorb::RetrievableType -id $compounds($msg_type_name)\n"
					}
					
				
				}
			#	my log cmd=$cmd
				my contains $cmd
			
			}
			"::xorb::Output" {
			
			
				# impose a sorting regime on sub-composite
				my orderby -order "increasing" "position"
				
				# nest a returnvalue object 
				
				my instvar id
				set cmd ""
				db_foreach select_rtv {
				
					select	el.element_name, msgs.msg_type_name, el.element_pos 
					from   	acs_sc_msg_type_elements el,
							acs_sc_msg_types msgs
					where  	el.msg_type_id = :id
					and		el.element_msg_type_id = msgs.msg_type_id
				
				} {
				
					append cmd "::xorb::ReturnValue new -label $element_name -datatype $msg_type_name -position $element_pos\n"
					
					::xorb::CompoundTypeRepository instvar compounds
				#	my log "msg_type: $msg_type_name, label: $element_name, iscompound: [info exists compounds($msg_type_name)]"
					if {[info exists compounds($msg_type_name)]} {
						::xorb::CompoundTypeRepository append initCompounds "::xorb::aux::Dict create ::xorb::CompoundTypeRepository::$msg_type_name  -mixin ::xorb::RetrievableType -id $compounds($msg_type_name)\n"
					}
					
				}
				
				my contains $cmd
					
			}
			"::xorb::ServiceImplementation" 	{
			
				my instvar id
			
				set cmd ""
				
				db_foreach select_aliases_for_impl {
				
					select 	al.impl_operation_name,
							al.impl_alias
					from	acs_sc_impl_aliases al
					where 	al.impl_id = :id
				
				} {
				
				append cmd "::xorb::Alias new -label $impl_operation_name -servantMethod $impl_alias\n"
				
				}
				
				my contains $cmd
				
				#my log "[self]'s children: [my info children]"
				
				
			
			}
		}
		
		
		next
	
	}


::xotcl::Class RetrievableType -parameter {id}

RetrievableType ad_instproc init args {} {

	my [namespace tail [my info class]]
	next
}

RetrievableType ad_instproc Dict {} {} {
			
				my instvar id
				::xorb::CompoundTypeRepository instvar compounds
				
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
	
		
::xotcl::Object ServiceContractRepository -ad_proc init {} {} {

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

::xotcl::Object ServiceImplRepository -ad_proc init {} {} {	

	
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

}

} -persistent 1