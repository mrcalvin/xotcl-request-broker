ad_library {
    
  Re-use facilities (following the ADAPTER pattern)
  
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date March 23, 2007
  @cvs-id $Id$
  
}

namespace eval ::xorb {
  

  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # # Meta-Class Adapter
  # # # # # # # # # # # #
  # # # # # # # # # # # #

  ::xotcl::Class Adapter \
      -superclass ServiceImplementation \
      -slots {
	Attribute adapts
      } -instproc init args {
	next
      }

  Adapter instproc adapterFilter args {
    set r [self calledproc]
    if {![catch { array set tmp [[my info class] adapts]
    }msg] && [info exists tmp($r)]} {
      set adaptee [lindex $tmp($r) 0]
      if {![::xotcl::Object isobject $adaptee]} {
	#TODO:-destroy_on_cleanup
	set tmpObj [::xotcl::Object new -destroy_on_cleanup]
	$tmpObj forward $r $adaptee
	set adaptee $tmpObj
      } 
      $adaptee mixin add [my info class]
      set result [eval $adaptee $r $args]
      $adaptee mixin delete [my info class]
      return $result
    } else {
      next
    }
  }
  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # # Adapter for Classes
  # # # # # # # # # # # #
  # # # # # # # # # # # #

  ::xotcl::Class ClassAdapter -superclass Adapter
  ClassAdapter instproc init args {
    my instvar adapts
    if {[info exists adapts]} {
      foreach {call adaptee+adapteeCall} $adapts {
	foreach {adaptee adapteeCall} ${adaptee+adapteeCall} break
	set adapteeCall [namespace tail $adapteeCall]
	set superclass($adaptee) 1
	append slots [subst {::xorb::Delegate new \
				 -name $call \
				 -proxies [self]::$adapteeCall\n}]
      }
      my superclass [array names superclass]
      if {[info exists slots]} {my slots $slots}
    }
    next;#ServiceImplementation->init
  }
  
  
  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # # Adapter for Objects
  # # # # # # # # # # # #
  # # # # # # # # # # # #
  
  ::xotcl::Class ObjectAdapter \
      -superclass Adapter
  
  ObjectAdapter instproc init args {
    my instvar adapts
    foreach {call adaptee+adapteeCall} $adapts {
      foreach {adaptee adapteeCall} ${adaptee+adapteeCall} break
      set adapteeCall [namespace tail $adapteeCall]
      append slots [subst {::xorb::Delegate new \
			       -name $call \
			       -proxies [self]::$adapteeCall\n}]
      set reversed($adapteeCall) $adaptee
    }
    if {[array exists reversed]} {my adapts [array get reversed]}
    if {[info exists slots]} {my slots $slots}
    my instfilter add adapterFilter
    next;#ServiceImplementation->init
  }
  
  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # # Adapter for Procs
  # # # # # # # # # # # #
  # # # # # # # # # # # #
  
  ::xotcl::Class ProcAdapter \
      -superclass Adapter
  
  ProcAdapter instproc init args {
    my instvar adapts
    foreach {call adapteeCall} ${adapts} {
      set adaptee $adapteeCall
      set adapteeCall [namespace tail $adapteeCall]
      append slots [subst {::xorb::Delegate new \
			       -name $call \
			       -proxies [self]::$adapteeCall\n}]
      set reversed($adapteeCall) $adaptee
    }
    if {[array exists reversed]} {
      my log "adapts=$adapts"
      my adapts [array get reversed]
    }
    if {[info exists slots]} {my slots $slots}
    my instfilter add adapterFilter
    next;#ServiceImplementation->init
  }

  namespace export Adapter ClassAdapter ObjectAdapter\
      ProcAdapter
}