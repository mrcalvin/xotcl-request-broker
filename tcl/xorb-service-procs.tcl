namespace eval xorb::service {

	::xotcl::Class Service -superclass ::xotcl::Class 
	
	Service ad_instproc unknown {method args} {} {
	
		 set shadow [my new -childof [self] -volatile]
		 eval $shadow $method $args
	
	}


}