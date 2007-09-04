ad_library {
    
    xorb auxiliary library
    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date January 30, 2006
    @cvs-id $Id$
    
}
ns_log debug LOADING
namespace eval ::xorb::aux {

  # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # 
  # Class AcsObjectType
  # A skeleton helper to
  # handle the management of
  # ACS Object (Types) at the
  # XOTcl Layer. It is only capable
  # of registering an XOTcl class
  # as ACS Object Type. In a not
  # so far future it will be subject
  # of adapting more generic
  # facilities of the xotcl-core
  # It is a strip-down version
  # of implementation studies
  # of Gustaf Neumann, so all credits
  # shall therefore go to him.
  # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # 

  ::xotcl::Class AcsObjectType -superclass ::xotcl::Class -slots {
    Attribute pretty_name
    Attribute pretty_plural
    Attribute supertype -default acs_object
    Attribute table_name -default ""
    Attribute id_column -default ""
    Attribute abstract_p -default "f"
    Attribute name_method -default ""
    Attribute object_type -default {[self]}
    Attribute security_inherit_p -default "t"
    Attribute lazilyAcquireTable -default false
    Attribute attributes -default {}
    Attribute dbConstructor -default new
    Attribute dbDestructor -default delete
    Attribute dbPackage
  }
  AcsObjectType set procExists {
    select exists (select 1 from pg_proc where proname = '$m');
  }
  AcsObjectType set numArgs {
    select count(*) from acs_function_args where function = '$mUpper';
  }
  AcsObjectType instproc existsObjectType {} {
    my instvar object_type
    expr {$object_type eq [db_list [my qn select_object_type] {
      select object_type from acs_object_types where 
      object_type = :object_type
    }]}
  }
  AcsObjectType instproc createObjectType {} {
    my instvar object_type supertype pretty_name pretty_plural \
        table_name id_column name_method abstract_p
    
    if {![info exists pretty_name]}   {set pretty_name [namespace tail [self]]}
    if {![info exists pretty_plural]} {set pretty_plural $pretty_name}

    ::xo::db::sql::acs_object_type create_type \
        -object_type $object_type \
        -supertype [$supertype object_type] \
        -pretty_name $pretty_name \
        -pretty_plural $pretty_plural \
        -table_name $table_name \
        -id_column $id_column \
        -abstract_p $abstract_p \
        -name_method $name_method

    # provide for table creation, 
    # similar to content_type__create_type
    # but at the XOTcl layer ...
    if {![my lazilyAcquireTable]} {
      my acquireTable
    }
  }

  AcsObjectType instproc dropObjectType {{-cascade true}} {
    my instvar object_type table_name abstract_p
    if {[my existsObjectType]} {
      ::xo::db::sql::acs_object_type drop_type \
	  -object_type $object_type \
	  -cascade_p [expr {$cascade ? "t" : "f"}]
      # TODO: Oracle manko ...
      if {!$abstract_p} {
	db_dml [my qn drop_object_type_table] "drop table $table_name"
	my releaseConstructor
      }
    }
  }
  
  AcsObjectType instproc setRelationAttributes {attribute} {
    my instvar __relation_attributes__
    set __relation_attributes__($attribute) 1
  }
  
