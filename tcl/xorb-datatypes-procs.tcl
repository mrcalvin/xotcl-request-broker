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
  MetaAny instproc validate {value} {
    set any [my new -volatile -set __value__ $value]
    return [$any validate]
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

  # / / / / / / / / / / / / / / / / /
  # TODO: refacture marshal und parse 
  # (demarshal) into xotcl-soap
  # !!!!!!
  
  Anything instproc marshal {document node soapElement} {
    # / / / / / / / / / / / / / / /
    # currently provides for XS-like
    # streaming/ annotation of anys
    my instvar isVoid
    if {!$isVoid && [my isPrimitive]} {
      my instvar __value__ name
      # / / / / / / / / / / / / / / / / /
      # TODO: get xsd key from actual objects
      # abstract from the xotcl-soap case here
      # no simple trimleft of prefix 'Xs'
      set xstype [string trimleft [namespace tail [my info class]] Xs]
      set xstype [string tolower $xstype 0 0]
      if {[$soapElement istype ::xosoap::marshaller::SoapBodyResponse] && \
	      ![info exists name]} {
	set name [string map {Response Return} [$soapElement elementName]]
      }
      set anyNode [$node appendChild \
			  [$document createElement $name]]
      $anyNode setAttribute xsi:type "xsd:$xstype"
      $anyNode appendChild \
	  [$document createTextNode $__value__]
    } else {
      # complex type
      my instvar __ordinary_map__ name
      set anyNode [$node appendChild \
		       [$document createElement $name]]
      foreach c $__ordinary_map__ {
	$c marshal $document $anyNode $soapElement
      }
    }
  }

  Anything instproc containsResultNode {} {
    my instvar isRoot
    return [expr {$isRoot && [llength [my info children]] == 1}]
  }

  Anything instproc parse {node} {
    my instvar __value__ isRoot isVoid
    #my log n=$node,type=[$node nodeType],xml=[$node asXML]
    set checkNode [$node firstChild]
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
      #my log isRoot=$isRoot
      if {$isRoot && [[$checkNode firstChild] nodeType] eq "TEXT_NODE"} {
	set __value__ [$checkNode text]
	set isRoot false
      } else {
	puts children=[$node childNodes]
	foreach c [$node childNodes] {
	  #my set $i [[self class] new -childof [self] -parse $c]
	 # my set __map__([$c nodeName]) $i
	  #incr i
	  set any [[self class] new \
		       -childof [self] \
		       -name [$c nodeName] \
		       -parse $c]
	  my add -parse $any
	}
      }
    }
  }
  Anything instproc parseObject {class object} {
    foreach s [$class info slots] {
      set type [$s anyType]
      set s [namespace tail $s] 
      set value [$object set $s]
      if {[my isobject $value]} {
	my add -parse [Anything new \
			   -childof [self] \
			   -name $s \
			   -parseObject $type $value]
      } else {
	my add -parse [$type new \
			   -childof [self] \
			   -name $s \
			   -set __value__ $value]
      }
    }
  }
  
  
  Anything instproc add {-parse:switch any} {
    my lappend __ordinary_map__ $any
    if {$parse} {my set [$any name] $any} 
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
    my log SER=[my serialize],typeKey=$typeKey
    if {[my isPrimitive]} {
      if {$typeKey eq {}} {
	return [self]
      } else {
	set className [expr {[my isclass $typeKey]?$typeKey:\
				 [[self class] getTypeClass $typeKey]}]
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
    } else {
      set isObj  [regexp {^object(=(.*))?$} $typeKey _ class]
      set anyObj my
      if {[my containsResultNode]} {
	set anyObj [my info children] 
      }
      if {!$isObj || $class eq {}} {
	error "type key specification '$typeKey' invalid."
      } else {
	set class [string trimleft $class =]
	foreach s [$class info slots] {
	  set type [$s anyType]
	  set s [namespace tail $s] 
	  set any [$anyObj set $s]
	  my log any=$any,typeKey=$type
	  set unwrapped [$any as $type]
	  my log unwrapped=$unwrapped
	  $anyObj set $s [$any as $type]
	}
	$anyObj mixin add $class
	return $anyObj
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
  # Attribute slot integration
  # for short-cut usage with
  # Any types.
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #


  ::xotcl::Class AnyAttribute -superclass ::xotcl::Attribute -slots {
    Attribute anyType
  }
  AnyAttribute instproc init args {
    my instvar type
    if {[info exists type]} {
      my anyType $type
      my type "$type validate"
    }
    next
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
    set isObj  [regexp {^object(=(.*))?$} $checkoption _ class]
    if {$anyImpl ne {} || $isObj} {
      switch [llength $args] {
	1 {
	  foreach argName $args break
	}
	2 {
	  foreach {argName argValue} $args break
	  if {[my isobject $argValue] && \
		  [$argValue istype $anyBase]} {
	    uplevel [list set uplift(-$argName) [$argValue as $checkoption]]
	  } elseif {[my isobject $argValue] && $isObj} {
	    if {$class eq {}} {
	      set class [$argValue info class]
	    } else {
	      set class [string trimleft $class =]
	    }
	    my log "+++class=$class"
	    uplevel [list lappend returnObjs \
			 [$anyBase new \
			      -name $argName \
			      -parseObject $class $argValue]]
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