ad_library {

  xorb infrastructure for protocol plug-ins
  
  @author stefan.sobernig@wu-wien.ac.at	
  @creation-date March 7, 2007			
  @cvs-id $Id: xorb-procs.tcl 17 2006-09-26 14:34:40Z ssoberni $

}

namespace eval ::xorb::protocols {

  ::xotcl::Class PluginClass -superclass ::xotcl::Class -slots {
    Attribute prettyName
  }
  PluginClass instproc init args {
    if {![my exists prettyName]} {
      my prettyName [string tolower [namespace tail [self]] 0 0]
    }
    my instvar prettyName
    [self class] set registry($prettyName) [self]
    next
  }
  PluginClass proc getClass {-uri:switch protocolKey} {
    my instvar registry
    if {$uri} {
      set pKeys [join [[self] getKeys] "|"]
      set rExpr [subst {^($pKeys)://\[^ \].+}]
      if {[regexp -nocase $rExpr [string trim $bind]]} {
	set protocolKey [lindex [split $protocolKey "://"] 0]
      }
    } else {
      set protocolKey tcl
    }
    set protocolKey [string tolower $protocolKey 0 0]
    if {[info exists registry($protocolKey)]} {
      return $registry($protocolKey)
    } 
  }
  PluginClass proc getKeys {} {
    my instvar registry
    if {[array exists registry]} {
      return [array names registry]
    }
  }
  PluginClass instproc plug {-listener:required} {
    ::xorb::rhandler mixin add [self]
    ::xorb::rhandler listener $listener
  }
  PluginClass instproc unplug {} {
    if {[::xorb::rhandler info mixin [self]] ne {}} {
      ::xorb::rhandler mixin delete [self]
    }
  }

  PluginClass instproc registerInterceptors {interceptors} {
    set cmds {}
    foreach i $interceptors {
      append cmds [subst {
	::xorb::Configuration::Element new \
	    -interceptor $i \
	    -array set properties {
	      position 0
	      protocol [string tolower [namespace tail [self]] 0 0]
	      listen all
      }}] 
    }
    if {$cmds ne {}} {
      ::xorb::Standard contains $cmds
    }
  }
  
  PluginClass Plugin -parameter {
    listener
  } -prettyName "all"
  
  PluginClass RemotingPlugin -superclass Plugin -prettyName "remote"
  PluginClass LocalPlugin -superclass Plugin -prettyName "local"

  # # # # # # # # # # # # # 
  # # # # # # # # # # # # # 
  # # Tcl Protocol-Plugin
  # # # # # # # # # # # # # 
  # # # # # # # # # # # # # 
  
  PluginClass Tcl -superclass LocalPlugin

  Tcl instproc handleRequest {requestObj} {
    array set call $requestObj
    # # # # # # # # # # # #
    # populate call context
    ::xo::cc virtualObject [expr {$call(impl_id) ne {}?\
				      $call(impl_id):$call(impl)}]
    ::xo::cc virtualCall $call(operation)
    ::xo::cc virtualArgs $call(call_args)

    next;#::xorb::RequestHandler->handleRequest
  }

  Tcl instproc handleResponse {requestObj responseObj} {
    set r [next];#::xorb::RequestHandler->handleResponse
    [my listener] dispatchResponse $r
  }

  # / / / / / / / / / / / /
  # interceptors?


  namespace export PluginClass Plugin RemotingPlugin LocalPlugin Tcl
}