  AcsObjectType instproc getRelationAttributes {{what plpgsql} {idx 1}} {
    my instvar __relation_attributes__ supertype table_name id_column
    # if __relation_attributes__ does not exist (type without attributes), 
    # default to {}
    if {![array exists __relation_attributes__]} {
      array set __relation_attributes__ [list]
    }
    set relAttributes [array names __relation_attributes__]
    switch -- $what {
      plpgsql {
	#foreach a $__relation_attributes__ {
	#  lappend r "p_$a alias for \$$idx;"
	#  incr idx
	#}
	set r $relAttributes
      }
      record {
	foreach a $relAttributes {
	  regexp {\w+} [my slot $a sqltype] type
	  lappend r $type
	} 
      }
      storedArgs {
	foreach a $relAttributes {
	  if {[my slot $a exists dbDefault]} {
	    lappend r $a;[my slot $a dbDefault]
	  } else {
	    lappend r $a
	  }
	}
      }
      sql-load {
	if {$table_name ne {} && $id_column ne {}} {
	  set tmp [list]
	  #my debug __relation_attributes__=$__relation_attributes__
	  foreach a $relAttributes {
	    lappend tmp $table_name.$a
	  }
	  set r [list $table_name.$id_column $tmp]
	  my debug r=$r
	}
      }
      sql-insert {
	if {$table_name ne {} && $id_column ne {}} {
	  set cols [expr {$relAttributes ne {}?\
			      ",[join $relAttributes ,]":""}]
	  set vars [expr {$relAttributes ne {}?\
			      ",p_[join $relAttributes ,p_]":""}]
	  set r [subst {
	    insert into $table_name ($id_column$cols) 
	    values (v_object_id$vars);
	  }]
	}
      }
    }

    if {![info exists r]} {set r {}}

    if {[$supertype object_type] ne "acs_object"} {
      return [concat [$supertype getRelationAttributes $what $idx] $r]
    } else {
      return $r
    }
  }
  AcsObjectType instproc getConstructor {{style plpgsql}} {
    my acquireConstructor
    my debug GETCONST=[my serialize]
    my instvar dbPackage dbConstructor __relation_attributes__ supertype \
	abstract_p
    if {!$abstract_p} {
      my instvar dbPackage dbConstructor __relation_attributes__
      set m ${dbPackage}__$dbConstructor
      switch -- $style {
	plpgsql {
	  return ${m}(p_[join [array names __relation_attributes__] ,p_])
	}
	"xo" {
	  regexp {(.+)__(.+)} $m _ object proc
	  return "::xo::db::sql::$object $proc"
	}
      }
    } else {
      if {[my isobject $supertype] && [$supertype istype [self class]]} {
	return [$supertype getConstructor]
      }
    }
 
  }

  AcsObjectType instproc releaseConstructor {} {
    # 1) clear ::xo::db::representation
    # 2) clear db (acs_function_args & drop)
    my instvar dbPackage dbConstructor
    if {![info exists dbPackage]} {
      set dbPackage [my canonise [my set object_type]]
    }
    set m ${dbPackage}__$dbConstructor
    my debug m=$m,exists=[db_string [my qn ""] [subst [[self class] set procExists]]]

    if {[db_string [my qn ""] [subst [[self class] set procExists]]]} {
      set types_declaration [my getRelationAttributes record]
      db_dml [my qn delete_constructor] \
	  "drop function ${m}([join $types_declaration ,])"

      # / / / / / / / / / / / / / / / /
      # to make sure that we don't clear acs_function_args
      # from a constructor version with a recor set other
      # than the fully expanded (=exposing all attributes of
      # the type) we provide for an attribute count!
      
      set c [llength $types_declaration]
      set mUpper [string toupper $m]

      # TODO: unify acs_function_args calls procExists + numArgs to a s
      # single, namely the latter to avoid db polling!!!!
      set nargs [db_string [my qn ""] [subst [[self class] set numArgs]]]
      my debug c=$c,nargs=$nargs
      if {$nargs eq $c} {
	db_dml [my qn clear_from_function_tbl] \
	    "delete from acs_function_args where function = '$mUpper'"
	# - - -
	# clear from ::xo::db::sql layer
	# - - -
	
	if {[my isobject ::xo::db::sql::$dbPackage] &&\
	      [::xo::db::sql::$dbPackage info methods $dbConstructor] ne {}} {
	  # TODO: as the wrappers are defined through
	  # ad_proc, shall we also clean the ad_*
	  # information (is handled by server restart
	  # anyway)???
	  ::xo::db::sql::$dbPackage proc $dbConstructor {} {}
	}
      }
    }
    
  }

