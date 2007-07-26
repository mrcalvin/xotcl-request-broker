::xorb::Package initialize -ad_doc {

  Basic admin WUI for xorb

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date July 23, 2007
  @cvs-id $Id$
  
} -parameter {
  {-orderby:optional "name"}
  {-direction:optional "increasing"}
  {-view_type "::xorb::ServiceContract"}
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

TableWidget XorbCockpit -volatile \
    -actions {} \
    -columns {
      AnchorField name -label Name -orderby name
      AnchorField description -label Description -orderby description
      ImageField_DeleteIcon delete \
	  -label "" \
	  -condition 1
    }

set inItems [::xorb::ServiceContract query allSubTypes]
lappend innerSelect [subst {
  (select 1 from acs_objects 
   where acs_objects.object_type in ($inItems) 
   and acs_objects.object_id = acs_sc_contracts.contract_id) 
  as is_xorb_object,acs_objects.object_id,acs_objects.object_type}]

db_foreach [XorbCockpit qn get_all_instances] \
    [::xorb::AcsScContract query \
	 -subtypes \
	 -selectClauses $innerSelect "allInstances"] {
	   ns_log notice is=$is_xorb_object
	   XorbCockpit add \
	       -name $contract_name \
	       -description $contract_desc \
	       -delete.href [export_vars \
				 -base [::$package_id package_url]admin/delete {
				   {object_id $object_id} 
				   {type $object_type}
				   {name $contract_name}
				 }] \
	       -delete.condition [expr {$is_xorb_object == 1?1:0}]
	 }
XorbCockpit orderby -order $direction $orderby

# / / / / / / / / / / / / /
# realising top-level tabs
set header_stuff {<link rel="stylesheet" href="/resources/xotcl-request-broker/xorb.css" type="text/css" media="all">}
set tabs [list ::xorb::ServiceContract ::xorb::ServiceImplementation]
foreach t $tabs {
  set id {}
  if {$view_type eq $t} {set id "-id selected"}
  append items "::html::li $id {::html::a -href [$package_id package_url]admin/?view_type=[ad_urlencode $t] {::html::t $t}}\n"
}
::require_html_procs
dom createDocument ul doc
set root [$doc documentElement]
$root appendFromScript $items
#$root setAttribute id xorbtabs
set l [$root asHTML]
set content "<div id=\"xorbtabs\">$l<br style=\"clear:both;\"/></div><div id=\"xorbcontent\">[XorbCockpit asHTML]</div>"
