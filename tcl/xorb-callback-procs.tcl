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
      db_source_sql_file $path
    } else {
      my log "Could not source '$f'"
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
  }

  proc after-install {} {
    ConfigurationManager sourceSql acs-object-model-function-args.sql
    set current [apm_highest_version_name acs-service-contract]
    if {[apm_version_names_compare $current "5.4.0d1"] == -1} {
      ConfigurationManager sourceSql acs-service-contract-function-args.sql
    }
  }

  proc after-upgrade {
    {-from_version_name:required}
    {-to_version_name:required}
   } {
     if {[apm_version_names_compare $from_version_name "0.4"] == -1 &&
	 [apm_version_names_compare $to_version_name "0.4"] > -1} {
       
       # / / / / / / / / / / / / / / / / / / / / /
       # Upgrading to version 0.4

       # / / / / / / / / / / / / / / / / / / / / /
       # We also require some other, ACS object model,
       # related functions to be registered with 
       # acs_function_args. We did not report it so far
       # so it is a generic, non-invasive patch.
       # conditions:
       # db_driver == postgres
       ConfigurationManager sourceSql acs-object-model-function-args.sql
    
       # / / / / / / / / / / / / / / / / / / / / /
       # Make sure that we can take of advantage
       # the ::xo::db::sql::* wrapper facility
       # for stored procedures. This is required
       # since version 0.4 of xorb.
       # Starting with version 5.4.0d1, the
       # acs-service-contract core package
       # is supposed to come with the appropriate
       # install and upgrade scripts. For version
       # below, we take care of providing this
       # non-invasive functionality.
       # conditions:
       # - acs-service-contract version < 5.4.0d1
       # - db_driver == postgres

       set current [apm_highest_version_name acs-service-contract]
       if {[apm_version_names_compare $current "5.4.0d1"] == -1} {
	 ConfigurationManager sourceSql acs-service-contract-function-args.sql
       }

     }
   }
}