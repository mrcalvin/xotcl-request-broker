ad_library {
    
    xorb core library
    
}



#########################################################
#
# 	to-dos:
#				* optimise queries (re-organise into separate *ql files)
#				* [done] new label for mixin Recoverable
#				* [done] Naming of embedded alias / operation objects -> ids instead if alias_/ operation_name
#				  in order to avoid naming conflicts <object> copy where copy is name of operation and #				  method on object


namespace eval xorb {

	
	#########################################################
	#
	# 	ServiceContract / Operation Classes
	#
	#	ServiceContract myContract 
	#	-description "desc of my contract" 
	#	-contains {
	#	
	#		Operation GetObjectTypes 
	#			-description "first op stipulated by my contract" 
	#			-contains {
	#			
	#				Input new -contains {
	#					
	#					Argument case_id -datatype integer
	#					Argument object_id -datatype integer
	#					Argument action_id -datatype integer
	#					Argument entry_id -datatype integer
	#				
	#				}
	#				
	#				Output new -contains {
	#				
	#					ReturnValue object_type -datatype string
	#				}
	#			}
	#	<OR>
	#			-input {
	#				
	#				case_id:integer
    #               object_id:integer
    #               action_id:integer
    #               entry_id:integer
	#			
	#			}					
	#			-output {
	#				object_type:string
	#			}	
	#	
	#	}
	#
	#########################################################
	

	
	::xotcl::Class ServiceContract -superclass ::xotcl::Class -parameter {label description}
	ServiceContract ad_instproc init {} {} { 
		
		
			
		if {[lsearch [my info mixin] "::xorb::Retrievable"] != -1} {
		
			my mixin delete "::xorb::Retrievable"
			my accept [::xorb::ClassBuilderVisitor new -volatile]
			
		}
		
		if {[lsearch [my info mixin] "::xorb::Storable"] != -1} {
		
		
			my mixin delete "::xorb::Storable"
		
		}
	
	}
	
	ServiceContract ad_instproc accept {visitor} {} {
	
		$visitor visit [self]
		#my log "++++ [self]'s children: [my info children]"
		foreach child [my info children] {
			 
			$child accept $visitor
		
		}
	
	}
	
	#########################################################
	#
	#	OACS service contracts introduce the notion of "message 
	#	types", however, they limit it to complex or primitive data
	#	types (InputType, OutputType, string, integer, multiple).
	#	Operations are conceptually not considered messages (!),
	# 	the following implementation introduces a composite pattern
	#	structure, including composite (Operation, Input, Output) and
	#	atomic (string, integer) message types.
	#	
	#	MessageType
	#		` Operation
	#		` SignatureElement (arguments (input), return value (output), positional info ...)
	#		` Argument, ReturnValue	(string, multiple, integer,...)
	#
	#
	#########################################################
	
	Class NestedClass -superclass ::xotcl::Class
	NestedClass ad_instproc new {-mixin args} {} {
		
		eval next -childof [self callingobject] [expr {[info exists mixin] ? [list -mixin $mixin] : ""}] $args

	}
	
	::xotcl::Class MessageType -superclass ::xorb::aux::SortableTypedComposite -parameter {label}
	MessageType addOperations {accept}
	
	MessageType ad_instproc accept {visitor} {} {
	
		$visitor visit [self]
	
	}
		
	NestedClass Operation -superclass MessageType -parameter {description}
	::xotcl::Class SignatureElement -superclass MessageType
	
		NestedClass Input -superclass SignatureElement		
		NestedClass Output -superclass SignatureElement
	
	NestedClass Argument -superclass MessageType -parameter {datatype position}	
	NestedClass ReturnValue -superclass MessageType -parameter {datatype position}
	
	#########################################################
	#
	# ServiceImplementation / Alias Classes
	#	
	#	ServiceImplementation myImplementation 
	#	-contractName 	"myContract"
	#	-prettyName 	"My first implementation"
	#	-owner 			"my package"   
	#	-contains {
	#	
	#		Alias GetObjectTypes 
	#			-servantMethod	bug_tracker::bug::object_type 
	#			
	#	
	#	}
	#
	#########################################################
	
	::xotcl::Class ServiceImplementation -superclass ::xotcl::Class -parameter {label contractName prettyName {owner ""}}
	ServiceImplementation ad_instproc init {} {} {	
	
		#my log "Dispatch of class builder for [self]."
		#my accept [::xorb::ClassBuilderVisitor new]
		#my log "+++ after impl init (methods)[my info methods]."
		#my log "+++ after impl init (instprocs) [my info instprocs]."
		
		# cleanup (mixins)
		
		if {[lsearch [my info mixin] "::xorb::Retrievable"] != -1} {
			
			my mixin delete "::xorb::Retrievable"
			my accept [::xorb::ClassBuilderVisitor new -volatile]
		
		}
		
		if {[lsearch [my info mixin] "::xorb::Storable"] != -1} {
		
			my mixin delete "::xorb::Storable"
		
		}
	
	}
	
