ad_library {
  
  Basic datatype handling infrastructure
  for protocol plug-ins. The main idea
  is inspired by specific forms of the
  context object pattern as argument
  passing and handling strategy. xorb provides
  so-called 'Anythings' as generic containers
  for lately-intiated, on-demand and extensible
  type conversion.
  
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date April 22, 2007
  @cvs-id $Id$
}

namespace eval ::xorb::datatypes {
  
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  # Anything
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  
  ::xotcl::Class MetaAny -slots {
    Attribute checkoption
  } -superclass ::xotcl::Class

  MetaAny instproc init args {
    my instvar checkoption
    if {![info exists checkoption]} {
      set checkoption [string tolower [namespace tail [self]] 0 0] 
    }
    if {![my isStored]} {
      db_transaction {
	db_exec_plsql insert_new_datatype \
            "select acs_sc_msg_type__new(:checkoption,'');"
      }
    }
    next
  }
  MetaAny instproc delete {} {
    my instvar checkoption
    if {[my isStored]} {
      db_transaction {
	db_exec_plsql delete_datatype \
	    "select acs_sc_msg_type__delete(:checkoption);"
      }
    }
  }
  MetaAny proc deleteAll {} {
    # / / / / / / / / / / / / /
    # to be called by before-uninstall
    # hook
    foreach i {[my allinstances]} {
      $i delete
    }
  }
  MetaAny instproc isStored {} {
    my instvar checkoption
    return [db_0or1row is_datatype_stored {
      select * from acs_sc_msg_types where msg_type_name = :checkoption
    }]
  }

  ::xotcl::Class Anything -slots {
    Attribute isRoot -type boolean -default false
    Attribute isVoid -type boolean -default false
    Attribute name
  }

  # / / / / / / / / / / / /
  # TODO: cache subclass tree?
  Anything proc subClassTree {{c {}}} {
    my instvar descendants
    my log "+++1"
    if {$c eq {}} {set c [self]}
    foreach s [$c info subclass] {
      set descendants($s) 0
      my subClassTree $s
    }
    my log "+++2: [array names descendants]"
    return [array names descendants]
  }
  
  Anything proc getTypeClass {key} {
    set key [string toupper $key 0 0]
    return  [lsearch -inline -glob [my subClassTree] *$key]
  }
  
  Anything instproc marshal {document node soapElement} {
    # / / / / / / / / / / / / / / /
    # currently provides for XS-like
    # streaming/ annotation of anys
    my instvar isVoid
    if {!$isVoid} {
      my instvar __value__ name
      # / / / / / / / / / / / / / / / / /
      # TODO: get xsd key from actual objects
      # abstract from the xotcl-soap case here
      # no simple trimleft of prefix 'Xs'
      set xstype [string trimleft [namespace tail [my info class]] Xs]
      set xstype [string tolower $xstype 0 0]
      if {![info exists name]} {
	set name [string map {Response Return} [$soapElement elementName]]
      }
      set returnNode [$node appendChild \
			  [$document createElement $name]]
      $returnNode setAttribute xsi:type "xsd:$xstype"
      $returnNode appendChild \
	  [$document createTextNode $__value__]
    }
  }

  Anything instproc parse {node} {
    my instvar __value__ isRoot isVoid
    puts n=$node,type=[$node nodeType]
    set checkNode [$node firstChild]
    my log "checkNode=$checkNode"
    #set checkNode [expr {$initial?$node:[$node firstChild]}]
    if {$isRoot && $checkNode eq {}} {
      # XsVoid
      set isVoid true
    } elseif {[$checkNode nodeType] eq "TEXT_NODE"} {
      set __value__ [$node text]
    } elseif {[$checkNode nodeType] eq "ELEMENT_NODE"} {
      # / / / / / / / / / / / / / / /
      # look-ahead tests
      # 	1. return-element encoding flaviours: as leaf or 
      #	intermediary composite type
      
      if {$isRoot} {
	set __value__ [$checkNode text]
	set isRoot false
      } else {
	puts children=[$node childNodes]
	foreach c [$node childNodes] {
	  my set $i [[self class] new -childof [self] -parse $c]
	  my set __map__([$c nodeName]) $i
	  incr i
	}
      }
    }
  }
  
