ad_library {
    
    xorb auxiliary library
    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date January 30, 2006
    @cvs-id $Id$
    
}

##################################################
##################################################
#
# generic helper classes
# 
#
##################################################
##################################################

::Serializer exportMethods {
  ::xotcl::Object instproc error
 
}


::xotcl::Object instproc error msg {
 ns_log notice "[self] [self callingclass]->[self callingproc]: $msg"
  error "[self] [self callingclass]->[self callingproc]: $msg"
}



##################################################
##################################################
#
# Storage Handler for message type elements, intercepts
# calls to acs_msg_type__new_element in acs_sc::msg_type::parse_spec
# (see msg-type-procs.tcl). therefore, replaces acs_sc::msg_type::element::new
# only an interim solution!
# 
#
##################################################
##################################################

rename ::acs_sc::msg_type::element::new ::acs_sc::msg_type::element::new.orig

ad_proc ::acs_sc::msg_type::element::new {
    {-msg_type_name:required}
    {-element_name:required} 
    {-element_msg_type_name:required} 
    {-element_msg_type_isset_p:required} 
    {-element_pos:required} 
} {} {
    ::xorb::aux::MsgTypeElement new -volatile -msg_type_name $msg_type_name -element_name $element_name -element_msg_type_name $element_msg_type_name -element_msg_type_isset_p $element_msg_type_isset_p -element_pos $element_pos 
}


namespace eval xorb::aux {


##################################################
##################################################
#
#	allow nesting by using "new" in XOTcl < 1.5
#
##################################################
##################################################

Class NestedClass -superclass ::xotcl::Class
	
	#ns_log notice "+++xotcl:$::xotcl::version"
	