	ServiceImplementation ad_instproc accept {visitor} {} {
	
		$visitor visit [self]
		foreach child [my info children] {
		
			$child accept $visitor
		
		}
	
	}
	
	NestedClass Alias -parameter {label servantMethod}
	
	Alias ad_instproc accept {visitor} {} {
	
		$visitor visit [self]
		foreach child [my info children] {
		
			$child accept $visitor
		
		}
	
	}
	

#  set spec {
 #       name "Action_SideEffect"
  #      description "Get the name of the side effect to create action"
   #     operations {
    #        GetObjectTypes {
#                description "Get the object types for which this implementation is valid."
#               output { object_types:string,multiple }
#                iscachable_p "t"
#            }
#            GetPrettyName { 
#                description "Get the pretty name of this implementation."
#                output { pretty_name:string }
#                iscachable_p "t"
#            }
#            DoSideEffect {
#                description "Do the side effect"
#                input {
#                    case_id:integer
#                    object_id:integer
#                    action_id:integer
#                    entry_id:integer
#                }
#            }
#        } 
#    }  

::xotcl::Class ArrayListBuilderVisitor

ArrayListBuilderVisitor ad_instproc init {} {} {

		my set strBuffer ""
		my set strOpBuffer ""
		my set hostType ""

} 

ArrayListBuilderVisitor ad_instproc visit {obj} {} {

	if {[my isobject $obj]} {
		
		#my log "++++ method-to-call: [namespace tail [$obj info class]]"
		eval my [namespace tail [$obj info class]] $obj 
	
	}

}

ArrayListBuilderVisitor ad_instproc asString {} {} {

	if {[my exists strBuffer]} {
		
		
		return [my set strBuffer]
	}
	
}

ArrayListBuilderVisitor ad_instproc ServiceContract {obj} {} {

	my instvar strBuffer hostType
	
	set hostType [$obj info class]
	
	set strBuffer "name {[$obj label]} description {[$obj description]} operations "
	#my log "++++++ strBuffer before: $strBuffer" 
}

ArrayListBuilderVisitor ad_instproc Operation {obj} {} {

	my instvar strBuffer strOpBuffer
	
	set tmpInput [list]
	set tmpOutput [list]
	
	foreach signObj [$obj children] {
					
						if {[$signObj istype "::xorb::Input"]} {
							
							foreach argObj [$signObj children] {
						
								lappend tmpInput "[$argObj label]:[$argObj datatype]"

							}
						} elseif {[$signObj istype "::xorb::Output"]} {
						
							foreach argObj [$signObj children] {
						
								lappend tmpOutput "[$argObj label]:[$argObj datatype]"
							}
							
						}
					}  
	
	append strOpBuffer " [$obj label] {  description {[$obj description]} input {$tmpInput} output {$tmpOutput} }"  
	set strBuffer "$strBuffer {$strOpBuffer}"
	  

}

ArrayListBuilderVisitor ad_instproc ServiceImplementation {obj} {} {
	
	my instvar strBuffer hostType
	set hostType [$obj info class]
	
	set strBuffer "contract_name {[$obj contractName]} owner {[$obj owner]} name {[$obj label]} pretty_name {[$obj prettyName]} aliases {"
	
	foreach child [$obj info children] {
	
		if {[$child istype ::xorb::Alias]} {
		
			append strBuffer " " "[$child label] [$child servantMethod]"	
		
		}
	}
	
	append strBuffer "}"
}

ArrayListBuilderVisitor ad_instproc Alias {obj} {} {}

ArrayListBuilderVisitor ad_instproc getSignature {} {} {

	if {[my exists strBuffer]} {
	my instvar strBuffer hostType
	
	set signature ""
		if {![catch {array set specification $strBuffer} msg]} {
			
			switch $hostType {
			
				"::xorb::ServiceContract" { set signature $specification(operations)}
				"::xorb::ServiceImplementation" {set signature $specification(aliases)}
			
			}
		
		} else {
		
			my log "+++ arraylist builder msg ($strBuffer): $msg"
		
		}
		
		return [ns_sha1 $signature]
	
	}

}

	
::xotcl::Class ClassBuilderVisitor

ClassBuilderVisitor ad_instproc visit {obj} {} {

	
	if {[my isobject $obj]} {
	
	my instvar cls
	#my log "++++ ClassBuilder in [$obj label] ([$obj info class])"
	#my log "+++ [$obj info methods]"
	switch [$obj info class] {
	
		"::xorb::ServiceContract" {
		
				my set cls $obj
				eval "$cls ad_doc { [$obj description] } "
		
		}
		"::xorb::ServiceImplementation" {
		
				my set cls $obj
				eval "$cls ad_doc { [$obj prettyName] }"
				
				set cmd ""
				
				foreach alias [$obj info children] {
				
					append cmd "$cls ad_instproc [$alias label] args {} { 
										set r \[next\] 
										set qualifier \[namespace qualifiers [$alias servantMethod]\]
										if {\[my isobject \$qualifier\]} {
											eval \$qualifier mixin ::xorb::Serving
										} 
										
										set msg \"\$qualifier's class mixins\"
										
										my log \"\$msg: \[ \$qualifier info mixin \]\"
										if {\[\$qualifier istype \"::xorb::service::InstantService\"\]} {
											eval \$qualifier \[namespace tail [$alias servantMethod]\] \$args 
										} else {
										
											eval \$qualifier \[namespace tail [$alias servantMethod]\] \$r 
										}
										 
										
										} \n\n"
					#append cmd "$cls ad_instproc [namespace tail $alias] args {} { my log \"++++ inside impl - args: \$args\";  next} \n\n"
					
				
				}
		
				#my log "+++++ command set of $cls: $cmd"
			    eval $cmd
		}		
		"::xorb::Operation"	{
		
				
					
					set cmd ""
					set doc "[$obj description]\n"
					append cmd "$cls ad_instproc [$obj label] {"
					
					#my log "++++ ClassBuilder in [$obj label] ([$obj info class])"
					#my log "obj childx: [$obj children]"
					
					foreach signObj [$obj children] {
					
						
						
						#my log "signObj istype Input: [$signObj istype "::xorb::Input"]"
						#my log "signObj istype Output: [$signObj istype "::xorb::Output"]"
						
						if {[$signObj istype "::xorb::Input"]} {
							
							#my log "signObj (Input) childx: [$signObj children]"
							
							$cls set posArgs([$obj label]) [list]
							
							foreach argObj [$signObj children] {
						
								append cmd "-[$argObj label]:[$argObj datatype] "
								append doc "@param [$argObj label] [$argObj datatype]\n"
								
								eval $cls lappend posArgs([$obj label]) [$argObj label]
							}
						} elseif {[$signObj istype "::xorb::Output"]} {
						
							#my log "signObj (Output) childx: [$signObj children]"
						
							foreach argObj [$signObj children] {
						
								append doc "@return [$argObj label] [$argObj datatype]\n"
							}
							
						}
					}  
					
					append cmd "args}" " " "{$doc}" " " {{
										
							#my log "i am here"			
										
							set reposArgs [list]
							if {[[self class] exists posArgs([self proc])]} {
							
								foreach arg [[self class] set posArgs([self proc])] {
									if {[info exists $arg]} {eval lappend reposArgs $$arg} else {lappend reposArgs {}}
								}
							
							}
					
							#my log "++++ resposArgs: $reposArgs"
							return $reposArgs					
					}}
					
					#my log "+++ ClassBuilder cmd: $cmd"
					
					eval $cmd				
				}	
				
				
					
				
						
		
		}
	
	
	}

}	
	
	
	
