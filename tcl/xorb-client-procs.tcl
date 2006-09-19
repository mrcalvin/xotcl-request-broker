ad_library {

	

	@author stefan.sobernig@wu-wien.ac.at
    @creation-date July, 25 2006
    @cvs-id $Id: xorb-broker-procs.tcl 11 2006-07-25 01:59:33Z ssoberni $

}


namespace eval xorb::client {

	# +---------------------------+
	# | meta class                |
	# | Stub                      |
	# | -realising "object stubs"|
	# |                           |
	# +---------------------------+


::xotcl::Class Stub -superclass ::xotcl::Class -parameter {bind} -ad_doc {

		Stub serves as factory of "object stubs", i.e. the case
		of RMI in its proper sense of the word. While RPC, as implemented
		at the instproc level (ad_instproc), allows for stubbing of single
		remote methods / remote procedures, object stubs as represented by 
		Stub classes reflect entire remote objects. The dynamic stub-argument-declarations
		(as realised by InvocationProxy + StubBuilders) and the stub-wide declaration of
		binding information adhere to a clear order of precedence: The level of method stubs
		overrules the stub-wide scope, this allows for more flexibility at the level of
		stub delcaration.
}

Stub ad_proc unknown {name args} {

		This overridden unknown mechanism for Stub classes allows for creating custom subtypes
		of Stubs with protocol-specific parameter sets, e.g.
		
		Stub s -bind "soap://Some-URI" -uri "Some-URI" -schemas "Some-Schemas" 
		
		returns a sub-meta-class of Stub with adapted / extended parameters implementing the 
		protocol-specific stub building / calling interface.

} {
	
	#my log "++callinglevel: [self callinglevel], +++activelevel: [self activelevel]"
	set idx [lsearch [lindex $args 0] "-bind"]
	if {$idx ne "-1"} {
		set bind [lindex $args [expr {$idx + 1}]]
		if {[string first "-" $bind] != 0} {
			set builder [InvocationProxy getStubBuilder -reference $bind]
			set x [Class new -superclass [self]]
			$x parameter [$builder info parameter]
			uplevel [self callinglevel] eval $x create $name $args
		} else {
			uplevel [self callinglevel] eval [self] create $name
		}
	}	
}

Stub ad_proc new {-bind:required args} {
		
		The same as the Stub-specific unknown mechanism, but in the sense of new semantics.
} {

		set builder [InvocationProxy getStubBuilder -reference $bind]
		set x [Class new -superclass [self]]
		$x parameter [$builder info parameter]
		eval $x new -bind $bind $args
		
	
} 


	# +---------------------------+
	# | Mixin class               |
	# | InvocationProxy           |
	# | -realising "method stubs" |
	# |                           |
	# +---------------------------+
	
	::xotcl::Class InvocationProxy 
	
	InvocationProxy set builders(default) LocalStubBuilder
	InvocationProxy set builders(soap) ::xosoap::client::SoapStubBuilder
	
	InvocationProxy ad_proc getStubBuilder {-reference:required} {} {
	
		my instvar builders
		set protocol [lindex [split $reference "://"] 0]
		#my log "+++protocol=$protocol"
		if {[info exists builders($protocol)]} {
			return $builders($protocol)
		} else {
			return $builders(default)
		}
	}
	
	InvocationProxy ad_instproc ad_instproc {-stub:switch -bind args} {} {
	
		
		if {$stub || [my istype Stub]} {
		
			if {![info exist bind] && [my istype Stub]} { my instvar bind }
				
				set builder [[self class] getStubBuilder -reference $bind]
				#my log "+++builder=$builder"
				$builder new -volatile -bind $bind -args [list $args]
			
		} else {
				next
		}
		
	
	}
	
	# +---------------------------+
	# |class                      |
	# |StubBuilder                |
	# | -LocalStubBuilder         |
	# |                           |
	# +---------------------------+
	
	::xotcl::Class StubBuilder -parameter {bind args method {arguments ""} {doc {}} {body ""}}
	
	StubBuilder ad_instproc init args {} {

		
		my set __signature [list method arguments doc body]
		my parse [lindex [my args] 0]
		next

	}

	StubBuilder ad_instproc parse args {} {
	
		set idx end
		
		#parsing nonpos args
		foreach {k v} [lindex $args 0] {
				# np-arg?
			if {[string first "-" $k] != -1} {
	
				my [string trimleft $k "-"] $v
	
			} else {
				
				set idx [lsearch [lindex $args 0] $k]
	
				break
			
			}
			
			}
			
			# parsing pos args
			
			set posArgs [lrange [lindex $args 0] $idx end]
			puts "idx=$idx, posArgs=$posArgs"
			foreach k [my set __signature] {
				my $k [lindex $posArgs [lsearch [my set __signature] $k]]
			} 
			
			# parsing stub-wide params
			set obj [my set __callingobject]
			if {[$obj istype Stub]} {
	
				foreach p [[$obj info class] info parameter] {
	
					if {[$obj exists $p] && ![my exists $p]} { my $p [$obj $p]} 
				}
			}
			
			
		}


::xotcl::Class LocalStubBuilder -superclass StubBuilder -parameter {{impl ""}} -instproc init args {
	
		my set __callingobject [self callingobject]
		
		next 
		
		[self callingobject] instforward [my method] ::xorb::SCInvoker invoke -operation %proc -contract [my bind] -impl [my impl]

}

	set comment {::xotcl::Class InvocationProxy -parameter {proxyFor realisedBy}
		
	InvocationProxy instproc ad_instproc {
		
			-proxy:switch 
			{-for		""}
			{-realisedBy ""}
			methodName 
			{arguments ""}
			{doc ""}
			{body ""}
		
		} {
			
			# enforce local invocation?
			
			if {$proxy} {
			
			if {([my exists proxyFor] && [my set proxyFor] eq {}) || (![my exists proxyFor] && $for eq {})} {
				next $methodName $arguments $doc $body
			} else {
			
			# parse arguments 
			
			set callArgs ""
			set posArgs [list]
			set nonposArgs [list]
			foreach arg $arguments {
			    if { [string index $arg 0] eq {-} } {
					lappend nonposArgs $arg
						if { [string last $arg :i] } {
		   				 #nonposArg
					    	 lappend callArgs [string trimleft [lindex [split $arg :] 0] -]
					    }
				} else {
					lappend posArgs $arg
			    }
			}
			
			#my log "+++callArgs: $callArgs"
			
			# enforce locally specified (at instproc level) contract for invocation redirection
			if {![info exists for] || $for eq {}} {set for [my set proxyFor]}
			
			
			my instforward $methodName ::xorb::SCInvoker invoke -operation %proc -contract $for -impl $realisedBy --
			
			if { $body ne {} } {
			    set x [Class new]
			    $x ad_instproc $methodName $arguments $doc $body
			    my instmixin $x
			} 
		
		}
		} else {
		
			next $methodName $arguments $doc $body
		}

}}

}