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

  proc after-upgrade {
    {-from_version_name:required}
    {-to_version_name:required}
  } { ; }
}