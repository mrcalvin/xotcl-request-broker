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

  # # # # # # # # # # # #
  # # # # # # # # # # # #
  # Little helper meta-class
  # that allows to preserve
  # object aggregations across
  # reload/watch ('recreation')
  # cycles. Anonymously and 
  # explicitly named recreation
  # of nested objects is supported.
  # This issue should ONLY
  # be observable in debugging
  # and development scenarios,
  # where selective reloads
  # might occur, limited to
  # single files, leaving 
  # out others.
  # TODO: Bind to debug_mode?
  # # # # # # # # # # # #
  # # # # # # # # # # # #

  ::xotcl::Class AggregationClass -superclass Class
  AggregationClass proc recreate {obj args} {
    # / / / / / / / / / / / / /
    # inspect current state of
    # aggregation
    foreach c [$obj info children] {
      # / / / / / / / / / / / / / / /
      # handle nested objects that
      # were create by calling 'new'
      set n [namespace tail $c]
      if {[string first "__#" $n] != -1} {
	set prefix "[$c info class] new -childof $obj"
	set stream [$c serialize]
	set idx [string first "-noinit" $stream]
	set body [string range $stream $idx end]
	append children "$prefix $body"
      } else {
	append children [$c serialize]
      }
    }
    next
    # / / / / / / / / / / / / /
    # restore last state of
    # aggregation
    if {[info exists children]} {
      eval $children
    }
  }
  
  namespace export Traversal PreOrderTraversal OrderedComposite \
      TypedOrderedComposite AggregationClass
  
}