ad_library {
    
    xorb auxiliary library
    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date January 30, 2006
    @cvs-id $Id$
    
}


namespace eval ::xorb::aux {


  # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # 
  # Class OrderedComposite
  # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # 

  # / / / / / / / / / / / / / / /
  # TODO: remove when contains-scopednew 
  # issue is resolved in xotcl-core
  
  ::xotcl::Class OrderedComposite

  OrderedComposite instproc orderby {{-order "increasing"} variable} {
    my set __order $order
    my set __orderby $variable
  }
  
  OrderedComposite instproc __compare {a b} {
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

  OrderedComposite instproc children {} {
    #my log "children?[my exists __children]"
    #my log "ser=[my serialize]"
    set children [expr {[my exists __children] ? [my set __children] : ""}]
    if {[my exists __orderby]} {
      set order [expr {[my exists __order] ? [my set __order] : "increasing"}]
      return [lsort -command [list my __compare] -$order $children]
    } else {
      return $children
    }
  }
  OrderedComposite instproc add obj {
    my lappend __children $obj
    $obj set __parent [self]
  }

  OrderedComposite instproc last_child {} {
    lindex [my set __children] end
  }

  OrderedComposite instproc destroy {} {
    if {[my exists __children]} {
      foreach c [my set __children] { $c destroy }
    }
    namespace eval [self] {namespace forget *}  ;# for pre 1.4.0 versions
    next
  }

  OrderedComposite instproc contains cmds {
    my requireNamespace ;# legacy for older xotcl versions
    set m [Object info instmixin]
    #my log "---CONTAINS-CALLED:[my info class]"
    if {[lsearch $m [self class]::ChildManager] == -1} {
      set insert 1
      Object instmixin add [self class]::ChildManager
    } else { 
      set insert 0
    }
    set errorOccurred [catch {next} errorMsg]
    if {$insert} {
      Object instmixin delete [self class]::ChildManager
    }
    if {$errorOccurred} {error $errorMsg}
  }
  Class OrderedComposite::ChildManager -instproc init args {
    set r [next]
    #my log "---OUTER-CONTAINS([self callingobject]):[my info class]"
    if {![my istype ::xotcl::ScopedNew]} {
      #my log "---INNER-CONTAINS([self callingobject]):[my info class]"
      [self callingobject] lappend __children [self]
      my set __parent [self callingobject]
    }
    return $r
  }

  Class OrderedComposite::Child -instproc __after_insert {} {;}

  Class OrderedComposite::IndexCompare
  OrderedComposite::IndexCompare instproc __compare {a b} {
    set by [my set __orderby]
    set x [$a set $by]
    set y [$b set $by]
    return [my __value_compare $x $y 0]
  }
  OrderedComposite::IndexCompare instproc __value_compare {x y def} {
    set xp [string first . $x]
    set yp [string first . $y]
    if {$xp == -1 && $yp == -1} {
      if {$x < $y} {
	return -1
      } elseif {$x > $y} {
	return 1
      } else {
	return $def
      }
    } elseif {$xp == -1} {
      set yh [string range $y 0 [expr {$yp-1}]]
      return [my __value_compare $x $yh -1]
    } elseif {$yp == -1} {
      set xh [string range $x 0 [expr {$xp-1}]]
      return [my __value_compare $xh $y 1]
    } else {
      set xh [string range $x 0 $xp]
      set yh [string range $y 0 $yp]
      if {$xh < $yh} {
	return -1
      } elseif {$xh > $yh} {
	return 1
      } else {
	incr xp 
	incr yp
	return [my __value_compare [string range $x $xp end] \
		    [string range $y $yp end] $def]
      }
    }
  }

  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # Class: TypedOrderedComposite
  # Transitive Mixin: TypedOrderedComposite::ChildManager
  # # # # # # # # # # # #
  # # # # # # # # # # # #

  ::xotcl::Class TypedOrderedComposite -superclass OrderedComposite \
      -parameter {
	{type "::xotcl::Object"}
      } -instproc contains args {
	[[self class] info superclass]::ChildManager instmixin \
	    [self class]::ChildManager
	next
  }
  
  ::xotcl::Class TypedOrderedComposite::ChildManager -instproc init args {
    if {[my istype ::xotcl::ScopedNew] \
	    || ([my exists type] && [my istype [my type]])} {
      next
    }
  }

  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # Meta-class Traversal
  # # # # # # # # # # # #
  # # # # # # # # # # # #
  
  ::xotcl::Class Traversal -superclass ::xotcl::Class
  Traversal instproc addOperations {allowed} {
    foreach op $allowed {
      if {![my exists operations($op)]} {
	my set operations($op) $op
      }
    }
  }
  
  Traversal instproc removeOperations args {
    foreach op $args {
      if {![my exists operations($op)]} {
	my unset operations($op)
      }
    }
  }
  
  Traversal instproc traversalFilter args {next}
  Traversal instproc init {args} {
    my instfilter add traversalFilter
    next
  } 
  
  ::xotcl::Class PreOrderTraversal -superclass Traversal
  PreOrderTraversal instproc traversalFilter args {
    
    # / / / / / / / / / / / / / /
    # visit root first
    set result [next]
    
    # / / / / / / / / / / / / / /
    # look for method calls to be
    # traversed
    
    set registrationclass [lindex [self filterreg] 0]
    $registrationclass instvar operations  
    set cp [self calledproc]
    if {[info exists operations($cp)]} {
      
      set ch [expr {[my istype ::xorb::aux::OrderedComposite]\
			?[my children]:[my info children]}]
      foreach object $ch {               
	eval $object $cp $args
      }
    }

    # / / / / / / / / / / / / / /
    # return result from root
    return $result
  }

namespace export Traversal PreOrderTraversal OrderedComposite \
      TypedOrderedComposite

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
#	allow nesting by using "new" in XOTcl < 1.5
#
##################################################
##################################################

Class NestedClass -superclass ::xotcl::Class
	
	if {$::xotcl::version < 1.5} {
	  NestedClass ad_instproc new {
	    -nochild:switch 
	    -mixin 
	    -childof args
	  } {} {	    
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
	    
	    my log "args(self=[self])=$args"
	    eval next $args
	    
	  }
	}



#::xotcl::Class MsgTypeElement -parameter {msg_type_name element_name element_msg_type_name element_msg_type_isset_p element_pos {element_constraints ""}}

# MsgTypeElement ad_instproc init {} {} {
	
# 	my instvar msg_type_name element_name element_msg_type_name element_msg_type_isset_p element_pos element_constraints
	
# 	#my log "type=$element_msg_type_name"
	
# 	# # # # # # # # # 
# 	# Array and multiple handling
# 	#
	
# 	# deal with old-style multiple declaration > foo:integer,multiple
# 	if {$element_msg_type_isset_p} {
# 		set element_msg_type_name "multiple($element_msg_type_name)"
# 	}
	
# 	set lexer [CompoundLexer new -volatile -init $element_msg_type_name]
# 	$lexer instvar argType isArray constraints
	
	
# 	array set arrConstraints [list]
# 	set element_constraints [db_null]
	
# 	#my log "isArray: $isArray, argType: $argType"
	
# 	if {$isArray || [string toupper $argType 0 0] eq "Multiple"} {
# 		set start [string first "(" $element_msg_type_name]
# 		if {$start != -1} {
# 			set element_constraints [string range $element_msg_type_name $start end]
# 			set element_msg_type_name [string range $element_msg_type_name 0 [expr {$start-1}]]
# 		}
		
# 		set element_msg_type_isset_p "t"
		 
# 	}
# 	#my log "+++element_name=$element_name // element_msg_type_name=$element_msg_type_name // element_msg_type_isset_p=$element_msg_type_isset_p // element_pos=$element_pos // element_constraints=$element_constraints"

# 	db_string insert_new_element_plus_constraints {
		
# 		select acs_sc_msg_type__new_element(
#             :msg_type_name,
#             :element_name,
#             :element_msg_type_name,
#             :element_msg_type_isset_p,
#             :element_pos,
#             :element_constraints
#         );
#      }
# }





##################################################
##################################################
#
# mixin for backend handling of types (integration into
# message type infrastructure)
#
##################################################
##################################################

::xotcl::Class StorableType
StorableType instproc init args {
    
    my info class
    next
}

StorableType ad_instproc registerAtom args {} {

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