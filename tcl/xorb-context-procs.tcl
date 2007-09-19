ad_library {
  
  Providing for (remoting) invocation contexts, based upon 
  the xotcl-core's context framework.

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date 2007-01-25
  @cvs-id $Id$
}

namespace eval ::xorb::context {
  namespace import -force ::xoexception::try

  # # # # # # # # # # # # # #
  # # # # # # # # # # # # # #
  # # Generic extensions
  # # to ConnectionContext
  # # as it comes with 
  # # xotcl-core
  # # # # # # # # # # # # # #
  # # # # # # # # # # # # # #
  
  ::xo::ConnectionContext slots {
    Attribute httpMethod -default GET
  }

  ::xo::ConnectionContext instproc isGet {} {
    my instvar httpMethod
    return [expr {$httpMethod eq "GET"}]
  }

  ::xo::ConnectionContext instproc isPost {} {
    my instvar httpMethod
    return [expr {$httpMethod eq "POST"}]
  }

#   # # # # # # # # # # # # # #
#   # # # # # # # # # # # # # #
#   # # Meta-Class ContextClass
#   # # # # # # # # # # # # # #
#   # # # # # # # # # # # # # #
#   ::xotcl::Class ContextClass -superclass ::xotcl::Class
#   ContextClass instproc require {
# 	-url
# 	{-package_id 0} 
# 	{-parameter ""}
# 	{-user_id 0}
# 	{-actual_query " "}
#       } {
    
#     try {
#       if {![info exists url]} {
# 	set url [ns_conn url]
#       }
      
#       # create connection context if necessary
#       if {$package_id == 0} {
# 	array set "" [site_node::get_from_url -url $url]
# 	set package_id $(package_id)
#       } 
      
#       if {![my isobject ::xo::cc]} {
# 	my create ::xo::cc \
# 	    -package_id $package_id \
# 	    -parameter_declaration $parameter \
# 	    -user_id $user_id \
# 	    -actual_query $actual_query \
# 	    -url $url
# 	::xo::cc destroy_on_cleanup 
#       } else {
# 	#my log ::XO::CC=CONFIGURED
# 	::xo::cc configure \
# 	    -package_id $package_id \
# 	    -url $url \
# 	    -actual_query $actual_query \
# 	    -parameter_declaration $parameter
# 	::xo::cc set_user_id $user_id
# 	::xo::cc process_query_parameter
#       }
#     } catch {error e} {
#       error [::xosoap::exceptions::Server::ContextInitException new $e]
#     }
#   }

  ::xotcl::Class InvocationContext -parameter {
    virtualObject
    virtualCall
    virtualArgs
    marshalledRequest
    marshalledResponse
    unmarshalledRequest
    unmarshalledResponse
    {protocol ::xorb::AcsSc}
    package
  }

  InvocationContext instproc setData {key value} {
    my set data($key) $value
  }

  InvocationContext instproc getData {key} {
    my instvar data
    if {[info exists data($key)]} {
      return $data($key)
    }
  }

  InvocationContext instproc dataExists {key} {
    my instvar data
    return [info exists data($key)]
  }
 
  InvocationContext instproc getProtocolTree {} {
    my instvar protocol

    set p [string toupper $protocol 0 0]
    if {[$p istype ::xorb::protocols::PluginClass]} {
      set l [$p prettyName]
      foreach h [$p info heritage] {
	lappend l [$h prettyName]
      }
      return $l
    }
  }

  ::xotcl::Class RemotingInvocationContext -parameter {
    method
    {transport {}}
  } -superclass InvocationContext

  namespace export ContextClass InvocationContext RemotingInvocationContext 
}