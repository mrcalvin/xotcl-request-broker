ad_library {
  
  Library specifying xorb-specific package-level callbacks
  
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date June 8, 2007
  @cvs-id $Id$
}

namespace eval ::xorb {

  ::xotcl::Object ConfigurationManager
  ConfigurationManager proc sourceSql {sourceScript} {
    set packageRoot [acs_package_root_dir xotcl-request-broker]
    set dbtype [db_driverkey ""]
    set f $packageRoot/sql/$dbtype/$sourceScript
    if {[file exists $f]} {
      db_source_sql_file $f
    } else {
      my log "Could not source '$f'"
    }
  }
  ConfigurationManager proc deleteMsgTypes types {
    set sql ""
    foreach t $types {
      append sql "delete from acs_sc_msg_types where msg_type_name like '$t';\n"
    }
    if {$sql ne {}} {
      db_dml [my qn cleanup_msg_types] $sql
    }
  }
  ConfigurationManager proc deleteContracts ctrs {
    set sql ""
    foreach c $ctrs {
      append sql "delete from acs_sc_contracts where contract_name like '$c';\n"
    }
    if {$sql ne {}} {
      db_dml [my qn cleanup_contracts] $sql
    }
  }
  ConfigurationManager proc deleteImplementations impls {
    set sql ""
    foreach i $impls {
      append sql "delete from acs_sc_impls where impl_name like '$i';\n"
    }
    if {$sql ne {}} {
      db_dml [my qn cleanup_impls] $sql
    }
  }



  proc before-uninstall {} {
    # / / / / / / / / / / / / / / / / /
    # Starting with v0.4 (r49) remove
    # basic object types:
    ::xorb::ServiceContract dropObjectType
    ::xorb::ServiceImplementation dropObjectType
    
    # / / / / / / / / / / / / / / / / /
    # We don't remove the xorb primitive/
    # composite type wrappers (anythings)
    # as they are all managed/provided
    # by the acs environment.
    # However, xorb introduces the
    # generic object messagetype
    # which needs to be handled here:
    ::xorb::datatypes::Object delete
    ::xorb::datatypes::Void delete
    # / / / / / / / / / / / / / / / /
    # Starting with 0.4, clearing
    # message types from protocol plug-ins
    # TODO: This needs to be handled
    # through proper acs_object_types!!!!
    ConfigurationManager deleteMsgTypes {
      xsVoid
      xsString
      xsBoolean
      xsDecimal
      xsInteger
      xsLong
      xsInt
      xsDouble
      xsFloat
      xsDate
      xsTime
      xsDateTime
      xsBase64Binary
      xsHexBinary
      soapStruct
      soapArray
    }
  }

  proc after-install {} { ; }

  ad_proc after-upgrade {
    -from_version_name
    -to_version_name
  } { 
      if {$from_version_name < 0.3} {
	ns_log warn {
	  Please note that upgrades from versions below 0.3
	  are not supported. Consider a complete re-install!
	}
      return
      }
    if {[apm_version_names_compare $from_version_name "0.3"] == 0 &&
	[apm_version_names_compare $to_version_name "0.4"] > -1} {
      
      # / / / / / / / / / / / / / / / / / / / / /
      # Upgrading from 0.3 to 0.4
      # - - - - - - - - - - - - - - - - - - - - - 
      # There is currently one limitation:
      # contracts and implementations that 
      # were defined by non-explicitly named
      # ::xotcl::Objects (by using new) cannot
      # be identified through the allinstances
      # call below (from within the scope 
      # of the upgrading connection thread as
      # they were never initiated in this very
      # very thread!)
      # This must then be handled manually, 
      # this won't be a problem in 0.4+ thanks
      # to the object types.
      ns_log notice "Upgrading from $from_version_name to $to_version_name"
      set ctrs [list]
      set msgTypes [list]
      foreach sc [::xorb::ServiceContract allinstances] {
	set n [$sc set name]
	lappend ctrs $n
	lappend msgTypes $n.%
      }
      set impls [list]
      foreach si [::xorb::ServiceImplementation allinstances] {
	set n [$si set name]
	lappend impls $n
      }
      ns_log notice "Removing ctrs=$ctrs, msgt=$msgTypes, impls=$impls"
      ConfigurationManager deleteContracts $ctrs
      ConfigurationManager deleteMsgTypes $msgTypes
      ConfigurationManager deleteImplementations $impls
    }
  }
}