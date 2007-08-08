::xorb::Package initialize -ad_doc {

  Basic admin WUI for xorb

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date July 23, 2007
  @cvs-id $Id$
  
} -parameter {
  {-orderby:optional "name"}
  {-direction:optional "increasing"}
  {-view_type "::xorb::AcsScContract"}
}

# / / / / / / / / / / / / / / /
# TODOs:
# Oracle compatibility
# 1) COALESCE -> NLV


# / / / / / / / / / / / / / / /
# generic extensions,
# should go in a procs file
# at some point in time

::xotcl::Class ConditionalField -slots {
  Attribute condition -default 1
}
ConditionalField instproc render-data {line} {
  if {[my check [$line set [my name].condition]]} {
    next
  }
}
ConditionalField instforward check -objscope ::expr
ConditionalField instproc get-slots {} {
  return [concat [next] -[my name].condition ""]
}

#::xo::Table::ImageField_DeleteIcon instmixin add ::template::ConditionalField

# / / / / / / / / / / / / / / /
# branching up between
# contracts and implementation
# views

# 1-) shared commons

append colset "AnchorField name -label Name -orderby name\n"
append colset "ImageField_ViewIcon view -label {}\n"
append colset "ImageField_DeleteIcon delete -mixin ::template::ConditionalField -label {} -condition 1\n"

# - - provide the return url
set return [export_vars \
		-base [::$package_id package_url]admin {view_type $view_type}]
set base [::$package_id package_url]admin

# 2-) branching up

switch -- $view_type {
  ::xorb::AcsScContract {
    set inItems [::xorb::ServiceContract query allSubTypes]
    set tname [$view_type table_name]
    set id_column [$view_type id_column]
    
    # / / / / / / / / / / / / / / /
    # The inner select provides for the
    # following aggregated columns:
    # - is_xorb_object: 0 | 1
    lappend innerSelect [subst {
      (COALESCE((select 1 from acs_objects
		 where acs_objects.object_type in ($inItems) 
		 and acs_objects.object_id = $tname.$id_column),0)) 
      as is_xorb_object,
      acs_objects.object_id,
      acs_objects.object_type}]
    
    set nameHref {[export_vars \
		       -base $base/contract-badge {
			 {id \$object_id}
		       }]}
    
    # assignments
    set assignments [subst -nocommands {
      XorbCockpit add \
	  -name \$contract_name \
	  -name.href $nameHref \
	  -delete.href [export_vars \
			    -base $base/delete {
			      {object_id \$object_id} 
			      {type \$object_type}
			      {name \$contract_name}
			      {return_url $return}
			    }] \
	  -delete.condition \$is_xorb_object \
	  -view.href $nameHref
    }]
  }
  ::xorb::AcsScImplementation {
    set colset "ImageField status -label {} -src /resources/xotcl-request-broker/state-0.png -height 16 -border 0\n$colset"
    append colset "ImageAnchorField change  -mixin ::template::ConditionalField -label {} -src /resources/xotcl-request-broker/operation-0.png -height 16 -border 0\n"
    set inItems [::xorb::ServiceImplementation query allSubTypes]
    set tname [$view_type table_name]
    set id_column [$view_type id_column]
    # / / / / / / / / / / / / / / /
    # The inner select provides for the
    # following aggregated columns:
    # - is_xorb_object: 0 | 1
    # - status: 	0 > orphan implementation
    #			2 > not bound to (existing) contract
    #			3 > bound to contract
    array set states {
      0,info	orphaned
      2,info	unregistered
      3,info	registered
      0,op	""
      2,op	register
      3,op	unregister
    }
    lappend innerSelect [subst {
      (COALESCE((select 1 from acs_objects
       where acs_objects.object_type in ($inItems) 
       and acs_objects.object_id = $tname.$id_column),0)) as is_xorb_object,
      acs_objects.object_id,
      acs_objects.object_type,
      (COALESCE((select 1 from acs_sc_impls
		 impls,acs_sc_bindings binds 
		 where impls.impl_id = binds.impl_id and
		 impls.impl_id = acs_objects.object_id),0)) + 
      (COALESCE((select 2 from acs_sc_contracts ctrs, acs_sc_impls impls 
		 where ctrs.contract_name = impls.impl_contract_name 
		 and impls.impl_id = acs_objects.object_id),0)) 
      as status,
      (select acs_sc_contracts.contract_id from acs_sc_contracts
       where acs_sc_contracts.contract_name = acs_sc_impls.impl_contract_name 
       and acs_sc_impls.impl_id = acs_objects.object_id)
      as contract_id
    }]
    
    # handle assignments to tablewidget
    set nameHref {[export_vars \
		       -base $base/impl-badge {
			 {id $contract_id}
			 {impl_name $impl_name}
		       }]}
    
    set assignments [subst -nocommands {
      #set base /acs-service-contract/binding-\$states(\$status,op)
      XorbCockpit add \
	  -name \$impl_name \
	  -name.href $nameHref \
	  -delete.href [export_vars \
			    -base $base/delete {
			      {object_id \$object_id} 
			      {type \$object_type}
			      {name \$impl_name}
			      {return_url $return}
			    }] \
	  -delete.condition \$is_xorb_object \
	  -view.href $nameHref \
	  -status.src /request-broker/resources/state-\$status-\$is_xorb_object.png \
	  -status.alt \$states(\$status,info) \
	  -status.title \$states(\$status,info) \
	  -change.condition [expr {\$status != 0}] \
	  -change.src /request-broker/resources/operation-\$status.png \
	  -change.title \$states(\$status,op) \
	  -change.href [export_vars \
			    -base \$base/\$states(\$status,op) {
			      {impl_name \$impl_name}
			      {contract_name \$impl_contract_name}
			      {return_url \$return}
			    }]
    }]
  }
}

TableWidget XorbCockpit -volatile \
    -actions {} \
    -columns $colset

db_foreach [XorbCockpit qn get_all_instances] \
    [$view_type query \
	 -subtypes \
	 -selectClauses $innerSelect "allInstances"] \
    $assignments

XorbCockpit orderby -order $direction $orderby

# / / / / / / / / / / / / /
# realising top-level tabs
set header_stuff {<link rel="stylesheet" href="/resources/xotcl-request-broker/xorb.css" type="text/css" media="all">}
set tabs [list ::xorb::AcsScContract ::xorb::AcsScImplementation]
foreach t $tabs {
  set id {}
  if {$view_type eq $t} {set id "-id selected"}
  append items [subst {
    ::html::li $id {
      ::html::a -href \
	  [$package_id package_url]admin/?view_type=[ad_urlencode $t] {
	    ::html::t {[$t pretty_plural]}
	  }
    }
  }]
}
::require_html_procs
dom createDocument ul doc
set root [$doc documentElement]
$root appendFromScript $items
#$root setAttribute id xorbtabs
set l [$root asHTML]
set content "<div id=\"xorbtabs\">$l<br style=\"clear:both;\"/></div><div id=\"xorbcontent\">[XorbCockpit asHTML]</div>"