  Anything instproc isPrimitive {} {
    my instvar __value__
    return [info exists __value__]
  } 
  
  Anything instproc as {
    -object:switch
    -default
    typeKey
  } {
    if {$typeKey eq {}} {
      return [self]
    } elseif {[my isclass $typeKey]} {
      my mixin add $typeKey
      return [self]
    } else {
      set className [[self class] getTypeClass $typeKey]
      my log "+++3:typeKey=$typeKey,classname=$className"
      if {$className ne {}} {
	my class $className
	my instvar __value__
	my log "+++4:reset-class"
	if {[my validate]} {
	  if {$object} {
	    return [self]
	  } else {
	    return [my unwrap]
	  }
	} elseif {[info exists default]} {
	  return $default
	} else {
	  error "Type cast is not possible."
	}
      } else {
	error "No type handler for '$typeKey' is registered."
      }
    }
  }

  # / / / / / / / / / / / / / /
  # TODO: How to organise validation
  # - 	merry with class hierarchy of 
  #	anythings
  # - 	BUT requires object creation
  #	for checkoption-based validation
  Anything abstract instproc validate args
  #Anything instproc validate {{value {}}} {
  #  if {[[self class] info subclass [my info class]]} {
  #    # redirect to validation provided
  #    # by a subclass (only if valid subclass!
  #    return [[my info class] validate $value]
  #  }
  #}

  Anything instproc unwrap {} {
    if {[my isPrimitive]} {
      return [my set __value__]
    }
  }

  Anything instproc wrap {value} {
    if {[my validate $value]} {
      # TODO
    }
  }

  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  # Checkoption integration
  # for anythings
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #

  # / / / / / / / / / / / / /
  # TODO: when to inject 
  # anything support?:
  # - 	general mixin for nonposArgs
  #	(CURRENT)
  # -	only for call abstractions
  # 	(Invoker, Requestor)?

  ::xotcl::Class Anything::CheckOption
  Anything::CheckOption instproc unknown {checkoption argName argValue} {
    set anyBase [[self class] info parent]
    set anyImpl [$anyBase getTypeClass $checkoption]
    if {$anyImpl ne {}} {
      if {[my isobject $argValue] && [$argValue istype $anyBase]} {
	# / / / / / / / / / / / / /
	# support for anythings
	# passed as argument values
	$argValue class $anyImpl
	return [$argValue validate]
      } else {
	# / / / / / / / / / / / / /
	# TODO: flyweights support?
	set a [$anyImpl new -volatile -set __value__ $argValue]
	return [$a validate]
      }
    } else {
      next
    }
  }

  ::xotcl::Class Anything::CheckOption+Uplift
  Anything::CheckOption+Uplift instproc unknown {checkoption args} {
    set anyBase [[self class] info parent]
    set anyImpl [$anyBase getTypeClass $checkoption]
    if {$anyImpl ne {}} {
      switch [llength $args] {
	1 {
	  foreach argName $args break
	}
	2 {
	  foreach {argName argValue} $args break
	  if {[my isobject $argValue] && \
		  [$argValue istype $anyBase]} {
	    uplevel [list set uplift(-$argName) [$argValue as $checkoption]]
	  } else {
	    # TODO: for return value checks -> conversion in any object?
	    set any [$anyImpl new -set __value__ $argValue -name $argName]
	    if {[$any validate]} {
	      uplevel [list lappend returnObjs $any]
	    }
	  }
 	}
      }
    } else {
      next
    }
  }

  # / / / / / / / / / / / / / / /
  # TODO: keep it that way?
  #::xotcl::nonposArgs mixin add Anything::nonposArgs


  namespace export Anything MetaAny

}