	if {$::xotcl::version < 1.5} {
		NestedClass ad_instproc new {-nochild:switch -mixin -childof args} {} {
			#my log "nester=[[self callingobject] info class], -mixin-arg exists:[info exists mixin], -childof-arg exists:[info exists childof], args=$args"
			
			if {$nochild} {
				eval next [expr {[info exists mixin] ? [list -mixin $mixin] : ""}] $args
			} elseif {[info exists childof]} {
				eval next [list -childof $childof] [expr {[info exists mixin] ? [list -mixin $mixin] : ""}] $args
			} else {
			
				my log "nester=[expr {[self callingobject] ne {} ?[[self callingobject] info class]  : ""}], -mixin-arg exists:[info exists mixin], -childof-arg exists:[info exists childof], args=$args"
				eval next [expr {[self callingobject] ne {} ? [list -childof [self callingobject]] : ""}] [expr {[info exists mixin] ? [list -mixin $mixin] : ""}] $args
			}
			#my log "+++ -mixin-arg exists:[info exists mixin], args=$args"
			

		}
	} else {
	
		NestedClass ad_instproc new {-nochild:switch args} {} {
			
			my log "args=$args"
			eval next $args

		}
	}



::xotcl::Class MsgTypeElement -parameter {msg_type_name element_name element_msg_type_name element_msg_type_isset_p element_pos {element_constraints ""}}

MsgTypeElement ad_instproc init {} {} {
	
	my instvar msg_type_name element_name element_msg_type_name element_msg_type_isset_p element_pos element_constraints
	
	#my log "type=$element_msg_type_name"
	
	# # # # # # # # # 
	# Array and multiple handling
	#
	
	# deal with old-style multiple declaration > foo:integer,multiple
	if {$element_msg_type_isset_p} {
		set element_msg_type_name "multiple($element_msg_type_name)"
	}
	
	set lexer [CompoundLexer new -volatile -init $element_msg_type_name]
	$lexer instvar argType isArray constraints
	
	
	array set arrConstraints [list]
	set element_constraints [db_null]
	
	#my log "isArray: $isArray, argType: $argType"
	
	if {$isArray || [string toupper $argType 0 0] eq "Multiple"} {
		set start [string first "(" $element_msg_type_name]
		if {$start != -1} {
			set element_constraints [string range $element_msg_type_name $start end]
			set element_msg_type_name [string range $element_msg_type_name 0 [expr {$start-1}]]
		}
		
		set element_msg_type_isset_p "t"
		 
	}
	#my log "+++element_name=$element_name // element_msg_type_name=$element_msg_type_name // element_msg_type_isset_p=$element_msg_type_isset_p // element_pos=$element_pos // element_constraints=$element_constraints"

	db_string insert_new_element_plus_constraints {
		
		select acs_sc_msg_type__new_element(
            :msg_type_name,
            :element_name,
            :element_msg_type_name,
            :element_msg_type_isset_p,
            :element_pos,
            :element_constraints
        );
     }
}





##################################################
##################################################
#
# mixin for backend handling of types (integration into
# message type infrastructure)
#
##################################################
##################################################

::xotcl::Class StorableType
StorableType ad_instproc init args {} {

	set name [string tolower [namespace tail [self]] 0 0]
	set specification ""
	
	if {![db_0or1row nn_msgtype_exists {
		select 	mt.msg_type_id 
		from 	acs_sc_msg_types as mt
		where 	mt.msg_type_name = :name 
	}]} {
		
		my set id [db_string insert_nn_msgtype {
		select acs_sc_msg_type__new(
            :name, 
            :specification);
	}]		
	} else {
		my set id $msg_type_id
	}
	
	next
	
}


::xotcl::Class StorableCompoundType
StorableCompoundType ad_instproc init args {} {

	
	#1 is dict (root element), mapped to acs_sc msg type
	
#	my log "+++class=[my info class], istype: [my istype Dict::__Pointer]"
	
	
	if {[my istype Dict]} {
	
		set name [my name]
		set specification ""
	
		if {![db_0or1row n_msgtype_exists {
			select 	mt.msg_type_id 
			from 	acs_sc_msg_types as mt
			where 	mt.msg_type_name = :name 
		}]} {
		
			my set id [db_string insert_nn_msgtype {
				select acs_sc_msg_type__new(
            		:name, 
            		:specification);}]
            	my set inserted true
            	Dict::$name set id [my set id]	
            	
		} else {
			my set id $msg_type_id 
			Dict::$name set id $msg_type_id
			my set inserted false
		}
	} elseif {[[my info class] istype CheckOption] || [my istype Dict::__Pointer]} {
		
		
		set msg_type_name [string tolower [namespace tail [my info parent]] 0 0]
		set element_name [string tolower [namespace tail [self]] 0 0]
		set element_msg_type_name [string tolower [namespace tail [my info class]] 0 0]
		set parent_id [db_null]
		set constraints [db_null]
		if {[my istype Dict::__Pointer]} {
			set element_msg_type_name [namespace tail [my substitute]]
			set parent_id [[my substitute] set id]
			
		}
		set element_msg_type_isset_p 0
		set element_pos	-1
		
	#	my log "+++child_name=$element_name, parent_name:$msg_type_name, id=$parent_id, constraints=$constraints"
		
		
		#my log "msg_type_name: $msg_type_name, element_name: $element_name, el_msg_type_name: $element_msg_type_name, insert? [[my info parent] set inserted]"
		 
		if {[[my info parent] set inserted]} {
			db_0or1row c_insert_subelement {
				select acs_sc_msg_type__new_element(
            			:msg_type_name,
            			:element_name,
	            		:element_msg_type_name,
	            		:element_msg_type_isset_p,
	            		:element_pos
	        );
		}
		}
	}
	next
	
}


##################################################
# mixin class implementing basic compound handling (getting compound declaration, ...)

::xotcl::Class CompoundNonPosArgs 
CompoundNonPosArgs ad_instproc unknown {npArgType argName argValue} {} {

		set lexer [CompoundLexer new -volatile -init $npArgType]
		$lexer instvar argType isArray constraints
		
		set argTypeUpper [string toupper $argType 0 0]
		
		if  {$isArray} {
			[Array new -nochild -name $argName -type $argType -occurrence $constraints] validate $argName $argValue
		} elseif {[my isobject Dict::$argType]} {
			Dict::$argType validate $argName $argValue
		} elseif {$argTypeUpper eq "Multiple" && [my isobject $argTypeUpper]} {
			[$argTypeUpper new -nochild -name $argName -type $constraints] validate $argName $argValue 
		} else {next}
}

##################################################
# basic lexer for compound declarations


::xotcl::Class CompoundLexer -parameter {{argType ""} {isArray ""} {constraints ""}}


CompoundLexer ad_instproc unbrace {in} {} {
	
	return [string map {" \{ " "(" " \}" ")"} $in]
}

CompoundLexer ad_instproc enbrace {in} {} {
	
	return [string map {"(" " \{ " ")" " \} "} $in]
}

CompoundLexer ad_instproc init {npArgType} {} {

	my instvar argType isArray constraints
	
  	 if {$npArgType ne {}} { 
   
   		set bracedString [my enbrace $npArgType]
   		set inserted 0
		if {[expr {[llength $bracedString]%2}] != 0} { set bracedString "$bracedString {}"; set inserted 1}
   
   		array set declaration $bracedString
   		set level0 [array names declaration]
   		set isArray false
   		set argType $npArgType
   		set constraints ""
   		
   		
   		if {[llength $level0] == 1 && !$inserted} {
   			set argType $level0
   			set constraints [my unbrace [string trim $declaration($level0)]]
   			set isArray [string is integer $constraints]
   			
   		} elseif {[llength $level0] == 2 && $inserted} {
   			
   			# array of multiples or array of arrays
   			set l [lsort -increasing [array names declaration]]
   			set constraints [lindex $l 0]
   			set isArray [string is integer $constraints]
   			set argType "[lindex $l 1]([my unbrace [string trim $declaration([lindex $l 1])]])"
   			
   		} 
      
   		
		#my log "argType: $argType, constraints=$constraints, isArray: $isArray"
		
		
	
	}
	
}


##################################################
# activate compound lexer

::xotcl::nonposArgs mixin CompoundNonPosArgs

##################################################
# basic meta-class for defining/ registering new checkoptions

::xotcl::Class CheckOption -superclass Class
CheckOption ad_instproc init args {} {
	
	my abstract instproc getValue {}
	my abstract instproc getCheckOption {}
	
	
	next
}

CheckOption ad_proc is {label} {} {
	return [expr {[my isclass [string toupper $label 0 0]] && [[string toupper $label 0 0] istype [self]]}]
}


##################################################
# derived meta-class for defining/ registering new atomic checkoptions

::xotcl::Class Atom -superclass {CheckOption NestedClass}

# register with backend (as basic message type)

Atom instmixin StorableType

Atom ad_instproc init args {} {
	
	next
	
	my abstract instproc validate {argName {value ""}}
	#set x [::xotcl::Class new -parameter {detainee name}]
	#my superclass $x
	#::Serializer exportObjects $x
#	my instproc init args {
			
			# clear from all mixins
#			my mixin {}
#			next
#	}
	
	# register with nonposArg Handler
	
	if {[lsearch -glob [::xotcl::nonposArgs info methods] [string tolower [namespace tail [self]]]] == -1} {
		set cmd "::xotcl::nonposArgs proc [string tolower [namespace tail [self]]] {argName {value \"\"}} { 
		
				set x \[[self] new -detainee \$value \] 
			
				\$x validate \$argName \$value 
			
				}"
		
		eval $cmd
	}
	
	
	