  AcsObjectType instproc acquireConstructor {} {
    my instvar dbConstructor __relation_attributes__ id_column supertype \
	table_name dbPackage __requireRefresh__ abstract_p
    if {$__requireRefresh__ || !$abstract_p} {
      if {![info exists dbPackage]} {
	set dbPackage [my canonise [my set object_type]] 
      }
      
      
      # __relation_attributes might not be initialised for types that did not
      # define any AcsAttributes. Default it to an empty tcl string.
      
      if {![array exists __relation_attributes__]} {
	array set __relation_attributes__ [list]
      }
      set relAttributes [array names __relation_attributes__]
      set m ${dbPackage}__$dbConstructor
      
      if {![db_string [my qn ""] [subst [[self class] set procExists]]]} {
	#set outerInterface [concat [$supertype set __relation_attributes__] \
	#			$__relation_attributes__]
	set types_declaration [my getRelationAttributes record]
	
	set idx 1
	foreach a [my getRelationAttributes] {
	  lappend declaration "p_$a alias for \$$idx;"
	  incr idx
	}
	set declare [subst {
	  declare
	  [join $declaration]
	  v_object_id integer;
	}]
	
	# resolve constructor of supertype
	# set supertypeCall [$supertype getConstructor]
	# / / / / / / / / / / / / / / / / /
	# 1) call acs_object__new directly 
	set supertypeCall [subst {
	  acs_object__new(
			  null,
			  ''[my object_type]'',
			  now(),
			  null,
			  null,
			  null,
			  ''t'',
			  null,
			  null
			  );
	}]

	# TODO: default to an acs_object__new call
	#set refs [expr {$relAttributes eq {}?\
	#		    "":",[join $__relation_attributes__ ,]"}]
	#set vals [expr {$relAttributes eq {}?\
	#		    "":",p_[join $__relation_attributes__ ,p_]"}]
	set body [subst {
	  begin
	  v_object_id := $supertypeCall
	  [my getRelationAttributes sql-insert]
	  return v_object_id;
	  end;
	}]
	
	set statement [subst {
	  create or replace function ${m}([join $types_declaration ,]) 
	  returns integer as '
	  $declare
	  $body
	  ' language 'plpgsql';
	}]
	my debug CONSTRUCTOR=$statement
	db_dml [my qn create_constructor] $statement
	
	# / / / / / / / / / / / / / / / / / / / /
	# register with acs_function_args
	# if there is a postgresql backend
	
	if {[db_driverkey ""] eq "postgresql"} {
	  set functionArgs [join [my getRelationAttributes storedArgs] ,]
	  db_exec_plsql [my qn register_function_args] {
	    select define_function_args(:m,:functionArgs);
	  }
	}
	
      }
      
      # / / / / / / / / / / / / / / / / / / / /
      # register the constructor as a package
      # - tcl namespace + object type as package
      # - only needed if we use postgresql
      # both, for newly created once and those
      # that are already existing ...
      set pkg ::xo::db::sql::$dbPackage
      if {![my isobject $pkg]} { ::xo::db::Class create $pkg -noinit }
      if {[$pkg info methods $dbConstructor] eq {}} {
	$pkg dbproc_nonposargs $dbConstructor
      }
    }
  }

  AcsObjectType instproc acquireTable {} {
    my instvar table_name id_column supertype abstract_p
    if {!$abstract_p && $table_name ne {} && $id_column ne {}} {
      # resolve supertype table
      if {[my isobject $supertype] && [$supertype istype [self class]]} {
	set supertable [$supertype table_name]
	my debug supertype=[$supertype serialize],supertable1=$supertable
      } else {
	# resolve it from the db
	set supertable [db_string [my qn get_supertable] {
	  select table_name
	  from   acs_object_types
	  where  object_type = :supertype
	}]
	my debug supertable2=$supertable
      }
      # TODO: Oracle manko ...
      ::xo::db::require table $table_name [subst {
	$id_column integer 
	constraint ${table_name}_pk primary key
	constraint ${table_name}_fk references $supertable on delete cascade
      }]
    }
  }
  