	::xotcl::Class Storable
	
	Storable ad_instproc init {} {} {
	
			# return code 0: simple synchronize
			# return code 1: no need for sync
			# return code <db id>: synchronize (delete / re-insert) 
			
			
			set v [ArrayListBuilderVisitor new -volatile]
			my accept $v
			set arrListAsString [$v asString]
			set type [expr {[my istype ::xorb::ServiceContract] ? "contract" : "impl"}]
			# verify whether impl / contract is already stores and registered with the Broker
			
			set verified [eval XorbContainer do ::xorb::Service[string toupper $type 0 0]Repository verify -label [my label] -sig [$v getSignature] [expr {[my exists contractName] ? "-implContract [my contractName]" : ""}]]
				
				
				
			if {$verified == 0} {
			
				if {![catch {set id [acs_sc::${type}::new_from_spec -spec $arrListAsString]} fid]} {
				
					XorbContainer do ::xorb::Service[string toupper $type 0 0]Repository synchronise -id $id	
				
				}
		    		
		    	
		    	
			} elseif {$verified > 1} {
						my log "++++ verified: $verified"
						if {![catch {eval acs_sc::${type}::delete [expr {[expr {$type == "contract"}]?"-${type}_id $verified":"-impl_name [my label] -contract_name [my contractName]"}]} msg]} {
		    			
		    			if {![catch {set id [acs_sc::${type}::new_from_spec -spec $arrListAsString]} fid]} {
		    			
		    				XorbContainer do ::xorb::Service[string toupper $type 0 0]Repository synchronise -id $id
		    			
		    			}
		    		
		    		}			
			} 	
		    
			next	
	}
	
