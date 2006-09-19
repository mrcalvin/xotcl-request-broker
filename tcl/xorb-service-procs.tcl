ad_library {
    
    xorb service classes
    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date January 30, 2006
    @cvs-id $Id$
    
}

###################################
#	test
###################################


namespace eval xorb::service {


###################################
#
#
#	Service class, allows for realising
#	a "reference implementation" (servant +
#	service implementation) for an existing
#	contract.
#
#
###################################


::xotcl::Class Service -superclass ::xotcl::Class -parameter {implements package} -ad_doc {} 

Service ad_instproc init {} {} {
	
		if {[my exists implements]} {
		my instvar refImplementation implements package
		
		
		set refImplementation [::xorb::ServiceImplementation new -childof [self] -label [namespace tail [self]] -prettyName "Reference Implementation for $implements" -contractName $implements -owner $package]
		ad_after_server_initialization "[self]'s injection" "[self] inject"
		} 
		next
		
	
	}  
	
Service instproc ad_instproc  {
   {-private:switch false}
   {-deprecated:switch false}
   {-warn:switch false}
   {-debug:switch false}
   {-operation:switch false}
  proc_name arguments doc body} {
    	
  #  	my log "private: $private, depr: $deprecated, warn: $warn, debug: $debug, operation: $operation"
  #  	my log "proc_name: $proc_name, arguments: $arguments, doc: $doc, body: $body"
    	
    	 	    	    	
    	if {[my exists refImplementation] && $operation} {
    		
    		my instvar refImplementation
    		set cmd "::xorb::Alias new -label $proc_name -servantMethod [self]::$proc_name"
    		$refImplementation contains "$cmd"       		
    		
    		}
    	
   # 	my log "++++ [self] am called."
    	
    	#uplevel [list [self] instproc $proc_name $arguments $body]
    	uplevel [list [self] instproc $proc_name $arguments $body]
    	my __api_make_doc inst $proc_name
    		
   # 	my log "++++ methods: [[self] info methods]"	
    	#next
    
  }
	
Service ad_instproc inject {} {} {

	if {[my exists refImplementation]} {
		my instvar refImplementation
		$refImplementation mixin ::xorb::Storable
		$refImplementation init
	}
	
	next

}

###################################
#
#
#	InstantService class, allows for realising
#	a ready-made service (servant +
#	service implementation + service contract).
#
#
###################################

::xotcl::Class InstantService -superclass ::xorb::service::Service -ad_doc {}

InstantService ad_instproc init {} {} {
	
		my instvar instantContract implements
		my set instantContract [::xorb::ServiceContract new -childof [self] -label [namespace tail [self]] -description "Instant Contract exposing Service [namespace tail [self]]"]
		set implements [$instantContract label]
		next
		
	
	}  
	
InstantService instproc ad_instproc  {
   {-private:switch false}
   {-deprecated:switch false}
   {-warn:switch false}
   {-debug:switch false}
   {-operation:switch false}
  proc_name arguments doc body} {
  		
  		if {[my exists instantContract] && $operation} {
    		
    		my instvar instantContract
    		
    		# input
    		
    	#	my log "++++ [self]: [[self] info methods]"
    		
    		#set nonposArgs [my info nonposargs $proc_name]
    		#my log "++++ $arguments"
    		set argObjs ""
    		foreach nonposArg $arguments {
    			
    			if {[string index $nonposArg 0] == "-"} {
    			#if {[string first "\[" $nonposArg] != -1} {
    			#	set nonposArg [string range $nonposArg 0 [expr {[string first "\[" $nonposArg] - 1 }]]
    			#}
    			set pair [split $nonposArg ":"]
    			append argObjs "::xorb::Argument new -label [string trimleft [lindex $pair 0] "-"]  -datatype {[lindex $pair 1]}\n"
    			}
    		}
    		#my log "++++ $argObjs"
    		set input "::xorb::Input new -contains {$argObjs}\n"
    		
    		#output
    		
    		set output "::xorb::Output new -contains { ::xorb::ReturnValue new -label returnValue -datatype string }"
    		
    		
    		# output
    		
    		set operationSignature "::xorb::Operation new -label $proc_name -description {$doc} -contains { $input $output }"
    		
    		#my log "opSig: $operationSignature"
    		
    		$instantContract contains $operationSignature       		
    		
    		}
    		
    		next 
  
  }
  
  InstantService ad_instproc inject {} {} {

	if {[my exists instantContract]} {
		my instvar instantContract
		$instantContract mixin ::xorb::Storable
		$instantContract init
	}
	
	next

}


}

