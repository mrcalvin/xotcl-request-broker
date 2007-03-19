ad_library {
  
  Providing for (remoting) invocation contexts, based upon 
  the xotcl-core's context framework.

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date 2007-01-25
  @cvs-id $Id: context-procs.tcl,v 1.7 2007/01/07 21:33:55 gustafn Exp $
}

namespace eval ::xorb::context {
  namespace import -force ::xoexception::try

  # # # # # # # # # # # # # #
  # # # # # # # # # # # # # #
  # # Meta-Class ContextClass
  # # # # # # # # # # # # # #
  # # # # # # # # # # # # # #
  ::xotcl::Class ContextClass -superclass ::xotcl::Class
  ContextClass instproc require {
	-url
	{-package_id 0} 
	{-parameter ""}
	{-user_id 0}
	{-actual_query " "}
      } {
    
    try {
      if {![info exists url]} {
	set url [ns_conn url]
      }
      
      # create connection context if necessary
      if {$package_id == 0} {
	array set "" [site_node::get_from_url -url $url]
	set package_id $(package_id)
      } 
      
      if {![my isobject ::xo::cc]} {
	my create ::xo::cc \
	    -package_id $package_id \
	    -parameter_declaration $parameter \
	    -user_id $user_id \
	    -actual_query $actual_query \
	    -url $url
	::xo::cc destroy_on_cleanup 
      } else {
	::xo::cc configure \
	    -package_id $package_id \
	    -url $url \
	    -actual_query $actual_query \
	    -parameter_declaration $parameter
	::xo::cc set_user_id $user_id
	::xo::cc process_query_parameter
      }
    } catch {error e} {
      error [::xosoap::exceptions::Server::ContextInitException new $e]
    }
  }

  ContextClass InvocationContext -parameter {
    virtualObject
    {virtualCall {}}
    {virtualArgs {}}
    {protocol {local}}
  } -superclass ::xo::ConnectionContext
  InvocationContext instproc getProtocolTree {} {
    my instvar protocol
    set p [string toupper 0 0 $protocol]
    if {[$p istype ::xorb::protocols::PluginClass]} {
      set l [list]
      foreach h [$p info heritage] {
	lappend l [$h prettyName]
      }
      return $l
    }
  }

  ContextClass RemotingInvocationContext -parameter {
    method
    {marshalledRequest ""}
    {marshalledResponse ""}
    {unmarshalledRequest ""}
    {unmarshalledResponse ""}
    {protocol {}}
    {transport {}}
  } -superclass InvocationContext

  namespace export ContextClass InvocationContext RemotingInvocationContext 
}