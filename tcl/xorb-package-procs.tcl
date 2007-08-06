ad_library {

  Package facility for xorb and protocol plug-ins
  
  @author stefan.sobernig@wu-wien.ac.at
  @cvs-id $Id$

}

namespace eval ::xorb {

  # / / / / / / / / / / / / /
  # A package class for the
  # request broker itself

  ::xo::PackageMgr Package -superclass ::xo::Package
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
  ::xotcl::Class ProtocolPackage -slots {
    Attribute node
    Attribute baseUrl
    Attribute protocol
    Attribute listener
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
      error [PackageException new [subst {
	Your solicit for '[my info class]->$what' cannot be handled.
      }]]
    }
  }
  
  ProtocolPackage instproc solicit=invocation {context} {
    my instvar listener protocol
    $protocol plug -listener $listener
    ::xorb::rhandler handleRequest $context
    $protocol unplug
  }


  namespace export ProtocolPackage PackageMgr
}