  AcsObjectType instproc load {obj} {
    if {[my isobject $obj]} {
      $obj instvar object_id
      array set attrs [concat \
			   [list acs_objects.object_id acs_objects.object_id] \
			   [my getRelationAttributes sql-load]]
      set tabidcol [array names attrs]
      my debug tabidcol=$tabidcol
      my debug atts=[array get attrs]
      array set tables []
      set cols $attrs([lindex $tabidcol end])
      foreach x [lrange $tabidcol 0 end-1] y [lrange $tabidcol 1 end] {
	lappend joins "$x = $y"
	set tables([lindex [split $x .] 0]) 1
	set tables([lindex [split $y .] 0]) 1
	set cols [concat $cols $attrs($x)]
      }
      #$obj db_1row [my qn populate_object]
      my debug SQL=[subst {
	select [join $cols ","]
	from [join [array names tables] ","]
	where [join $joins " and "]
	and acs_objects.object_id = $object_id 
      }]
    }
  }

  AcsObjectType insproc unload {obj} {
    # to be filled
  }
  
  AcsObjectType instproc instantiate {
    -object_id:required
    -absolute:switch
  } {
    if {$absolute} {
      if {![my exists ::$object_id]} {
	my create ::$object_id
      } 
      set obj ::$object_id
    } else {
      set obj [my new]
    }
    $obj object_id $object_id
    my load $obj
    return 
  }

  AcsObjectType instproc canonise {in} {
    set in [string tolower $in]
    set in [string map {:: _} $in]
    set in [string trimleft $in _]
    return $in
  }
  AcsObjectType instproc init {} {
    my instvar object_type attributes supertype abstract_p

    # / / / / / / / / / / / / / / / /
    # Note that only single inheritance
    # is allowed for object types !!!
    # However, we somehow align XOTcl's
    # multiple inheritance and ACS's single
    # one by introducing the following
    # heuristic: In case of multiple super
    # classes, only the first one in the list
    # is considered as AcsObjectType
    my set __requireRefresh__ 0
    set sc [lindex [my info superclass] 0]
    if {$supertype eq "acs_object" && \
	    $sc ne "::xotcl::Object" && \
	    [$sc istype ::xorb::aux::AcsObjectType]} {
      set supertype $sc
    }

    if {$supertype eq "acs_object"} {
      set supertype ::xorb::aux::AcsObject
    }
    
    if {![my existsObjectType]} {
      my createObjectType
    }
    # set slots after object_type
    # has been intialised
    # will be updated incrementally
    my slots $attributes
    
    # / / / / / / / / / / / / / / /
    # demand a constructor function
    if {!$abstract_p} {
      my acquireConstructor
    }
    # / / / / / / / / / / / / / / /
    # resolve treesort key
    my getTreesortKey
    next
  }

  AcsObjectType instproc getTreesortKey {} {
    my instvar treesortKey object_type
    set treesortKey [db_string [my qn tree_sortkey] {
        select tree_sortkey from acs_object_types
        where object_type = :object_type
      }]

  }

  # / / / / / / / / / / / / / / / /
  # Some querying facilities:
  # 1-) resolve type tree
  # 2-) select all instances of
  # a given type and its subtypes
  # ...

  AcsObjectType instproc query {
    -subtypes:switch 
    {-selectClauses {}}
    {-whereClauses {}}
    {-from {}}
    what 
  } {
    my instvar object_type table_name id_column abstract_p \
	__relation_attributes__ treesortKey
    switch -- $what {
      allInstances {
	if {!$abstract_p} {
	  if {$subtypes} {
	    set typeClause "in ([my query allSubTypes])"
	  } else {
	    set typeClause "= '$object_type'"
	  }
	  set attrs [array names __relation_attributes__]
	  return [subst {
	    select $table_name.[join $attrs ",$table_name."]
	    [expr {$selectClauses ne {}?",[join $selectClauses ,]":""}]
	    from acs_objects,$table_name 
	    [expr {$from ne {}?",[join $from ,]":""}]
	    where acs_objects.object_type $typeClause
	    and acs_objects.object_id = $table_name.$id_column
	    [expr {$whereClauses ne {}?"and [join $whereClauses and]":""}]
	  }]
	}
      }
      allSubTypes {
	return [subst {
	  select object_type 
	  from acs_object_types 
	  where tree_sortkey between '$treesortKey' 
	  and tree_right('$treesortKey')}]
      }
      default break
    }

  }
  