	::xotcl::Class Retrievable -parameter {id}
	Retrievable ad_instproc init {} {} {
		
		
		my instvar id {prettyName impl_pretty_name} {owner impl_owner_name} {contractName impl_contract_name} 
		
		
		switch [my info class] {
		
			"::xorb::ServiceContract" 			{  
			
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
				my log "[self]'s children: [my info children]"
			
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
				
					select	el.element_name, msgs.msg_type_name, el.element_pos 
					from   	acs_sc_msg_type_elements el,
							acs_sc_msg_types msgs
					where  	el.msg_type_id = :id
					and		el.element_msg_type_id = msgs.msg_type_id
				
				} {
				
					append cmd "::xorb::Argument new -label $element_name -datatype $msg_type_name -position $element_pos\n"
				
				}
				
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
				
				}
				
				my contains $cmd
					
			}
			"::xorb::ServiceImplementation" 	{
			
			my instvar id ;#{prettyName impl_pretty_name} {owner impl_owner_name} {contractName impl_contract_name}   
			
				# populate object with key info
				
				#db_1row select_impl_basics "select 	impls.impl_pretty_name,
				#					impls.impl_owner_name,
				#					impls.impl_contract_name      
    			#		from   		acs_sc_impls impls
				#		where  		impls.impl_id = :id"
				
				#my log "Populated [self] with dbID: $id, prettyName: [my prettyName], owner: [my owner], contractName: [my contractName]"
				
				# populate impl object with affiliated alias objects
				
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


#########################################################
#
#	::xorb::SCInvoker class
#
#	intercepts anonymous call (unknown) and initiates contract / impl
#	lookup 
#
#########################################################


::xotcl::Class Serving -ad_doc {} 

Serving ad_instproc unknown {method args} {} {

	set servingShadow [my new -childof [self] -volatile]
	# clear mixin list
	my mixin delete [self class]
	#my log "post-clearing: [my info mixin]"
	eval $servingShadow $method $args

}

::xotcl::Class SCInvoker -ad_proc unknown args {} {}

SCInvoker ad_proc invoke {{-contract ""} -operation:required {-impl ""} {-implId ""} {-callArgs {}} args} {} {

	# retrieve servant proxy from SCBroker (lookup)
	
		set rawproxy [XorbContainer do ::xorb::SCBroker getServant -contractLabel $contract -implLabel $impl]
	
	# deserialize servant proxy
		
		set serializedCode [lindex $rawproxy 2]
		set contract [lindex $rawproxy 0]
		set impls [lindex $rawproxy 1]
		
		my log "+++ serialized proxy code: $serializedCode"
		
		eval $serializedCode
		
		#set proxy [eval [namespace tail $contract] [self]::[my autoname ServantProxy]]
		set proxy [eval [namespace tail $contract] [self]::[my autoname ServantProxy] -mixin [namespace tail $impls]]
		
		#my log "+++ $proxy created / methods: [$proxy info methods] / mixin: [$proxy info mixin]"
	
	# parse call args -> convert to nonpos args / implement checkoptions (string, integer, ...)
	
	set npArgs ""
	
	#my log "+++++ proxy posArgs: [[$proxy info class] set posArgs($operation)], callArgs: $callArgs"
	
	if {[[$proxy info class] exists posArgs($operation)]} {
		foreach argName [[$proxy info class] set posArgs($operation)] argValue $callArgs {
			
			#my log "+++++ npArgs: $npArgs, argName: $argName, argValue: $argValue"
			expr {[string equal $argValue ""] ? "" : [append npArgs " " "-$argName $argValue"]} 
	
		}
	}
	
	
	# invoke actual op
	set cmd "$proxy $operation $npArgs"
	#my log "++++ actual invocation call: $cmd"
	set r [eval $cmd]
	#my log "++++ result of invoc: $r"
	
	# check restrictions on result value
	
	# return result


}


}


#::xorb::SCInvoker invoke -contract "auth_authentication" -impl "local" -operation "Authenticate" -callArgs "dotlearner@dotl.rn dtpwd {

namespace eval mytest {

	Class myService
	myService instproc myMethod args {
		
		my log "invocation successful: $args"
	
	}

}




