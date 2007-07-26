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

::xo::Table::ImageField_DeleteIcon instmixin add ::template::ConditionalField

append colset "AnchorField name -label Name -orderby name\n"
if {$view_type eq "::xorb::AcsScContract"} {
  append colset "AnchorField description -label Description -orderby description\n"
}
append colset "ImageField_DeleteIcon delete -label {} -condition 1\n"
#ns_write colset=$colset
TableWidget XorbCockpit -volatile \
    -actions {} \
    -columns $colset

set map(::xorb::AcsScContract,sub) ::xorb::ServiceContract
set map(::xorb::AcsScImplementation,sub) ::xorb::ServiceImplementation
set map(::xorb::AcsScContract,key) contract
set map(::xorb::AcsScImplementation,key) impl

set inItems [$map($view_type,sub) query allSubTypes]
lappend innerSelect [subst {
  (select 1 from acs_objects 
   where acs_objects.object_type in ($inItems) 
   and acs_objects.object_id = [$view_type table_name].$map($view_type,key)_id) 
  as is_xorb_object,acs_objects.object_id,acs_objects.object_type}]
set k $map($view_type,key)
set return [export_vars -base [::$package_id package_url]admin {view_type $view_type}]
db_foreach [XorbCockpit qn get_all_instances] \
    [$view_type query \
	 -subtypes \
	 -selectClauses $innerSelect "allInstances"] {
	   eval XorbCockpit add \
	       -name \$${k}_name \
	       [expr {$view_type eq "::xorb::AcsScContract"?\
			  [list -description $contract_desc]:""}] \
	       -delete.href [subst -nocommands {[export_vars \
				 -base [::$package_id package_url]admin/delete {
				   {object_id $object_id} 
				   {type $object_type}
				   {name \$${k}_name}
				   {return_url $return}
				 }]}] \
	       -delete.condition [expr {$is_xorb_object == 1?1:0}]
	 }
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