	my ad_instproc getCheckOption {} {} {
		return [string tolower [namespace tail [self class]] 0 0]
	}
	
	#my log "+++help: i am here"
	
	
}

Atom ad_proc is {label} {} {

	return [expr {[my isclass [string toupper $label 0 0]] && [[string toupper $label 0 0] istype [self]]}]
}


##################################################
# derived meta-class for defining/ registering new compound checkoptions


::xotcl::Class Compound -superclass {CheckOption NestedClass}

Compound ad_proc is {label} {} {

	return [expr {[my isclass [string toupper $label 0 0]] && [[string toupper $label 0 0] istype [self]]}]
}
 
Compound ad_instproc init args {} {

	my abstract instproc validate {argName {value ""}}
	my abstract instproc getValues {}
	my abstract instproc ascribe {container accessor}
	
	#set x [::xotcl::Class new -parameter {detainee {domNode ""}}]
	#my superclass $x
	#::Serializer exportObjects $x
	next
	
}

##################################################
##################################################
#
#	orthogonal superclass Type
#
##################################################
##################################################

::xotcl::Class Type -parameter {detainee name {domNode ""}}

Type ad_instproc init args {} {
		
	# clear from all mixins (StorableCompoundType, RetrievableType, ...)
	my mixin {}
	# call ascription procedure (when nesting is achieved by contains)
	if {[my info parent] ne {} && [my isobject [my info parent]] && ([[my info parent] istype Dict] || [[my info parent] istype Array])} {
	
		[my info parent] ascribe [self] [my name]
	}
	
	next

}	


