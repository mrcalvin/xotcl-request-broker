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

  # / / / / / / / / / / / / / / / / /
  # Attributes of Anythings have to be
  # renamed or escaped accordingly. As
  # demarshalled values are stored as
  # ordinary instance variables, we
  # could otherwise expect name clashes
  # and therefore parsing errors!
  ::xotcl::Class Anything -slots {
    Attribute isRoot__ -type boolean -default false
    Attribute isVoid__ -type boolean -default false
    Attribute name__
  }

  # / / / / / / / / / / / /
  # TODO: cache subclass tree?
  Anything proc subClassTree {{c {}}} {
    my instvar descendants
    #my log "+++1"
    if {$c eq {}} {set c [self]}
    foreach s [$c info subclass] {
      set descendants($s) 0
      my subClassTree $s
    }
    #my log "+++2: [array names descendants]"
    return [array names descendants]
  }
  # / / / / / / / / / / / / / / / / / / / /
  # TODO: turn it into per-instance method
  # called 'expand' and therefore make it overloadable
  # by subclasses
  Anything proc getTypeClass {key} {
    #  && [$key info superclass [self]] needed?
    if {[my isclass $key]} {
      return $key
    } else {
      set key [string toupper $key 0 0]
      return  [lsearch -inline -glob [my subClassTree] *$key]
    }
  }

  Anything proc resolve {key} {
    if {[my isclass $key] && [$key info superclass [self]]} {
      return $key
    } else {
      set key [string toupper $key 0 0]
      return  [lsearch -inline -glob [my subClassTree] *$key]
    }
  }

  Anything instproc marshal args {next}

  Anything instproc containsResultNode {} {
    my instvar isRoot__
    return [expr {$isRoot__ && [llength [my info children]] == 1}]
  }


  Anything instproc parseObject {reader object} {
    $reader instvar cast
    my log ANYINPARSE=$cast
    foreach s [$cast info slots] {
      set type [$s anyType]
      set ar [AnyReader new -typecode $type]
      $s instvar tagName
      set s [namespace tail $s]
      set value [$object set $s]
      my log CLASS=[$ar any],object=$value,isobject?[my isobject $value]
      if {[my isobject $value]} {
	my add -parse [[$ar any] new \
			   -childof [self] \
			   -name__ $tagName \
			   -parseObject $ar $value]
      } else {
	my add -parse [[$ar any] new \
			   -childof [self] \
			   -name__ $tagName \
			   -set __value__ $value]
      }
    }
  }
  
  Anything instproc add {-parse:switch any} {
    my lappend __ordinary_map__ $any
    my log ANYPARSE=[$any serialize]
    if {$parse} {my set [$any name__] $any} 
  }
  
  Anything instproc isPrimitive {} {
    my instvar __value__
    return [info exists __value__]
  } 
  
  Anything proc tokenise {typeKey} {
    # / / / / / / / / / / / / / / /
    # a simple tokeniser: it allows for
    # the following notational forms
    # for anything type keys:
    # <anything><some-non-word-character><constraints>
    # e.g.:
    # soapArray=xsInteger[4]
    # soapStruct=::xosoap::demo::exampleStruct
    # soapArray=::xosoap::demo::exampleStruct[4]
    # xsCompound={
    #  sizeOf 4
    #  contains   xsInteger
    #  is     
    #}
    uplevel [list regexp {^(\w+)(.*)?$} $typeKey _ hook typeInfo]
  }

   Anything instproc as {
    -object:switch
    -default
    typeKey
  } {
    if {$typeKey eq {}} {
      return [self]
    } else {
      set ar [AnyReader new -typecode $typeKey]
      my log "+++3:typeKey=[$ar any]"
      # 3) recast anything into concrete anything implementation
      my class [$ar any]
      
      # 4) process anything further: validation + unwrapping
      if {[my validate $ar]} {
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
    }
  }
  

#    Anything instproc as {
#     -object:switch
#     -default
#     typeKey
#   } {
#     if {$typeKey eq {}} {
#       return [self]
#     } else {
#       # 1) apply tokeniser > yields two variables: hook + typeInfo
#       [self class] tokenise $typeKey
#       # 2) resolve typeKey
#       set typeKey [expr {[info exists hook]?$hook:$typeKey}]
#       set typeInfo [expr {[info exists typeInfo]?$typeInfo:""}]
#       set typeInfo [string trimleft $typeInfo =]
#       set className [[self class] getTypeClass $typeKey]
#       my log "+++3:typeKey=$typeKey,classname=$className,typeInfo=$typeInfo"
#       if {$className ne {}} {
# 	# 3) recast anything into concrete anything implementation
# 	my class $className

# 	# 4) process anything further: validation + unwrapping
# 	if {[my validate $typeInfo]} {
# 	  if {$object} {
# 	    return [self]
# 	  } else {
# 	    return [my unwrap]
# 	  }
# 	} elseif {[info exists default]} {
# 	  return $default
# 	} else {
# 	  error "Type cast is not possible."
# 	}
#       } else {
# 	error "No type handler for '$typeKey' is registered."
#       }
#     }
#   }

  

  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #
  # A small interpreter for
  # typecodes as used to declare
  # Anythings
  # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # #

  ::xotcl::Class AnyReader -slots {
    Attribute typecode
    Attribute observer
    Attribute name
    Attribute any
    Attribute cast
    Attribute suffix
    Attribute style
    Attribute inCompound -default 0
  }
  
  AnyReader instproc init args {
    my instvar any cast suffix
    # a) tokenise
    set tc [my enbrace]
    my log tc=$tc
    switch [llength $tc] {
      1 { set tokens any;}
      2 { set tokens [list any cast]}
      3 { set tokens [list any cast suffix]}
      default {
	error "Invalid typecode specification."
      }
    }
    foreach $tokens $tc break;
    # b) resolve Anything
    set any [Anything resolve $any]
    if {$any eq {}} {
      error "Invalid typecode specification."
    }
  }
  
  AnyReader instproc get {what} {
    my instvar any name style
    if {[my isclass $any]} {
      # / / / / / / / / / / / /
      # TODO: introduce flyweights for
      # anythings!
      set any [$any new]
      if {[info exists name]} {
	$any name__ $name
      }
    }
    # / / / / / / / / / / / / / / /
    # Introduce styles
    set class [$any info class]
    foreach h [concat $class [$class info heritage]] {
      set hstripped [namespace tail $h]
      #my log ATTEMPT=${style}::${hstripped}
      set mixins {}
      if {[my isclass ${style}::${hstripped}]} {
	append mixins ${style}::${hstripped}
	$any mixin add ${style}::${hstripped}
      }
    }
    my log MIXINS=$mixins
    if {[$any info methods expand=$what] ne {}} {
      set result [$any expand=$what [self]] 
    }
    foreach m $mixins {
      $any mixin delete $m
    }
    if {[info exists result]} {
      return $result
    }
  }
  
  AnyReader instproc enbrace {} {
    my instvar typecode
    return [string map {"(" " {" ")" "} "} $typecode]
  }

  AnyReader instproc unbrace {{in {}}} {
    if {$in eq {}} { 
      my instvar typecode
      set in $typecode
    }
    return [string map {" {" "(" "} " ")"} $in]
  }

  
  #  Anything instproc as {
  #     -object:switch
#     -default
#     typeKey
#   } {
#     my log SER=[my serialize],typeKey=$typeKey
#     if {[my isPrimitive]} {
#       if {$typeKey eq {}} {
# 	return [self]
#       } else {
# 	set className [expr {[my isclass $typeKey]?$typeKey:\
# 				 [[self class] getTypeClass $typeKey]}]
# 	my log "+++3:typeKey=$typeKey,classname=$className"
# 	if {$className ne {}} {
# 	  my class $className
# 	  my instvar __value__
# 	  my log "+++4:reset-class"
# 	  if {[my validate]} {
# 	    if {$object} {
# 	      return [self]
# 	    } else {
# 	      return [my unwrap]
# 	    }
# 	  } elseif {[info exists default]} {
# 	    return $default
# 	  } else {
# 	    error "Type cast is not possible."
# 	  }
# 	} else {
# 	  error "No type handler for '$typeKey' is registered."
# 	}
#       }
#     } else {
#       set isObj  [regexp {^object(=(.*))?$} $typeKey _ class]
#       set anyObj my
#       if {[my containsResultNode]} {
# 	set anyObj [my info children] 
#       }
#       if {!$isObj || $class eq {}} {
# 	error "type key specification '$typeKey' invalid."
#       } else {
# 	set class [string trimleft $class =]
# 	foreach s [$class info slots] {
# 	  set type [$s anyType]
# 	  set s [namespace tail $s] 
# 	  set any [$anyObj set $s]
# 	  my log any=$any,typeKey=$type
# 	  set unwrapped [$any as $type]
# 	  my log unwrapped=$unwrapped
# 	  $anyObj set $s [$any as $type]
# 	}
# 	$anyObj mixin add $class
# 	return $anyObj
#       }
#     }
#   }

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
    Attribute tagName
  }
  AnyAttribute instproc init args {
    my instvar type tagName
    if {[info exists type]} {
      my anyType $type
      my type "$type validate"
    }
    my log tagName?[info exists tagName]
    if {![info exists tagName]} {
      set tagName [namespace tail [self]]
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
    # $anyBase tokenise $checkoption
    # set typeKey [expr {[info exists hook]?$hook:$checkoption}]
    # set typeInfo [expr {[info exists typeInfo]?$typeInfo:""}]
    # set anyImpl [$anyBase getTypeClass $typeKey]


    # / / / / / / / / / / / / / / / / 
    # TODO: generalise the verification
    # should be independent from protocol
    # plugins, introduce Simple and Compound subclasses
    # for Anything!
    #set isObj  [regexp {^object(=(.*))?$} $checkoption _ class]
    set anyBase [[self class] info parent]
    set ar [::xorb::datatypes::AnyReader new -typecode $checkoption]
    if {[$ar any] ne {}} {
      my log "ARANY=[$ar any]"
      switch [llength $args] {
	1 {
	  foreach argName $args break
	}
	2 {
	  set isObj [[$ar any] info superclass ::xosoap::xsd::XsCompound]
	  foreach {argName argValue} $args break
	  if {[my isobject $argValue] && \
		  [$argValue istype $anyBase]} {
	    uplevel [list set uplift(-$argName) [$argValue as $checkoption]]
	  } elseif {[my isobject $argValue] && $isObj} {
	    #if {$class eq {}} {
	    #  set class [$argValue info class]
	    #} else {
	    #  set class [string trimleft $class =]
	    #}
	    my log "ARANY-INSIDE=[$ar any]"
	    uplevel [list lappend returnObjs \
			 [[$ar any] new \
			      -name__ $argName \
			      -parseObject $ar $argValue]]
	    #  uplevel [list lappend returnObjs \
		# 			 [$anyBase new \
		# 			      -name $argName \
		# 			      -parseObject $class $argValue]]
	  } else {
	    # TODO: for return value checks -> conversion in any object?
	    set any [[$ar any] new -set __value__ $argValue -name__ $argName]
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


#   Anything::CheckOption+Uplift instproc unknown {checkoption args} {
#     set anyBase [[self class] info parent]
#     $anyBase tokenise $checkoption
#     set typeKey [expr {[info exists hook]?$hook:$checkoption}]
#     set typeInfo [expr {[info exists typeInfo]?$typeInfo:""}]
#     set anyImpl [$anyBase getTypeClass $typeKey]
#     # / / / / / / / / / / / / / / / / 
#     # TODO: generalise the verification
#     # should be independent from protocol
#     # plugins, introduce Simple and Compound subclasses
#     # for Anything!
#     set isObj [$anyImpl info superclass ::xosoap::xsd::XsCompound]
#     set class $typeInfo
#     #set isObj  [regexp {^object(=(.*))?$} $checkoption _ class]
#     if {$anyImpl ne {} || $isObj} {
#       switch [llength $args] {
# 	1 {
# 	  foreach argName $args break
# 	}
# 	2 {
# 	  foreach {argName argValue} $args break
# 	  if {[my isobject $argValue] && \
# 		  [$argValue istype $anyBase]} {
# 	    uplevel [list set uplift(-$argName) [$argValue as $checkoption]]
# 	  } elseif {[my isobject $argValue] && $isObj} {
# 	    if {$class eq {}} {
# 	      set class [$argValue info class]
# 	    } else {
# 	      set class [string trimleft $class =]
# 	    }
# 	    uplevel [list lappend returnObjs \
# 			 [$anyImpl new \
# 			      -name $argName \
# 			      -parseObject $class $argValue]]
# 	    #  uplevel [list lappend returnObjs \
# 		# 			 [$anyBase new \
# 		# 			      -name $argName \
# 		# 			      -parseObject $class $argValue]]
# 	  } else {
# 	    # TODO: for return value checks -> conversion in any object?
# 	    set any [$anyImpl new -set __value__ $argValue -name $argName]
# 	    if {[$any validate]} {
# 	      uplevel [list lappend returnObjs $any]
# 	    }
# 	  }
#  	}
#       }
#     } else {
#       next
#     }
#   }

  # / / / / / / / / / / / / / / /
  # TODO: keep it that way?
  #::xotcl::nonposArgs mixin add Anything::nonposArgs


  namespace export Anything MetaAny AnyReader

}