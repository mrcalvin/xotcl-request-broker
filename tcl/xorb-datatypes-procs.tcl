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
  
  ::xotcl::Class MetaPrimitive -slots {
    Attribute checkoption
    Attribute protocol -default {::xorb::AcsSc}
  } -superclass ::xotcl::Class
  
  # / / / / / / / / / / / / / / / / /
  # Realising a basic scheme of 
  # anything sponsorship across protocols
  # Sponsor anythings are considered 
  # homolgues in different protocol domains.

  MetaPrimitive instproc isSponsorFor {for} {
    if {[$for istype [self class]] \
	    && [my protocol] ne [$for protocol] \
	    && $for ne [my info class]} {
      $for addSponsor [my protocol] [self]
    }
  }
  
  MetaPrimitive instproc addSponsor {protocol anything} {
    my instvar sponsors
    set sponsors($protocol) $anything
  }

  MetaPrimitive instproc selectSponsor {protocol} {
    my instvar sponsors
    if {$protocol eq [my protocol]} {return [self];}
    foreach {prot sponsor} [array get sponsors] {
      if {$prot eq $protocol} {return $sponsor;}
      return [$sponsor selectSponsor $protocol]
    }
  }

  MetaPrimitive instproc init args {
    my instvar checkoption
    if {![info exists checkoption]} {
      set checkoption [string tolower [namespace tail [self]] 0 0] 
    }
    if {![my isStored]} {
      ::xo::db::sql::acs_sc_msg_type new \
	  -msg_type_name $checkoption \
	  -msg_type_spec {}
    }
    next
  }
  MetaPrimitive instproc validate {value} {
    set any [my new -volatile -set __value__ $value]
    return [$any validate]
  }
  MetaPrimitive instproc delete {} {
    my instvar checkoption
    if {[my isStored]} {
      ::xo::db::sql::acs_sc_msg_type delete \
	  -msg_type_name $checkoption
    }
  }
  MetaPrimitive proc deleteAll {} {
    # / / / / / / / / / / / / /
    # to be called by before-uninstall
    # hook
    foreach i {[my allinstances]} {
      $i delete
    }
  }
  MetaPrimitive instproc isStored {} {
    my instvar checkoption
    return [db_0or1row [my qn is_datatype_stored] {
      select * from acs_sc_msg_types where msg_type_name = :checkoption
    }]
  }

  # / / / / / / / / / / / / / / / / / 
  # In the current realisation of 
  # Anythings merely used for distinguising
  # Anything types that prescribe a 
  # composite structure. Might change
  # in future and revised versions.
  ::xotcl::Class MetaComposite -superclass MetaPrimitive

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
      return  [lsearch -inline -glob [my subClassTree] *::$key]
    }
  }

  Anything proc resolve {key} {
    if {[my isclass $key] && [$key info superclass [self]]} {
      return $key
    } else {
      set key [string toupper $key 0 0]
      return  [lsearch -inline -glob [my subClassTree] *::$key]
    }
  }

  Anything instproc marshal args {
    if {[my isPrimitive]} {
      return "-[my set name__] [my set __value__]"
    }
  }

  Anything instproc containsResultNode {} {
    my instvar isRoot__
    return [expr {$isRoot__ && [llength [my info children]] == 1}]
  }


  Anything instproc parseObject {reader object} {
    $reader instvar cast
    my debug ANYINPARSE=$cast,[$cast serialize]
    foreach s [$cast info slots] {
      set type [$s anyType]
      set ar [AnyReader new \
		  -typecode $type \
		  -protocol [$reader protocol]]
      $s instvar tagName
      set s [namespace tail $s]
      if {[my isobject $object]} {
	set value [$object set $s]
      } else {
	if {[catch {array set tmp $object} e]} {
	  error "Casting associative array into anything failed."
	}
	set value $tmp($s)
      }
      my debug CLASS=[$ar any],value=$value,valueisobject?[my isobject $value]
      # -- Note, we need to make sure that, in case of
      # an object value, the value stores an absolute reference
      # to the object. Otherwise, this might be conflicting
      # because 'isobject' defaults to the global namespace 
      # provided that the stored object identifier is not absolute.
      if {[my isobject $value] && $value eq [$value self]} {
	my debug SER=[$value serialize]
	my add -parse true [[$ar any] new \
			   -childof [self] \
			   -name__ $tagName \
			   -parseObject $ar $value]
      } else {
	my add -parse true [[$ar any] new \
			   -childof [self] \
			   -name__ $tagName \
			   -set __value__ $value]
      }
    }
  }
  
  Anything instproc add {{-parse false} any} {
    my lappend __ordinary_map__ $any
    my debug ANYPARSE=[$any serialize]
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
    {-protocol  ::xorb::AcsSc}
    -object:switch
    -default
    typeKey
  } {
    if {$typeKey eq {}} {
      return [self]
    } else {
      set ar [AnyReader new \
		  -protocol $protocol \
		  -typecode $typeKey]
      my debug "+++3:typeKey=[$ar any]"
      # 3) recast anything into concrete anything implementation
      my class [$ar any]
      
      # 4) process anything further: validation + unwrapping
      my debug --x1
      if {[my validate $ar]} {
	my debug --x2
	if {$object} {
	  my debug --x3
	  return [self]
	} else {
	  my debug --x4
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
    Attribute protocol -default "::xorb::AcsSc"
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
    my debug tc=$tc
    switch [llength $tc] {
      1 { set tokens any;}
      2 { set tokens [list any cast]}
      3 { set tokens [list any cast suffix]}
      default {
	error "Invalid typecode specification: $tc"
      }
    }
    foreach $tokens $tc break;
    # b) resolve Anything
    # / / / / / / / / / / / / / / /
    # Starting with 0.4, resolution is
    # done in two steps:
    # 1-) resolving the typecode in
    # an anything object
    # 2-) identifying the actual, protocol
    # dependent anything sponsor.
    set any [Anything resolve $any]
    if {$any eq {}} {
      error "Invalid typecode specification: $tc"
    }

    set sp [$any selectSponsor [my protocol]]
    if {$sp eq {}} {
      error [subst {
	No sponsor could be identified for Anything '$any' 
	in the realm of protocol '[my protocol]'.}]
    }
    set any $sp
    my debug IN-READER=$sp/any=$any
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
    my debug MIXINS=$mixins
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
    my debug tagName?[info exists tagName]
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
  # / / / / / / / / / / / / / /
  # 'glue' is a simple delegate for 
  # 'required' in the scope of nonposArgs when
  # decorated by CheckOption+Uplift!
  Anything::CheckOption+Uplift instforward glue %self required
  # / / / / / / / / / / / / / /
  # xotcl-core already comes with
  # a equally named proc on ::xotcl::nonposArgs
  # which bypasses the checkoption+uplift mechanism
  # we therefore have to redirect the call the
  # default unknown mechanism
  Anything::CheckOption+Uplift instproc integer args {
    eval my unknown [self proc] $args
    if {[info exists returnObjs]} {
      uplevel [list set returnObjs $returnObjs]
    } elseif {[array exists uplift]} {
      uplevel [list array set uplift [array get uplift]]
    }
  }
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
    # / / / / / / / / / / / / / / / /
    # calling object need to be ...
    # 1-) either ::xorb::Invoker
    # 2-) or ::xorb::stub::Requestor
    set p [self callingobject]
    my debug UPLIFT-CALLER=$p,[my stackTrace]
    set ar [eval ::xorb::datatypes::AnyReader new \
		-typecode $checkoption \
		[expr {[$p exists protocol]?"-protocol [$p set protocol]":""}]]
    my debug "CHECKOPTION:$checkoption,ARGS=$args,ANY=[$ar any]"
    if {[$ar any] ne {}} {
      # my log "ARANY=[$ar any]"
      switch [llength $args] {
	1 {
	  foreach argName $args break
	}
	2 {
	  #set isObj [[$ar any] info superclass ::xosoap::xsd::XsCompound]
	  set isObj [[$ar any] istype ::xorb::datatypes::MetaComposite]
	  foreach {argName argValue} $args break
	  if {[my isobject $argValue] && \
		  [$argValue istype $anyBase]} {
	    my debug ===1,[$argValue serialize],[my stackTrace]
	    uplevel [list set uplift(-$argName) \
			 [eval $argValue as \
			      [expr {[$p exists protocol]?\
					 "-protocol [$p set protocol]":""}] \
			      $checkoption]]

	  } elseif {([my isobject $argValue] || \
			 ![catch {array set tmp $argValue} msg]) && $isObj} {
	    #if {$class eq {}} {
	    #  set class [$argValue info class]
	    #} else {
	    #  set class [string trimleft $class =]
	    #}
	    #my log "ARANY-INSIDE=[$ar any]"
	    my debug ===2
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
	    my debug ===3,$argValue,$argName
	    set any [[$ar any] new -set __value__ $argValue -name__ $argName]
	    if {[$any validate]} {
	      my debug ===3a,ANY=$any,cp=[self callingproc],stack=[my stackTrace]
	      uplevel [list lappend returnObjs $any]
	    } else {
	      error [::xorb::exceptions::TypeViolationException new [subst {
		value: $argValue,
		type: [$any info class]
	      }]]
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

  # / / / / / / / / / / / / / / /
  # TODO: Provide Anything definitions
  # for the following atomic types as
  # declared/ used by ACS Service Contracts
  # (see acs_sc_msg_types).
  # integer
  # string
  # boolean
  # timestamp
  # uri
  # version
  # float
  # bytearray

  MetaPrimitive Void -superclass Anything \
      -instproc validate args {
	my instvar __value__
	return [expr {$__value__ eq {}}]
      }
  
  
  MetaPrimitive String -superclass Anything \
      -instproc validate args {
	# as everything is a string
	my instvar __value__
	return 1
      }
  
  MetaPrimitive Integer -superclass Anything \
      -instproc validate args {
	my instvar __value__
	return [string is integer $__value__]
      }

  MetaPrimitive Boolean -superclass Anything \
      -instproc validate args {
	my instvar __value__
	return [string is boolean $__value__]
      }
  
  MetaPrimitive Timestamp -superclass Anything \
      -instproc validate args {
	# / / / / / / / / / / / / / / / /
	# It is not quite clear to me
	# by which means 'timestamp' is
	# defined (in terms of a value space)
	# in the context of message types.
	# However, I assume compatibility to SQL:1999 
	# data type 'timestamp' WITHOUT timezone.
	# This reflects by observation, that
	# timestamp is, for instance, generated through
	# ns_localsqltimestamp which omits the TZ, e.g.
	# 2007-07-26 18:40:36
	my instvar __value__
	return [regexp {^([1-9]\d\d\d+|0\d\d\d)-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])\s(([01]\d|2[0-3]):[0-5]\d:[0-5]\d$} $__value__]
	return 1
      }
  
  MetaPrimitive Uri -superclass Anything \
      -instproc validate args {
	# / / / / / / / / / / / / / / / /
	# Lacking, again, a clear
	# understanding on what uri
	# refers to, we adopt a so-so
	# validation following RFC 3986
	# we first extract the five and
	# components and the verify for
	# a scheme-qualified uri
	# see http://rfc.sunsite.dk/rfc/rfc3986.html
	my instvar __value__
	if {[regexp {^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?} $__value__ _ 1 scheme 3 authority path 6 query 8 fragment]} {
	  # validation
	  # 1-) scheme
	  if {$scheme eq {} || ![regexp {^[[:alnum:]\+\-\.]+$} $scheme]} {return 0;}
	  if {$authority eq {} || ![regexp {^([[:alnum:]\:]*@)?[[:alnum:]\_\-\.\~]+|(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$} $authority]} {return 0;}
	  if {$path ne {} && ![regexp {^/?[[:alnum:]\_\-\.\~\!\$\&\'\(\)\*\+\,\;\=\:\@]+(/[[:alnum:]\_\-\.\~\!\$\&\'\(\)\*\+\,\;\=\:\@]+)*$} $path]}
	  if {$query ne {} && ![regexp {^[[:alnum:]\_\-\.\~\!\$\&\'\/\(\)\*\+\,\;\=\:\@\/\?]+$} $query]} {return 0;}
	  if {$fragment ne {} && ![regexp {^[[:alnum:]\_\-\.\~\!\$\&\'\/\(\)\*\+\,\;\=\:\@\/\?]+$} $fragment]} {return 0;}
	} else {
	  return 0
	}
	return 1
      }
  
  MetaPrimitive Version -superclass Anything \
      -instproc validate args {
	# / / / / / / / / / / / / / / / / / / / / / / / / /
	# I employ the regex as specified
	# at http://openacs.org/doc/current/apm-design.html
	return [regexp {^[0-9]+((\.[0-9]+)+((d|a|b|)[0-9]?)?)$} $__value__]
	my instvar __value__
	return 1
      }
  
  # / / / / / / / / / / / / / / / / 
  # It remains widely unclear to me
  # how to conceptualise a validation
  # for the latter two types, as
  # there is hardly any source of
  # reference. I leave it open for the
  # moment.
  # / / / / / / / / / / / / / / / /
  # As for floatings, we limit ourselves
  # to a format validation, no value
  # space is enforced
  MetaPrimitive Float -superclass Anything \
      -instproc validate args {
	my instvar __value__
	return [regexp {[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?^$} $__value__]
      }
  
  MetaPrimitive Bytearray -superclass Anything \
      -instproc validate args {
	my instvar __value__
	return 1
      }
	
  MetaComposite Object -slots {
    Attribute template
  } -superclass Anything
  Object instproc validate {reader} {
    my instvar template
    set template [$reader cast]
    # TODO: is validate for complex types
    # or structs needed? Handled by 'as' anyway!
    return true
  } 
  Object instproc unwrap args {
    my instvar template
    if {![my isclass $template]} {
      error "No such class '$template' declared/ available."
    }
    set anyObj [self]
    
    if {$template eq {}} {
      error "type key specification '$typeKey' invalid."
    } 
    foreach s [$template info slots] {
      set type [$s anyType]
      set s [namespace tail $s]
      $anyObj instvar __ordinary_map__
      if {![string is integer $s] && [$anyObj exists $s]} {
	set any [$anyObj set $s]
      } elseif {[string is integer $s]} {
	set any [lindex $__ordinary_map__ $s]
      } else {
	error "Cannot resolve accessor '$s' to nested element in Anything object."
      }
      my debug any=$any,typeKey=$type
      set unwrapped [$any as -protocol ::xorb::AcsSc $type]
      my debug unwrapped=$unwrapped
      $anyObj set $s $unwrapped
    }
    $anyObj class $template
    return $anyObj
  }
  namespace export Anything MetaPrimitive AnyReader String \
      Integer MetaComposite Boolean
}