  # / / / / / / / / / / / / / / / /
  # Inspired by DbAttribute, again
  # credits to Gustaf Neumann
  # Only amended in so far as attributes
  # are reflected into the attributes
  # in the attribute table of the object
  # type in a dynamic manner.
  # / / / / / / / / / / / / / / / /
  # There is one major issue with 
  # ::xotcl::Attribute and subclasses thereof:
  # In fact, they are serialised (by the xotcl
  # Serializer without the -noinit flag
  # as the Domain/Slot initialisation is more
  # or less handled in the init call on the
  # Attribute object. This, however, requires
  # special caution when using attributes
  # to aggregate state on the domain object,
  # e.g. setting variables or similar, especially
  # in the context of the blueprint mechanism
  # in aolserver. This aggregated states are
  # then introduced dupes etc. (if not taken
  # care of).
  # This is relevant for ::xorb::AcsAttribute 
  # and ::xorb::datatypes::AnyAttribute (and
  # similar).

  ::xotcl::Class AcsAttribute -superclass ::xotcl::Attribute -slots {
    Attribute pretty_name 
    Attribute datatype -default "text"
    Attribute sqltype -default "text"
    Attribute min_n_values -default 1 
    Attribute max_n_values -default 1
    Attribute dbDefault
  }

  AcsAttribute instproc qname {value} {
    # check for reserved namespaces used in name proposition
    if {[regexp {^::(xotcl|acs)::(.+)$} $value _ ns children]} {
      set type [[my domain] info class]
      error [subst {
	Please, make sure that you use a name for the $type '$value' 
	that does not resolve to the reserved namespace ::${ns}::*.
      }]
    } else {
      return 1
    } 
  }

  AcsAttribute instproc resolve-to-qname {value} {
    # resolve only, if value indicates relative reference
    if {[regexp {^::(xotcl|acs)::(.+)$} $value _ ns children]} {
      set type [[my domain] info class]
      set v [my uplevel [list set var]]
      error [subst {
	Please, make sure that you assign a value for $v 
	that does not resolve to the reserved namespace ::${ns}::*.
	The current value '$value' does!
      }]
    } else {
      set current [namespace qualifiers [my uplevel {set obj}]]
      if {[string first "::" $value] == -1 && \
	      ![regexp {^::(xotcl|acs).*$} $current]} {
	# resolve in domain's or global namespace
	# mimics "namespace which command" relative to the
	# domain object
	# we have to check $current for the reserved namespace
	# prefixes as implements for instance can be assigned
	# before the qname constraint on impl_name and contract_name
	# are actually verified.
	if {[my isobject ${current}::$value] && \
		[${current}::$value istype ::xorb::Object]} {
	  my uplevel [subst {\$obj set \$var ${current}::$value}]
	} elseif {[my isobject ::$value] && \
		      [::$value istype ::xorb::Object]} {
	  my uplevel [subst {\$obj set \$var ::$value}]
	}
      }
      return 1
    }
  }
  
