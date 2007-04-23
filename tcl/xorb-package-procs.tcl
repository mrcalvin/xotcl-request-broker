ad_library {}

namespace eval ::xorb {
  
  ::xotcl::Class PackageManager -superclass ::xotcl::Class
  PackageManager instproc initialise {
    -package_id:required
    {-node_id {}}
    {-package_url {}}
  } {
    if {![my isobject ::$package_id]} {
      my create ::$package_id
    }
    if {$node_id eq {}} {
      set node_id [site_node::get_node_id_from_object_id \
		       -object_id $package_id]
    }
    if {$package_url eq {}} {
      set package_url [apm_package_url_from_id $package_id]
    }
    ::$package_id configure \
	-node $node_id \
	-baseUrl $package_url

    ::$package_id setup
  }

  PackageManager ProtocolPackage -slots {
    Attribute node
    Attribute baseUrl
  }
  ProtocolPackage instproc setup {} {
    next
  }
  ProtocolPackage instproc remove {} {
    next
  }

  namespace export ProtocolPackage PackageManager
}