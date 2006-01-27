ad_library {
    
    xorb service classes
    
}

###################################
#	test
###################################

#ad_proc ::xorb::test args {} {set spec {name {myContract} description {desc_of_my_contract} operations  { MyOperation {  description {first op stipulated by my contract} input {arg1:string} output {object_type:string} }}}

#my log "++++ acs_sc::contract::new: [acs_sc::contract::new -name "MyContract" -description "desc"]"
#}

#eval ::xorb::test

namespace eval xorb::service {

	::xotcl::Class Specification -superclass ::xorb::aux::Slot -parameter {refersto multiplicity}

	::xotcl::Class Service -superclass ::xotcl::Class -contains {
	
		::xorb::service::Specification contract -refersto ::xorb::ServiceContract
		::xorb::service::Specification implementation -refersto ::xorb::ServiceImplementation
	
	}
		
	Service ad_instproc unknown {method args} {} {
	
		 set shadow [my new -childof [self] -volatile]
		 eval $shadow $method $args
	
	}

}