  # TODO: Oracle manko ...
  # TODO: move to xotcl-core db-procs as an amendment
  AcsAttribute set attributeExists {
    select 1 from pg_attribute attrs, pg_class tables 
    where tables.oid = attrs.attrelid 
    and tables.relname = '$table_name' 
    and attrs.attname = '$name'
  }
  AcsAttribute instproc init args {
    next;
    my instvar name datatype pretty_name min_n_values max_n_values \
	sqltype
    [my domain] instvar __requireRefresh__
    set object_type [[my domain] object_type]
    #[my domain] lappend __relation_attributes__ $name
    my debug ---2,ot=$object_type
    if {![db_0or1row [my qn check_att] {
      select 1 from acs_attributes 
      where attribute_name = :name 
      and object_type = :object_type
    }]} {
      #if {![$object_type existsObjectType]} {
      #$object_type createObjectType
      #}
      if {![info exists pretty_name]} {
	set pretty_name $name
      }
      ::xo::db::sql::acs_attribute create_attribute \
          -object_type $object_type \
          -attribute_name $name \
          -datatype $datatype \
          -pretty_name $pretty_name \
          -min_n_values $min_n_values \
          -max_n_values $max_n_values
       my debug ---4
      # materialise attribute also as attribute
      # to the object type specific relation!
      if {[[my domain] lazilyAcquireTable]} {
	[my domain] acquireTable
      }

      [my domain] instvar table_name
      if {![db_0or1row [my qn ""] [subst [[self class] set attributeExists]]]} {
	# TODO: Oracle manko ...
	# Propose as an amendment to the xotcl-db core ..
	db_dml [my qn add_attribute] [subst {
	  alter table $table_name add $name $sqltype
	}]
	# - - - 
	# It also requires a re-acquisition of the
	# constructor plpgsql procedure, therefore
	# we provide for a call sequence of release 
	# and acquire
	# - - -
	[my domain] releaseConstructor
	set __requireRefresh__ 1
      }
    }
    
    [my domain] setRelationAttributes $name
    my debug CALLED-FROM=[self callingproc]
    my debug RELATTRS([llength [[my domain] array get __relation_attributes__]],[[my domain] array get __relation_attributes__])
    #if {$requireRefresh} {
    #	[my domain] acquireConstructor
    # }
  }


  # / / / / / / / / / / / / / / / / / /
  # AcsObject ...
  
  AcsObjectType AcsObject -attributes {
    ::xorb::aux::AcsAttribute object_id \
	-datatype integer \
	-sqltype integer
  } -table_name acs_objects -id_column object_id \
      -pretty_name Object -pretty_plural Objects \
      -object_type acs_object

  AcsObject instproc init args {next}

  AcsObject instproc delete {} {
    my instvar object_id
    if {[info exists object_id]} {
      ::xo::db::sql::acs_object delete -object_id $object_id
    }
  }

  # AcsObject instproc save {} {
#     if {[[my info class] istype ::xorb::aux::AcsObjectType]} {
#       my instvar object_id
#       [my info class] instvar dbPackage dbConstructor
#       set attrs [[my info class] getRelationAttributes] 
#       foreach a $attrs {
# 	if {[my exists $a]} {
# 	  lappend arguments [list -$a [my $a]]
# 	}
#       }
#       set object_id [eval ::xo::db::sql::$dbPackage \
# 			 $dbConstructor [join $arguments]]
#     }
#   }

  AcsObject instproc save {} {
    my instvar object_id
    set t [my getType]
    my debug TYPE=$t
    if {$t ne {}} {
      $t instvar dbPackage dbConstructor
      set attrs [$t getRelationAttributes] 
      foreach a $attrs {
	if {[my exists $a]} {
	  lappend arguments [list -$a [my $a]]
	}
      }
      set object_id [eval ::xo::db::sql::$dbPackage \
			 $dbConstructor [join $arguments]]
    }
  }

  AcsObject instproc getType {} {
    set heritors [concat [my info class] [[my info class] info heritage]] 
    set found 0
    foreach h $heritors {
      if {[$h istype ::xorb::aux::AcsObjectType]} {set found 1; break;}
    }
    if {$found} {
      return $h
    }
  }
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # 
  # Helper method to resolve
  # complete subclass tree
  # # # # # # # # # # # # # # 
  # # # # # # # # # # # # # # 

  ::Serializer exportMethods {
    ::xotcl::Class instproc getAllSubClasses
  }
  
  ::xotcl::Class instproc getAllSubClasses {} {
    set result ""
    set sc [my info subclass]
    foreach c $sc {
      lappend result $c
      set result [concat $result [$c getAllSubClasses]]
    }
    return $result 
  }
  
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  

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
    #my debug "children?[my exists __children]"
    #my debug "ser=[my serialize]"
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
    #my debug "---CONTAINS-CALLED:[my info class]"
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
    #my debug "---OUTER-CONTAINS([self callingobject]):[my info class]"
    if {![my istype ::xotcl::ScopedNew]} {
      #my debug "---INNER-CONTAINS([self callingobject]):[my info class]"
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
      TypedOrderedComposite AggregationClass AcsObjectType AcsAttribute \
      AcsObject
  
}