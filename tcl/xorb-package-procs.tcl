ad_library {

  Package facility for xorb and protocol plug-ins
  
  @author stefan.sobernig@wu-wien.ac.at
  @cvs-id $Id$

}

namespace eval ::xorb {

  # / / / / / / / / / / / / /
  # A package class for the
  # request broker itself

  ::xo::PackageMgr Package \
      -superclass ::xo::Package \
      -pretty_name "XORB Package" \
      -package_key "xotcl-request-broker"

  Package proc require {-url {package_id -1}} {
    # / / / / / / / / / / / /
    # -1 indicates a dependent
    # require call, for instance,
    # from within a plugin 
    # protocol package context
    # in such a case, resolve
    # the package_id from
    # singleton instance:
    if {$package_id == -1} {
      set frag [site_node::get_package_url \
		    -package_key xotcl-request-broker]
      array set n [site_node::get_from_url -url $frag]
      set package_id $n(package_id)
    }
    next $package_id;# ::xo::PackageMgr->require
    return ::$package_id
  }
  # ---
  ::xotcl::Class PackageMgr -superclass ::xo::PackageMgr
  PackageMgr instproc initialize args {
    my debug INIT=[info command ::ns_conn]
    if {[info command ::ns_conn] eq {} || ![::ns_conn isconnected]} {
      # we are in a non-connection scope,
      # ns_conn was not initialised in
      # the current interpreter
      # we, therefore, provide for an
      # alternative initialisation
      foreach {name value} $args {
	switch -- $name {
	  -package_id { set package_id $value}
	  default break
	}
      }
      if {[info exists package_id]} {
	my require $package_id
      } else {
	error {If ::xorb::PackageMgr->initialize is called in the context
	  of a non-connection thread, at least a dedicated package_id has to
	  be provided.
	}
      }
    } else {
      next
      #::xo::show_stack
      ::xo::cc export_vars -level 2
    }
  }
  # / / / / / / / / / / / / / 
  # Class common to protocol
  # packages ...

  ::xotcl::Class ProtocolPackage -slots {
    Attribute node
    Attribute baseUrl
    Attribute protocol
    Attribute listener
    Attribute xorb
    Attribute policy
  } -superclass ::xo::Package
  ProtocolPackage instproc init args {
    my instvar node
    if {![info exists node] || $node eq {}} {
      set node [site_node::get_node_id_from_object_id \
		       -object_id [namespace tail [self]]]
    }
    next
  }
  ProtocolPackage instproc onMount {} {
    next
  }
  ProtocolPackage instproc onUnmount {} {
    next
  }
  ProtocolPackage instproc getPolicy {} {
    return [my get_parameter \
		invocation_access_policy \
		::xorb::deployment::Default]
  }
  ProtocolPackage instproc requireXorb {} {
    my instvar xorb
    # / / / / / / / / / /
    # initialize package
    # object for request
    # broker and provide
    # reference to plugin
    # package attribute
    set xorb [::xorb::Package require]
    
  }
  ProtocolPackage ad_instproc get_parameter {
    attribute 
    {default ""}
  } {
    We resolve configuration parameters in the following
    order of precedence:
    -1- parameters specific to the protocol plug-in
    -2- parameters specific to the request broker
    (and, therefore, all plugin packages)
  } {
    my requireXorb
    my instvar xorb
    set value [next $attribute]
    my debug "PARAM1 => value=$value,xorb?[info exists xorb]"
    if {$value eq {} && [info exists xorb]} {
      set value [$xorb get_parameter $attribute $default]
      my debug XORB-VALUE=$value
    }
    return $value
  }
  ProtocolPackage instforward check_permissions {%my getPolicy} %proc
  # / / / / / / / / / / / / / / / /
  # cross-protocol commons

  ProtocolPackage instproc getPackagePath {} {
    set package_id [namespace tail [self]]
    set key [apm_package_key_from_id $package_id]
    return [acs_package_root_dir $key]
  }
  
  ProtocolPackage instproc solicit {what} {
    if {[my procsearch solicit=$what] ne {}} {
      my solicit=$what
    } else {
      error [::xorb::exceptions::PackageException new [subst {
	Your solicit for '[my info class]->$what' cannot be handled.
      }]]
    }
  }
  
  ProtocolPackage instproc acquireInvocationContext {} {
    my instvar protocol
    set ctxClass [$protocol contextClass]
    return [$ctxClass new \
		-destroy_on_cleanup]
  }

  ProtocolPackage instproc solicit=invocation {context} {
    my instvar listener protocol
    # $protocol plug -listener $listener
    #::xorb::ServerRequestHandler handleRequest $context
    ::xorb::ServerRequestHandler handle $context $listener
    # $protocol unplug
  }

  namespace export ProtocolPackage PackageMgr
}