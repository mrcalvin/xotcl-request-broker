ad_library {
    
    xorb auxiliary library
    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date January 30, 2006
    @cvs-id $Id$
    
}


##################################################
#
# additional checkoptions for type verification
# (string, integer, multiple)
#	
#
##################################################

::xotcl::nonposArgs ad_proc string {argName {string ""}} {} {}

::xotcl::nonposArgs ad_proc multiple {argName {list ""}} {} {
	
	if {[catch {llength $list}] || ![string equal $list [split $list]] } { set errmsg "non-positional argument: '$argName' with value '$list' is not a well-formed list"; error $errmsg } 

}


::xotcl::nonposArgs ad_proc integer {argName {integer ""}} {} {

	if {![string is integer $integer]} {set errmsg "non-positional argument: '$argName' with value '$integer' is not of type integer"; error $errmsg}

}


namespace eval xorb::aux {

	::xotcl::Class Composite -superclass ::xotcl::Class
	
	 
 Composite ad_instproc addOperations args {} {
        foreach op $args {
            if {![my exists operations($op)]} {
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
        
        #my log "+++ I am here, though I should not ..."
        set result [next]
        set registrationclass [lindex [self filterreg] 0]
        $registrationclass instvar operations        
        set r [self calledproc]

        
        if {[info exists operations($r)]} {
            foreach object [my set __children] {               
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
    #puts "[self callingobject] -> allowedType: [[self callingobject] set allowedType]"
    #puts "Typecheck (self:[self], allowedType: [[self callingobject] set allowedType]): [[self] istype [[self callingobject] set allowedType]]"
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
    #puts "+++ [self] $cmds"
    
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

############################################
#
#	Slot support
#
############################################

::xotcl::Class Slot -parameter {name type default multiplicity}
Slot ad_instproc assign {obj prop value} {} {$obj set $prop $value}
Slot ad_instproc get {obj prop}   {}    {$obj set $prop}
Slot ad_instproc add {obj prop value {pos 0}} {} {

if {[$obj exists $prop]} {} {
    $obj set $prop [linsert [$obj set $prop] $pos $value]
  } else {
    $obj set $prop [list $value]
  }
}
Slot ad_instproc delete {-nocomplain:switch obj prop value} {} {
  set old [$obj set $prop]
  set p [lsearch -glob $old $value]
  if {$p>-1} {$obj set $prop [lreplace $old $p $p]} else {
    error "$value is not a $prop of $obj (valid are: $old)"
  }
}
Slot ad_instproc init {} {} {
  regexp {^(.*)::([^:]+)$} [self] _ cl name
  $cl instforward $name -default [list get assign] [self] %1 %self %proc
  if {[my exists default]} {$cl set __defaults($name) [my default]}

}

}