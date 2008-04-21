::xo::library doc {

  xorb infrastructure for protocol plug-ins
  
  @author stefan.sobernig@wu-wien.ac.at	
  @creation-date March 7, 2007			
  @cvs-id $Id$

}

namespace eval ::xorb::protocols {
  
  ::xotcl::Class PluginClass -superclass ::xotcl::Class -slots {
    Attribute contextClass
  }
  
  namespace export PluginClass
}

