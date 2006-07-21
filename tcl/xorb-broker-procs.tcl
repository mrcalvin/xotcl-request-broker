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
	my log "Iamhere2"
	my log "isdone exists: [my exists isdone]"
	my log "isdone: $isdone"
	if {!$isdone} {
	
		my log "impl to check: $impl"
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

ImplementationSelector ad_instproc init args {} {

	#my log "constructor of ImplSel is called"
	#my instvar criterium
	#my set criterium [::xorb::LabelBasedSelection lbsCriterium]
	#my log "++++ criterium type: $criterium -> [$criterium info class]"

}

#ImplementationSelector ad_instproc selectContract {contractLabel} {} {
#	
#	set contracts [::xorb::ServiceContractRepository info children]
#	my set contractLabel $contractLabel
	#my log "contract objs: $contracts, contract label: $contractLabel, lsearch: [lsearch $contracts "::xorb::ServiceContractRepository::$contractLabel"]"
#	
#	set resultObj ""
#	
#	foreach contractObj $contracts {
#	
#		if {[$contractObj istype ::xorb::ServiceContract] && [my exists contractLabel]} {
#	
#			set isdone [string equal [my contractLabel] [$contractObj label]] 
#			if {$isdone} {
#			
#				set resultObj $contractObj
#				break
#			
#			} 
#	
#		}
#	
#	} 
#	
#	return $resultObj
#
#}

ImplementationSelector ad_instproc selectImpl {-ids:required implLabel} {} {
	
	my instvar criterium contractLabel
	
	set matchingImpl [list]	
	$criterium contractLabel $contractLabel
	$criterium implLabel $implLabel
	
	# test for binding state - ping db
	my log "++++ ids: $ids"	
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
	
	my log "impls found? [llength $matchingImpl]"
	my log "matches: $matchingImpl"
	
	if {[llength $matchingImpl] == 0} {
	
		my log "Iamhere"
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
	
	#db_foreach select_binding_pairs {
	#
	#	select binds.contract_id, binds.impl_id        
    	#	from   	acs_sc_bindings binds,
	#				acs_sc_contracts ctrs,
	#				acs_sc_impls impls
	#		where   ctrs.contract_id = binds.contract_id
	#		and 	impls.impl_id = binds.impl_id			
	#		and 	impls.impl_contract_name = :contractLabel
	#		and		impls.impl_contract_name = ctrs.contract_name
	#
	#} {
	#	set contractID $contract_id
	#	lappend boundImpls $impl_id
	#
	#}
	
	#my log "binding pairs: $boundImpls"
	
	
	
	set contract "::xorb::ServiceContractRepository::$contractID"
	$selector contractLabel [$contract label]
	set impls	[$selector selectImpl -ids $boundImpls $implLabel]
	#my log "impls in getServant: $impls"
	#my log "identified contract: $contract"
	#my log "identified impl: $impls"
	#my log "$impls's method arsenal: [$impls info instprocs]"
	
	# strip off child objects for the purpose of serialization
	
	set itemsToSerialize [concat $contract $impls]
	set childrenAsList [list]
	
	#my log "itemsToSerialize $itemsToSerialize"
	
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

::xotcl::Object ServiceContractRepository -ad_proc init {} {} {

	db_foreach defined_contracts_with_installed_binds {
	
			select distinct ctrs.contract_name, ctrs.contract_id, ctrs.contract_desc         
    		from   	acs_sc_contracts ctrs
    		
    		 
	
	} {
	
	#where  ctrs.contract_id = binds.contract_id, where ctrs.contract_id = 2136
	#my log "contract_id: $contract_id, contract_name: $contract_name, contract_desc: $contract_desc"
	set contrObj [eval ServiceContract [self]::$contract_id -mixin ::xorb::Retrievable -id $contract_id -label $contract_name -description {$contract_desc}]
	#my log "Created and nested $contrObj"
	#my log "~~~~ [$contrObj info methods]"
	#my log "~~~~ [::Serializer deepSerialize $contrObj]"
	
	#SCBroker add $contrObj
	
	}

	#my show [self]

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
	
		set v [ArrayListBuilderVisitor new -volatile]
		$child accept $v
		return [expr {[expr {[$v getSignature] == $sig}] ? 1 : [$candidateObj set id]}]
	
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
	
	#my log "impl_name: $impl_name, impl_id: $impl_id, impl_pretty_name: $impl_pretty_name, impl_owner_name: $impl_owner_name, impl_contract_name: $impl_contract_name"
	
	
	
	set implObj [eval ServiceImplementation [self]::$impl_id -mixin ::xorb::Retrievable -id $impl_id -label {$impl_name} -prettyName {$impl_pretty_name} -owner {$impl_contract_name} -contractName $impl_contract_name]
	
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
	
		eval ServiceImplementation [self]::$impl_id -mixin ::xorb::Retrievable -id $impl_id -label {$impl_name} -prettyName {$impl_pretty_name} -owner {$impl_contract_name} -contractName $impl_contract_name
	
	}	

}

}
} -persistent 1