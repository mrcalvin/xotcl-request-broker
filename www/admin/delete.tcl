::xorb::Package initialize -ad_doc {

  Admin facility for deleting xorb items

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date July 23, 2007
  @cvs-id $Id$
  
} -parameter {
  -name
  -type
  -object_id:optional
  {-return_url:optional "."}
}

# 1-) name resolves to existing specification object
if {[::xotcl::Object isobject $name] && [$name istype ::xorb::Object]} {
  set obj $name
  ns_log debug obj=$obj
} else {
  # 2-) not given, resolve it from broker
  set flag [expr {$type eq "::xorb::ServiceContract"?"contract":"impl"}]
  array set stream [eval XorbManager do \
			::xorb::manager::Broker stream \
			-what [namespace tail $type] \
			-$flag $name]
  ns_log debug stream=[array get stream]  
  if {[info exists stream($flag)]} {
    set host [::xotcl::Object new -volatile]
    $host requireNamespace;
    $host eval $stream($flag)
    set obj ${host}::[::xorb::Object canonicalName $name]
    ns_log debug obj(isobj?[::xotcl::Object isobject $obj])=$obj
  }
}

if {[permission::permission_p \
    -party_id [::xo::cc user_id] -object_id $package_id \
    -privilege "write"] && \
	[info exists obj] && \
	[::xotcl::Object isobject $obj]} {
  $obj mixin add ::xorb::Synchronizable
  $obj sync -delete
  $obj mixin delete ::xorb::Synchronizable
}

ad_returnredirect $return_url
