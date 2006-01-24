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

::xotcl::Class FirstComeFirstOut -superclass ::xorb::Criterium -set isdone false
FirstComeFirstOut ad_instproc isSatisfiedBy {-impl:required} {} {

	my instvar isdone
	#my log "Iamnothere2"
	if {!$isdone} {
	
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
	my instvar criterium
	my set criterium [::xorb::LabelBasedSelection lbsCriterium]
	#my log "++++ criterium type: $criterium -> [$criterium info class]"

}

ImplementationSelector ad_instproc selectContract {contractLabel} {} {
	
	set contracts [::xorb::ServiceContractRepository info children]
	my set contractLabel $contractLabel
	#my log "contract objs: $contracts, contract label: $contractLabel, lsearch: [lsearch $contracts "::xorb::ServiceContractRepository::$contractLabel"]"
	
	set resultObj ""
	
	foreach contractObj $contracts {
	
		if {[$contractObj istype ::xorb::ServiceContract] && [my exists contractLabel]} {
	
			set isdone [string equal [my contractLabel] [$contractObj label]] 
			if {$isdone} {
			
				set resultObj $contractObj
				break
			
			} 
	
		}
	
	} 
	
	return $resultObj

}

ImplementationSelector ad_instproc selectImpl {implLabel} {} {
	
	my instvar criterium contractLabel
	
	set matchingImpl [list]	
	$criterium contractLabel $contractLabel
	$criterium implLabel $implLabel
	
		
	if {[my exists criterium]} {
		
		
	
		foreach implClass [::xorb::ServiceImplRepository info children] {
			
			
			#my log "++++ $criterium: [$criterium info methods]"
			set result [eval $criterium isSatisfiedBy -impl $implClass]
			#my log "++++ selectImpl crit 3 ($implClass): $result"
			
			expr {$result ? [lappend matchingImpl $implClass] : ""}
		
		} 
		
		
	
	} else {
	
		my log "Pre-conditions for impl selection not met."
	
	}
	
	# general fallback (first implementation of contract will be returned)
	
	if {[llength matchingImpl] == 0} {
	
		#my log "Iamnothere"
		my set criterium [::xorb::FirstComeFirstOut new]
		set matchingImpl [my selectImpl $implLabel]
	
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
		my set selector [eval ::xorb::ImplementationSelector is]		
		#my log "++++ $selector created."	

}
SCBroker ad_proc getServant {-contractLabel:required -implLabel args} {} {

	my instvar selector
	
	# criterium selection / passing + fallback: $selector criterium 
	
	
	
	set contract	[$selector selectContract $contractLabel]
	set impls	[$selector selectImpl $implLabel]
	
	#my log "identified contract: $contract"
	my log "identified impl: $impls"
	my log "$impls's method arsenal: [$impls info instprocs]"
	
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
	
	
	my log "++++++ serializedCode (Broker) -> $serializedCode"
	return [list $contract $impls $serializedCode]
	

} 

::xotcl::Object ServiceContractRepository -ad_proc init {} {} {

	db_foreach defined_contracts_with_installed_binds {
	
			select distinct ctrs.contract_name, ctrs.contract_id, ctrs.contract_desc         
    		from   	acs_sc_bindings binds,
           			acs_sc_contracts ctrs
    		where  ctrs.contract_id = binds.contract_id 
	
	} {
	
	#my log "contract_id: $contract_id, contract_name: $contract_name, contract_desc: $contract_desc"
	set contrObj [eval ServiceContract [self]::[my autoname SContr] -mixin ::xorb::Recoverable -id $contract_id -label $contract_name -description {$contract_desc}]
	#my log "Created and nested $contrObj"
	}

	#my show [self]

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
    		where  	ia.impl_id = binds.impl_id 
    		and 	binds.impl_id = impls.impl_id 
    		
    		} {
	
	#my log "impl_name: $impl_name, impl_id: $impl_id, impl_pretty_name: $impl_pretty_name, impl_owner_name: $impl_owner_name, impl_contract_name: $impl_contract_name"
	
	
	
	set implObj [eval ServiceImplementation [self]::[my autoname SImpl] -mixin ::xorb::Recoverable -id $impl_id -label {$impl_name} -prettyName {$impl_pretty_name} -owner {$impl_contract_name} -contractName $impl_contract_name]
		
	#my log "Created and nested $implObj"
	
	}
	
	
	
	

} 
}
} -persistent 1