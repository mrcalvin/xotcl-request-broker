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
    }
   #  if {![my isobject ::$package_id]} {
#       my create ::$package_id
#     }
#     if {$node_id eq {}} {
#       set node_id [site_node::get_node_id_from_object_id \
# 		       -object_id $package_id]
#     }
#     if {$package_url eq {}} {
#       set package_url [apm_package_url_from_id $package_id]
#     }
#     ::$package_id configure \
# 	-node $node_id \
# 	-baseUrl $package_url

#     ::$package_id setup
  }
  ::xotcl::Class ProtocolPackage -slots {
    Attribute node
    Attribute baseUrl
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

  namespace export ProtocolPackage PackageMgr
}