##################################################
##################################################
#
#	compounds / atoms
#
##################################################
##################################################

 # # # # # # # # # # # 
 #   ______________
 #  /              \
 # | Compound: 
 # |	     multiple
 #  \__   _________/
 #    / ,'
 #   /,'


Compound  Multiple -superclass Type -parameter {type}

	Multiple ad_instproc init args {} {
		my instvar type
		if {![Atom is $type]} {
			set errmsg "non-positional argument: 
				Creating a [self class] with a type constraint '$type' is invalid"; error $errmsg
		}
		
		next
	} 
	
	Multiple ad_instproc validate {argName {value ""}} {} {
		
			my log "[self class] // value: $value"
			my instvar type
			if {[catch {llength $value}]} { set errmsg "non-positional argument: 
				'$argName' with value '$value' is not a well-formed list"; error $errmsg } 
					
			foreach component $value {
					::xotcl::nonposArgs $type "$argName's component (pos [lsearch -glob $value $component])" $component
				}
	}	
	
	Multiple ad_instproc getValues {} {} {
		
		if {[my exists detainee]} {
			return [my detainee]
		}
	}
	
	Multiple ad_instproc getCheckOption {} {} {
		
		my instvar type
		return "[string tolower [namespace tail [self class] ] 0 0]($type)"
	}


 # # # # # # # # # # # 
 #   ______________
 #  /              \
 # | Compound: 
 # |	     dict
 #  \__   _________/
 #    / ,'
 #   /,'

Compound  Dict -superclass Type


	
	Dict ad_proc unknown {name elements} {} {
			
			#1 create a new instance 
			#set x [uplevel [self callinglevel] eval [self] create $name]
			
			
			# create a permanent proxy in Dict::* namespace
			Dict::__Proxy [self]::$name 
			# create a volatile container for one time parsing / registering
			set x [[self] new -nochild -name $name -mixin ::xorb::aux::StorableCompoundType]
			
			
			foreach element $elements {
				if {![regexp {^([0-9,a-z,A-Z]*):([a-z,A-Z]*)([[.(.]]([a-z,0-9]*)[[.).]])?$} $element -> elName elType info constraints ] || ($elName eq {} && $elType eq {})} {
					set errmsg "Invalid element specification in '$elements' when trying to populate new custom compound of type [self]"; 					error $errmsg	
				}
				
				set elTypeUpper [string toupper $elType 0 0]
				
			#	my log "element=$element, name=$elName, type=$elType, info=$info, constraints=$constraints"
				
				
				#2 identify nested types
				if {[my isobject Dict::$elType] && $info eq {}} { 
					$x contains "::xorb::aux::Dict::__Pointer new -name $elName -substitute Dict::$elType -mixin ::xorb::aux::StorableCompoundType"
				} elseif {[CheckOption is $elTypeUpper] && $info ne {}} {
					$x contains "::xorb::aux::Array new -name $elName -type $elTypeUpper -occurrence $constraints -mixin ::xorb::aux::StorableCompoundType"
				} elseif {[Compound is $elTypeUpper] && $elTypeUpper == "Multiple"} {
					$x contains "::xorb::aux::$elTypeUpper new -name $elName -type $constraints -mixin ::xorb::aux::StorableCompoundType"
				} elseif {[Atom is $elTypeUpper]} {
					$x contains "::xorb::aux::$elTypeUpper new -name $elName -mixin ::xorb::aux::StorableCompoundType"
				}
				
				
			}
	}
	
	Dict ad_instproc validate {argName {value ""}} {} {
		
			my log "[self class] // value: $value"
			
			if {[catch {array set tmpArray $value}] } { set errmsg "non-positional argument: 
			'$argName' with value '$value' is not a serialized Tcl array (associative array)"; error $errmsg }
			
			foreach childCO [my info children] {
			
				set childArgName [$childCO name]
			#	my log "childobj:$childCO"
			#	my log "checkopt: [$childCO getCheckOption]"
				set checkoption [$childCO getCheckOption]
				
				if {![info exists tmpArray($childArgName)]} {
						set errmsg "non-positional argument: 
						Array '$argName' with value '$value' does not contain an accessor '$childArgName'"; error $errmsg	
					}
				
				::xotcl::nonposArgs $checkoption $childArgName $tmpArray($childArgName)
				
			}
	}
	
	Dict ad_instproc getValues {} {} {
		
		if {[my array exists __detainee]} {
		
			my detainee [my getValue]
		}
		
		if {[my exists detainee]} {
			set values [list]
			 foreach {k v} [my detainee] {
			 	lappend values $v
			 }
			 
			 return $values
			 
		}
	}
	
	
	
	Dict ad_instproc getValue {} {} {
	
		if {[my array exists __detainee]} {
		
			array set tmpArray [list]
			foreach {n c} [my array get __detainee] {
				set tmpArray($n) [$c getValue]
			}
			
			
			return [array get tmpArray]
		
		}
	
	}
	
	Dict ad_instproc ascribe {container accessor} {} {
	
		my set __detainee($accessor) $container
	}
	
	Dict ad_instproc getCheckOption {} {} {
	
		return [namespace tail [self]]
	}
	
	
	NestedClass Dict::__Pointer -superclass Type -parameter substitute
	
	Dict::__Pointer ad_instproc init {} {} {
		my forward validate [my substitute] %proc
		my forward getCheckOption [my substitute] %proc
	}
	
	::xotcl::Class Dict::__Proxy
	Dict::__Proxy ad_instproc init args {} {
		my forward validate %self retrieveAndExec %proc
		my forward getCheckOption %self retrieveAndExec %proc
	}
	
	Dict::__Proxy ad_instproc retrieveAndExec {proc args} {} {
	
			set serialisedTypeCode [XorbContainer do ::xorb::CompoundTypeRepository retrieve -name [namespace tail [self]]]
			if {$serialisedTypeCode ne {}} {
				eval $serialisedTypeCode
			}
			
			# set volatile
			[self]::__[namespace tail [self]] volatile
			# validate
			eval [self]::__[namespace tail [self]] $proc $args
			
			
	}
 # # # # # # # # # # # 
 #   ______________
 #  /              \
 # | Compound: 
 # |	     array
 #  \__   _________/
 #    / ,'
 #   /,'

 Compound  Array -superclass Type -parameter {{type ""} {occurrence ""}}
 
 	Array ad_instproc getCheckOption {} {} {
 		my instvar type occurrence
 		if {$type ne {}} {
 			return "[string tolower $type 0 0]($occurrence)"
 		}
 	}
	
	
	Array ad_instproc validate {argName {value ""}} {} {
		
			my log "[self class] // value: $value"
			
			my instvar occurrence  type
			set errmsg "non-positional argument: 
			'$argName' with value '$value' is not a serialized Tcl array (numerical array)";
		
			if {[catch {array set tmpArray $value} msg] || [catch {set sortedAccessors [lsort -integer -increasing [array names tmpArray]]} msg] || ![string equal $sortedAccessors [my .. [expr {[lindex $sortedAccessors end]+1}]]]} { error "$errmsg [expr {[info exists msg]? "-> $msg" : "" }]"  }
		
		
			if {$occurrence ne {}} {
				
					if {[llength [my getValues $value]] != $occurrence} {
						set errmsg "non-positional argument: 
					'$argName' with value '$value' contains a number of components other than $occurrence"; error $errmsg
					}
				}
				
				#my log "dataType=$type"
				# 3) type check on components
			if {$type ne {}} {
					
					foreach component [my getValues $value] {
						::xotcl::nonposArgs $type "$argName's component (pos [lsearch -glob [my getValues $value] $component])" $component
					}
				}
			}
		
		
	Array ad_instproc .. {a {b ""} {step 1}} {} {
    if {$b eq ""} {set b $a; set a 0} ;# argument shift
    if {![string is int $a] || ![string is int $b]} {
        scan $a %c a; scan $b %c b
        incr b $step ;# let character ranges include the last
        set mode %c
    } else {set mode %d}
    set ss [my sgn $step]
    if {[my sgn [expr {$b - $a}]] == $ss} {
        set res [format $mode $a]
        while {[my sgn [expr {$b-$step-$a}]] == $ss} {
            lappend res [format $mode [incr a $step]]
        }
        set res
    } ;# one-armed if: else return empty list
 }

 Array ad_instproc sgn x {} {expr {($x>0) - ($x<0)}}	
	
	Array instproc getValues {sArray} {
		
		
			 foreach {k v} $sArray {
			 	lappend values $v
			 }
			 
			return $values
			 
		
	}

	Array ad_instproc getValue {} {} {
	
		if {[my array exists __detainee]} {
		
			array set tmpArray [list]
			foreach {n c} [my array get __detainee] {
				set tmpArray($n) [$c getValue]
			}
			my log "+++[array get tmpArray]"
			return [array get tmpArray]
		
		}
		
	} 

	Array ad_instproc ascribe {container accessor} {} {
	
		set idx 0
		if {[my array exists __detainee]} {
			set idxs [lsort -integer -increasing [my array names __detainee]]
			set idx [expr {[lindex $idxs end] + 1}]
		}
		
		my set __detainee($idx) $container
	
	}


 # # # # # # # # # # # 
 #   ______________
 #  /              \
 # | Atom: integer
 # |
 #  \__   _________/
 #    / ,'
 #   /,'

Atom Integer -superclass Type

	Integer ad_instproc validate {argName {value ""}} {} {
		#my log "[self class] // value: $value"
		if {![string is integer $value]} {set errmsg "non-positional argument: 
		'$argName' with value '$value' is not of type integer"; error $errmsg}
	}
	
	Integer ad_instproc getValue {} {} {
	
		if {[my exists detainee]} {
				return [my detainee]
		}	
	}
	

 # # # # # # # # # # # 
 #   ______________
 #  /              \
 # | Atom: string
 # |
 #  \__   _________/
 #    / ,'
 #   /,'

Atom String -superclass Type

	String ad_instproc validate {argName {value ""}} {} {
		#my log "[self class] // value: $value"
		if {![string is print $value]} {set errmsg "non-positional argument: 
		'$argName' with value '$value' is not of type string"; error $errmsg}
	}
	
	String ad_instproc getValue {} {} {
		if {[my exists detainee]} {
				return [my detainee]
		}	
	}

 # # # # # # # # # # # 
 #   ______________
 #  /              \
 # | Atom: double
 # |
 #  \__   _________/
 #    / ,'
 #   /,'

 Atom Double -superclass Type

	Double ad_instproc validate {argName {value ""}} {} {
		#my log "[self class] // value: $value"
		if {![string is double $value]} {set errmsg "non-positional argument: 
		'$argName' with value '$value' is not of type double"; error $errmsg}
	}
	
	Double ad_instproc getValue {} {} {
		if {[my exists detainee]} {
				return [my detainee]
		}	
	}

	
 ################################################
 #	export namespace constructs
 ################################################
   
  namespace export Multiple Dict Array String Integer Double


} 

##################################################
##################################################
#
# register extended nonposArgs object with serializer
#
##################################################
##################################################

::Serializer exportObjects {
  
  ::xotcl::nonposArgs
}


namespace eval xorb::aux {


	


::xotcl::Class Composite -superclass ::xotcl::Class
	
	 
 Composite ad_instproc addOperations args {} {
        foreach op $args {
            if {![my exists operations($op)]} {
            
            		#my log "+++4: self: [self], self class: [self class], my class: [my info class]"
            		
                my set operations($op) $op
            }
        }
    }

   Composite ad_instproc removeOperations args {} {
        foreach op $args {
            if {![my exists operations($op)]} {
                my unset operations($op)
            }
        }
    }
    
   Composite ad_instproc init {args} {} {
   
   		    my array set operations {}   		    
	        next
	        my instfilter add compositeFilter
        
    } 
  
  ################################################
  #
  #
  #	TopDownComposite
  #
  #
  ################################################
  
    ::xotcl::Class TopDownComposite -superclass Composite
    TopDownComposite ad_instproc init {} {} {next}   
  	TopDownComposite ad_instproc compositeFilter args {} {
        
        
        set result [next]
        set registrationclass [lindex [self filterreg] 0]
        $registrationclass instvar operations  
        #set operations(accept) "accept"   
        
        set r [self calledproc]
        

        #my log "+++ I am here, though I should not, regclass: $registrationclass, self: [my info class] op: $r, op array: [array names operations]"
        
        if {[info exists operations($r)]} {
        		
        	#my log "+++ I am here, though I should not, op: $r"
            foreach object [my children] {               
                eval $object $r $args
            }
            
            
        }
        return $result
    }
    
  ################################################
  #
  #
  #	BottomUpComposite
  #
  #
  ################################################
  
  ::xotcl::Class BottomUpComposite -superclass Composite -parameter {{connective "AND"}}
  BottomUpComposite ad_instproc init {} {} {next}   
  BottomUpComposite ad_instproc compositeFilter args {} {
        
        #my log "+++ [self filterreg]"
        #my log "+++ current type: [self class]"
        set registrationclass [lindex [self filterreg] 0]
        #my log "+++ [$registrationclass]"
        #my log "vars +++ [$registrationclass info vars], [$registrationclass info methods] "
        #foreach op [$registrationclass array names operations] {
 	#
 		#	my log "+++ op: $op "
 
 		#}
 		
        $registrationclass instvar operations connective
               
        set r [self calledproc]
        
        #my log "++++ $registrationclass & calledproc $r & exists: [info exists operations($r)]"
        
        set result ""
        
        if {[info exists operations($r)]} {
               
	        if {[my info children] == ""} {
	        
	        	set result [next]
	        
	        } else {
				
				set operator [expr {[string equal $connective "OR"] ? "||" : "&&"}]        
	        	set logExpression [list]
	        	
        	foreach object [my info children] {               
	                lappend logExpression [eval $object $r $args]
	            }
	            
	            set result [expr {[join $logExpression $operator]}]
	        
	        }
	        
        } else {
        
        	set result [next]
        
        }
        
        	return $result
            
        }
        
   
  ################################################
  #
  #
  #	SortableTypedComposite
  #
  #
  ################################################
  
	
  TopDownComposite SortableTypedComposite
  
  #SortableTypedComposite instproc init {} {}
  
  SortableTypedComposite ad_instproc orderby {{-order "increasing"} variable} {} {
    my set __order $order
    my set __orderby $variable
  }

  SortableTypedComposite ad_instproc __compare {a b} {} {
    set by [my set __orderby]
    set x [$a set $by]
    set y [$b set $by]
    if {$x < $y} {
      return -1
    } elseif {$x > $y} {
      return 1
    } else {
      return 0
    }
  }
  
  SortableTypedComposite ad_instproc children {} {} {
    	set children [expr {[my exists __children] ? [my set __children] : ""}]
    	if {[my exists __orderby]} {
      		set order [expr {[my exists __order] ? [my set __order] : "increasing"}]
      		return [lsort -command [list my __compare] -$order $children]
    	} else {
      		return $children
    	}
  }
  
  SortableTypedComposite ad_instproc parent {} {} {
  
  		set parent [expr {[my exists __parent] ? [my set __parent] : ""}]
  		return $parent
  
  }
  
  ::xotcl::Class SortableTypedComposite::ChildManager -ad_instproc init args {} {
  
    set r [next]
    my log "+++[self callingobject], class: [[self callingobject] info class], current: [self], current class: [my info class]"
    
    #my log "[self callingobject] -> allowedType: [[self callingobject] set allowedType]"
    #my log "Typecheck (self:[self], allowedType: [[self callingobject] set allowedType]): [[self] istype [[self callingobject] set allowedType]]"
    if { [[self] istype [[self callingobject] set allowedType]] } {
    [self callingobject] lappend __children [self]
    my set __parent [self callingobject]    
    } else {
    
    	[self] destroy
    
    }
    return $r
  }
  
  SortableTypedComposite ad_instproc contains cmds {} {
  
  
    my requireNamespace ;# legacy for older xotcl versions
    my set allowedType [lindex [[self class] info subclass] 0]
    set m [Object info instmixin]
    if {[lsearch $m [self class]::ChildManager] == -1} {
      set insert 1
      Object instmixin add [self class]::ChildManager
    } else { 
      set insert 0
    }
    #my log "+++ [self] $cmds"
    
    set errorOccurred [catch {namespace eval [self] $cmds} errorMsg]
    if {$insert} {
      Object instmixin delete [self class]::ChildManager
    }
    if {$errorOccurred} {error $errorMsg}
  }
  
  
	
	
    
  SortableTypedComposite ad_instproc destroy {} {} {
    
    if {[my exists __children]} {
    foreach c [my set __children] { $c destroy }
    next
  }
  }
  
  
}