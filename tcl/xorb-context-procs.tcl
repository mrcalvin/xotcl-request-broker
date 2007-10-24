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

  # / / / / / / / / / / / / / 
  # Class InvocationContext

  ::xotcl::Class InvocationContext -parameter {
    virtualObject
    virtualCall
    virtualArgs
    marshalledRequest
    marshalledResponse
    unmarshalledRequest
    unmarshalledResponse
    {protocol ::xorb::AcsSc}
    {package {[::xorb::Package require]}}
    result
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

  InvocationContext instproc clearData {} {
    my instvar data
    array unset data
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