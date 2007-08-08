::xorb::Package initialize -ad_doc {
  
  Admin facility for UNregistering 
  implementations with the invoker
  More or less a copy-paste practice,
  taken from Neophytos' unbinding-install.tcl
  but I could not re-use it as it
  didn't allow for 
  1-) state mangling of the broker
  2-) providing a custom return url 

  Btw., I introduce ::xo::db::sql*
  for dispatching the actual db insert!


  @author stefan.sobernig@wu-wien.ac.at
  @creation-date August, 2007
  @cvs-id $Id$
  
} -parameter {
  -contract_name:required
  -impl_name:required
  {-return_url:optional "."}
}

# / / / / / / / / / / / / 
# TODO: Might change once 
# an AcsObjectType AcsScBinding
# is introduced. all current
# steps could so be encapsulated
# in the AcsObject delete step.
# TODO: permission check, again!

# 1-) clear backend
::xo::db::sql::acs_sc_binding delete \
    -contract_name $contract_name \
    -impl_name $impl_name
# 2-) re-init binding state in Broker
::XorbManager do ::xorb::manager::Broker init

# 3-) clear Skeleton cache for
# implementation, contract
# could potentially still be
# in use.
::xorb::SkeletonCache remove \
    [::xorb::Object canonicalName $impl_name] 

ad_returnredirect $return_url