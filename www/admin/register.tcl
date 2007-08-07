::xorb::Package initialize -ad_doc {
  
  Admin facility for registering 
  implementations with the invoker
  More or less a copy-paste practice,
  taken from Neophytos' binding-install.tcl
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
# is introduced.


::xo::db::sql::acs_sc_binding new \
    -contract_name $contract_name \
    -impl_name $impl_name
::XorbManager do ::xorb::manager::Broker init

ad_returnredirect $return_url