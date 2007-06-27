# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# +-+-+-+-+ +-+-+-+-+ +-+-+-+-+-+
# |x|o|r|b| |t|e|s|t| |s|u|i|t|e|
# +-+-+-+-+ +-+-+-+-+ +-+-+-+-+-+
# author: stefan.sobernig@wu-wien.a.at
# cvs-id: $Id$
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

Object test
test set passed 0
test set failed 0
test proc case msg {ad_return_top_of_page "<title>$msg</title><h2>$msg</h2>"} 
test proc section msg    {my reset; ns_write "<hr><h3>$msg</h3>"} 
test proc subsection msg {ns_write "<h4>$msg</h4>"} 
test proc errmsg msg     {ns_write "ERROR: $msg<BR/>"; test incr failed}
test proc okmsg msg      {ns_write "OK: $msg<BR/>"; test incr passed}
test proc code msg       {ns_write "<pre>$msg</pre>"}
test proc reset {} {
  array unset ::xotcl_cleanup
  global af_parts  af_key_name
  array unset af_parts
  array unset af_key_name
}

proc ? {cmd expected {msg ""}} {
   set r [uplevel $cmd]
   if {$msg eq ""} {set msg $cmd}
   if {$r ne $expected} {
     test errmsg "$msg returned '$r' ne '$expected'"
   } else {
     test okmsg "$msg - passed ([t1 diff] ms)"
   }
}

# proc ?+ {cmd expected {msg ""}} {
#   if {$msg eq ""} {set msg $cmd}
#   if {[catch {set r [uplevel $cmd]} catchMsg]} {
#     if {[Throwable isThrowable $catchMsg]} {
#       test errmsg "$msg failed: [$catchMsg message] ([$catchMsg info class])."
#     } else {
#       global errorInfo
#       test errmsg "$msg failed: $errorInfo"
#     }
#   } else {
#     if {$r ne $expected} {
#        test errmsg "$msg returned '$r' ne '$expected'"
#     } else { 
#       test okmsg "$msg passed ([t1 diff] ms)"
#     }
#   }
# }

proc ?+ {cmd {msg ""}} {
  if {$msg eq ""} {set msg $cmd}
  try {
    set r [uplevel $cmd]
     test okmsg "$msg passed ([t1 diff] ms)"
  } catch {Exception e} {
    test errmsg "$msg failed: <pre>[ad_quotehtml [$e set __message__([[$e info class] contentType])]]</pre>"
  } catch {error e} {
    global errorInfo
    test errmsg "$msg failed: $errorInfo"
  }
 
}

proc ?++ {cmd expected {msg ""}} {
  if {$msg eq ""} {set msg $cmd}
  try {
    set r [uplevel $cmd]
    if {$r ne $expected} {
      test errmsg "$msg returned '$r' ne '$expected'"
    } else { 
      test okmsg "$msg passed ([t1 diff] ms)"
    }
  } catch {Exception e} {
    test errmsg "$msg failed: <pre>[ad_quotehtml [$e set __message__([[$e info class] contentType])]]</pre>"
  } catch {error e} {
    test errmsg "$msg failed: $e"
  }
}

proc ?- {cmd expected {msg ""}} {
  if {$msg eq ""} {set msg $cmd}
  set status [catch {set r [uplevel $cmd]} catchMsg]
  if {$status eq $expected} {
    test okmsg "$msg passed: $status eq $expected"
  } else {
    test errmsg "$msg failed: $status ne $expected"
  }
}

# / / / / / / / / / / / / / / /
# Negative-expected test 
# Suceeds if certain expected
# exception is caught!
# knows four states.

proc ?-- {cmd expected {msg ""}} {
  if {$msg eq ""} {set msg $cmd}
  try {
    set r [uplevel $cmd]
    test errmsg "$msg failed due to NO error"
  } catch {Exception e} {
    if {[$e istype $expected]} {
      test okmsg "$msg passed ([t1 diff] ms):<pre>[ad_quotehtml [$e set __message__([[$e info class] contentType])]]</pre>"
    } else {
      test errmsg "$msg failed due to UNEXPECTED exception:<pre>[ad_quotehtml [$e set __message__([[$e info class] contentType])]]</pre>"
    }
  } catch {error e} {
    test errmsg "$msg failed due to UNEXPECTED error: $e"
  }
  
}
# / / / / / / / / / / / / / / /
# Negative-expected test 
# Suceeds if certain expected
# exception is caught!
# knows four states.

proc ?-- {cmd expected {msg ""}} {
  if {$msg eq ""} {set msg $cmd}
  try {
    set r [uplevel $cmd]
    test errmsg "$msg failed due to NO error"
  } catch {Exception e} {
    if {[$e istype $expected]} {
      test okmsg "$msg passed ([t1 diff] ms):<pre>[ad_quotehtml [$e set __message__([[$e info class] contentType])]]</pre>"
    } else {
      test errmsg "$msg failed due to UNEXPECTED exception:<pre>[ad_quotehtml [$e set __message__([[$e info class] contentType])]]</pre>"
    }
  } catch {error e} {
    test errmsg "$msg failed due to UNEXPECTED error: $e"
  }
  
}

# proc ?-- {cmd expected {msg ""}} {
#   if {$msg eq ""} {set msg $cmd}
#    if {[catch {set r [uplevel $cmd]} catchMsg]} {
#      global errorInfo
#      if {[Throwable isThrowable $catchMsg] && [$catchMsg istype $expected]} {
#        test okmsg "$msg passed: $expected eq [$catchMsg info class]."
#      } elseif {$expected eq "error"} {
#        test okmsg "$msg passed: expected error caught ($errorInfo)"
#      } else {
#        test errmsg "$msg failed: unexpected error caught ($errorInfo)"
#      }
#    } else {
#      test errmsg "$msg failed: no error caught."
#    }
# }
 Class Timestamp
  Timestamp instproc init {} {my set time [clock clicks -milliseconds]}
  Timestamp instproc diffs {} {
    set now [clock clicks -milliseconds]
    set ldiff [expr {[my exists ltime] ? [expr {$now-[my set ltime]}] : 0}]
    my set ltime $now
    return [list [expr {$now-[my set time]}] $ldiff]
  }
  Timestamp instproc diff {{-start:switch}} {
    lindex [my diffs] [expr {$start ? 0 : 1}]
  }

  Timestamp instproc report {{string ""}} {
    foreach {start_diff last_diff} [my diffs] break
    my log "--$string (${start_diff}ms, diff ${last_diff}ms)"
  }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

Timestamp t1

# / / / / / / / / / / / / /

test case "xorb test cases"

test section "Basic Setup"
namespace import -force ::xoexception::*
namespace import -force ::xorb::*
namespace import -force ::xorb::context::*

# # # # # # # # # # # # # 
# # # # # # # # # # # # # 
# # cleanup


# 1) cleanup db
# 1a) contracts
set clist [list myTreaty myContract AATreaty]
set sql_1 [list "delete from acs_sc_contracts"]
set sql_2 [list "delete from acs_sc_msg_types"]
foreach c $clist {
  set name $c
  #set name [expr {[$c exists name]?[$c name]:[namespace tail $c]}]
  if {[llength $sql_1] == 1} {lappend sql_1 "where";lappend sql_2 "where"}
  if {[llength $sql_1] >= 3} {lappend sql_1 "or"; lappend sql_2 "or"}
  lappend sql_1 "contract_name like '$name'"
  lappend sql_2 "msg_type_name like '$name.%'"
}
#1b) impls
set ilist [list myImplementation AAImplementation ::xowiki::ExamplePage AA-2-LC-Adapter AA-2-LO-Adapter]
set sql_3 [list "delete from acs_sc_impls"]
foreach i $ilist {
  set name $i
  #set name [expr {[$i exists name]?[$i name]:[namespace tail $i]}]
  if {[llength $sql_3] == 1} {lappend sql_3 "where"}
  if {[llength $sql_3] >= 3} {lappend sql_3 "or"}
  lappend sql_3 "impl_name like '$name'"
}
set cleanupSQL "[join $sql_1]; [join $sql_2]; [join $sql_3]"
#db_dml db_cleanup $cleanupSQL


#?+ {testproc} "test error with exception thrown"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# ((title)) 			XOTcl version test
# ((description)) 	Verifies whether the adequate XOTcl version is installed >1.5
# ((type)) 			Basic Setup
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

? {expr {$::xotcl::version < 1.5}} 0 "XOTcl Version $::xotcl::version >= 1.5"
?- {
  ns_cache eval xorb_skeleton_cache dummy { set x 1 }
  ns_cache flush xorb_skeleton_cache dummy
} 0 "Initiating cache for skeleton objects"

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# CoI/ Configurations
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test section "Chain of Interceptors (CoI)"

# / / / / / / / / / / / / / / / / 

?- { 
  Interceptor DummyInterceptor
  DummyInterceptor instproc handleRequest {requestObj} { next }
  DummyInterceptor instproc handleResponse {responseObj} { next }

  Interceptor AuthenticationInterceptor
  AuthenticationInterceptor instproc handleRequest {requestObj} { next }
  AuthenticationInterceptor instproc handleResponse {responseObj} { next }

  Interceptor CachingInterceptor
  CachingInterceptor instproc handleRequest {requestObj} { next }
  CachingInterceptor instproc handleResponse {responseObj} { next }

  Interceptor LoggingInterceptor2
  LoggingInterceptor2 instproc handleRequest {requestObj} { next }
  LoggingInterceptor2 instproc handleResponse {responseObj} { next }
  
} 0 "Declaring custom interceptors"


test subsection "Configurations"

# / / / / / / / / / / / / / / / / /

?- {
  Configuration DummySuper -contains {
    ::xorb::Configuration::Element el1 \
	-interceptor ::template::CachingInterceptor \
	-array set properties {
	  listen all
	}
    ::xorb::Configuration::Element el2 \
	-interceptor ::template::DummyInterceptor \
	-array set properties {
	  listen myImplementation
	  position 5
	}
    ::xorb::Configuration::Element el3 \
	-interceptor ::template::AuthenticationInterceptor \
	-array set properties {
	  protocol soap
	  position 2
	}
  }
} 0 "Creating super configuration for testing purposes." 

?- {
  Configuration DummySub -superclass ::template::DummySuper -contains {
    ::xorb::Configuration::Element el1 \
	-interceptor ::template::LoggingInterceptor2 \
	-array set properties {
	  protocol remote
	  position 5
	}
  }
} 0 "Creating custom CoI Configuration, including custom interceptor"

# / / / / / / / / / / / / / / / / /
?- { ::xorb::rhandler load ::template::DummySub } 0 \
    "Loading custom configuration into request and response flow"

# / / / / / / / / / / / / / / / / /
set reqMixins [::xorb::rhandler::RequestFlow info mixin]
set compare [list ::template::CachingInterceptor \
		 ::template::AuthenticationInterceptor \
		 ::template::DummyInterceptor \
		 ::template::LoggingInterceptor2]
? {expr {$reqMixins eq $compare}} 1 \
    "Validating RequestFlow configuration ($reqMixins=$compare)" 

# / / / / / / / / / / / / / / / / /
set resMixins [::xorb::rhandler::ResponseFlow info mixin]
set compare  [list ::template::LoggingInterceptor2 \
		   ::template::DummyInterceptor \
		   ::template::AuthenticationInterceptor \
		   ::template::CachingInterceptor]
? {expr {$resMixins eq $compare}} 1 \
    "Validating ResponseFlow configuration ($resMixins=$compare)" 

# / / / / / / / / / / / / / / / / /
?- { ::xorb::rhandler load Standard } 0 \
    "Re-establishing STANDARD configuration into request and response flow"



test section "Skeleton: Service Contracts"

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# staging
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

if {[::xotcl::Object isobject myTreaty]} {
  myTreaty destroy
}
if {[::xotcl::Object isobject myImplementation]} {
  myImplementation destroy
}

set keys [ns_cache names xorb_skeleton_cache *]
foreach k $keys {ns_cache flush xorb_skeleton_cache $k}


# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# contract specification
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
test subsection "Skeleton: Contract specification"

::xorb::ServiceContract myContract -defines {
  ::xorb::Abstract m2 -arguments {
    arg1:string 
    arg3:integer
  } -returns "returnValue:string" -description "m2's description"
  ::xorb::Abstract m3 -arguments {
    arg1:string 
    arg3:integer
  } -returns "returnValue:string" -description "m3's description"
} -ad_doc {myContract's description} 

# / / / / / / / / / / / / / /
# init has to be called/ processed
# before the deployment, so
# 1) either call .. -init -deploy
# as flags to ::xotcl::Object configure
# 2) or make it a separate call (see
# below)
# myContract deploy

set eStream {operations {m2 {description {m2's description} input {arg1:string arg3:integer} output returnValue:string} m3 {description {m3's description} input {arg1:string arg3:integer} output returnValue:string}} description {myContract's description} name ::template::myContract}
set eSignature [ns_sha1 $eStream]

? {catch {set spec [myContract stream]}} 0 "Streaming contract into array list."
? {expr {$eStream eq $spec}} 1 "Streaming produces valid contract spec."
? {catch {set sig [myContract getSignature]}} 0 "Streaming contract into array list: generating signature."
? {expr {$eSignature eq $sig}} 1 "Expected signature from spec is valid."

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# contract sync
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test subsection "Skeleton: Contract persistence / synchronisation"
myContract mixin ::xorb::Synchronizable
# / / / / / / / / / / / / / / / / / / /
? {catch {array set status [myContract action]}} 0 "Synchronising contract with backend: retrieve status (getAction-1)."
? {set status(action)} "save" "Synchronising contract with backend: action is 'save' (getAction-2)."
? {catch {myContract sync}} 0 "Synchronising contract with backend: new contract (save)."
? { db_0or1row contract_saved \
  [myContract subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
 } 1 "Synchronising contract with backend: new contract (id:[myContract object_id]) successfully stored."
# / / / / / / / / / / / / / / / / / / /
myContract defines {
  ::xorb::Abstract m4 -arguments {
    arg4:string } -returns "returnValue:string" -description "m4's description"
}
? {catch {array set status [myContract action]}} 0 "Synchronising contract with backend: retrieve status (getAction-3)."
? {set status(action)} "update" "Synchronising contract with backend: action is 'update' (getAction-4)."
#myContract sync
? {catch {myContract sync}} 0 "Synchronising contract with backend: updated contract (update)."
? { db_0or1row contract_updated \
  [myContract subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
} 1 "Synchronising contract with backend: existing contract (id:[myContract getState oldId]) successfully updated (id:[myContract object_id])."
# / / / / / / / / / / / / / / / / / / /
? {catch {array set status [myContract action]}} 0 "Synchronising contract with backend: retrieve status (getAction-5)."
#? {set status(action)} "update" "Synchronising contract with backend: action is 'update' (before delete) (getAction-6)."
? {set status(action)} "" "Synchronising contract with backend: action is '' (before delete) (getAction-6)."
? {catch {myContract sync -delete}} 0 "Synchronising contract with backend: remove contract (delete)."
? { db_0or1row contract_deleted \
  [myContract subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
} 0 "Synchronising contract with backend: existing contract (id:[myContract object_id]) successfully deleted."
myContract mixin delete ::xorb::Synchronizable
# / / / / / / / / / / / / / / / / / / /
? {expr {[::xotcl::Object isobject XorbManager] && [thread::exists [XorbManager get_tid]]}} 1 "xorb's managing thread exists."


# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# implementations
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test section "Skeleton: Service Implementations / Bindings"

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# staging
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
test subsection "Implementations: staging"

::xorb::ServiceContract myTreaty -defines {
  ::xorb::Abstract m2 -arguments {
    arg1:boolean 
    arg3:integer
  } -returns "returnValue:string" -description "m2's description"
  ::xorb::Abstract m3 -arguments {
    arg1:string 
    arg3:integer
  } -returns "returnValue:integer" -description "m3's description"
} -ad_doc {myTreaty's description}

myTreaty mixin add ::xorb::Synchronizable
myTreaty sync

? { db_0or1row contract_saved \
  [myTreaty subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
 } 1 "Staging: test contract (id:[myTreaty object_id]) is available."

myTreaty mixin delete ::xorb::Synchronizable
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# implementation spec
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test subsection "Skeleton: Implementation specification"

::xorb::ServiceImplementation myImplementation \
    -implements ::template::myTreaty \
    -using {
    ::xorb::Delegate m2 -proxies ::myproc
    ::xorb::Method m3 {
      arg1:required 
      arg3:required
    } {doc} {
      return 1
    }  
}

set eStream {pretty_name ::template::myImplementation name ::template::myImplementation aliases {m2 ::myproc m3 ::template::myImplementation::__m3__} contract_name ::template::myTreaty owner {}}
set eSignature [ns_sha1 $eStream]

? {catch {set spec [myImplementation stream]}} 0 "Streaming implementation into array list."
? {expr {$eStream eq $spec}} 1 "Streaming produces valid implementation spec."
? {catch {set sig [myImplementation getSignature]}} 0 "Streaming implementation into array list: generating signature."
? {expr {$eSignature eq $sig}} 1 "Expected signature from spec is valid."

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# implementation sync
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test subsection "Skeleton: Implementation persistence/ synchronization"

# !!!!!!!!!!!!
myImplementation mixin add ::xorb::Synchronizable
# / / / / / / / / / / / / / / / / / / /
? {catch {array set status [myImplementation action]}} 0 "Synchronising implementation with backend: retrieve status (getAction-1)."
? {set status(action)} "save" "Synchronising implementation with backend: action is 'save' (getAction-2)."
? {catch {myImplementation sync}} 0 "Synchronising implementation with backend: new implementation (save)."
? { db_0or1row impl_saved \
  [myImplementation subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 1 "Synchronising implementation with backend: new implementation (id:[myImplementation object_id]) successfully stored."
# / / / / / / / / / / / / / / / / / / /
? {catch {myImplementation sync -delete}} 0 "Synchronising implementation with backend: remove implementation (delete)."
? { db_0or1row impl_deleted \
  [myImplementation subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
} 0 "Synchronising implementation with backend: existing implementation (id:[myImplementation object_id]) successfully deleted."

test subsection "Update on implementations: recreation => conformance, binding" 

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# super-set of contract
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

# initial impl
myImplementation sync
# extended one
myImplementation using {
  ::xorb::Delegate m4 -proxies ::myproc2
}

? {catch {array set status [myImplementation action]}} 0 "Implementation update (impl as super-set of contract) retrieve status (getAction-1)."
? {set status(action)} "update" "Implementation update (impl as super-set of contract): action is 'update' (getAction-2)."
? {catch {myImplementation sync}} 0 "Implementation update (impl as super-set of contract): updated implementation (update)."
? { db_0or1row impl_updated \
  [myImplementation subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
} 1 "Implementation update (impl as super-set of contract): existing implementation (id:[myImplementation getState oldId]) successfully updated (id:[myImplementation object_id])."
# / / / / / / / / / / / / / / / / / / /

test subsection "Update on contract having a binding: recreation => binding"
myTreaty mixin add ::xorb::Synchronizable
myTreaty defines {
  ::xorb::Abstract m4 -arguments {
    arg4:string
  } -returns "resultValue:integer" -description "m4's description"
}

set bindings_before [XorbManager do ::xorb::manager::Broker array get bindings [myTreaty object_id]]

? {catch {array set status [myTreaty action]}} 0 "Synchronising contract with backend: retrieve status (getAction-1)."
? {set status(action)} "update" "Synchronising contract with backend: action is 'update' (getAction-2)."
#myTreaty sync
? {catch {myTreaty sync}} 0 "Synchronising contract with backend: updated contract (update)."
? { db_0or1row contract_updated \
  [myTreaty subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
} 1 "Synchronising contract with backend: existing contract (id:[myTreaty getState oldId]) successfully updated (id:[myTreaty object_id])."

set bindings_after [XorbManager do ::xorb::manager::Broker array get bindings [myTreaty object_id]]

? {expr {[lindex $bindings_after 1] eq [lindex $bindings_before 1]}} 1 "Recreation of bindings successful --- before=($bindings_before),after=($bindings_after) ---"
myTreaty mixin delete ::xorb::Synchronizable

# / / / / / / / / / / / / / / / / / / /
test subsection "Conformance checking (Containment)"

ServiceContract CallerInterface -defines {
  ::xorb::Abstract abstractCallOne -description "abstractCallOne desc"
  ::xorb::Abstract abstractCallTwo -description "abstractCallTwo desc"
}

CallerInterface deploy

ServiceImplementation CalleeInterface \
    -implements ::template::CallerInterface \
    -using {
      ::xorb::Delegate abstractCallTwo \
	  -proxies ::template::ServantClass::servantMethod
      ::xorb::Delegate abstractCallOne \
	  -proxies ::template::servantProc
}

? {CalleeInterface check} 1 "Verifying conformance of implementation ('check', implementation is fully containing contract)"
CalleeInterface destroy

ServiceImplementation CalleeInterface \
    -implements ::template::CallerInterface \
    -using {
      ::xorb::Delegate abstractCallTwo \
	  -proxies ::template::ServantClass::servantMethod
}

? {CalleeInterface check} 0 \
    {	Verifying conformance of implementation ('check', 
     	implementation is NOT fully containing contract)
    }
CalleeInterface destroy

# / / / / / / / / / / / / / / / / / / /
test subsection "Deployment"

Interceptor GeneralInterceptor
Interceptor SoapInterceptor
ServiceImplementation CalleeInterface \
    -implements ::template::CallerInterface \
    -using {
      ::xorb::Delegate abstractCallTwo \
	  -proxies ::template::ServantClass::servantMethod
      ::xorb::Delegate abstractCallOne \
	  -proxies ::template::servantProc
}

?+ {CalleeInterface deploy \
    -interceptors {
      {soap ::template::SoapInterceptor}
      ::template::GeneralInterceptor
    } \
    -defaultPermission public \
    -requirePermission {
      abstractCallTwo none
      abstractCallOne login
    }
} "Deploying ServiceImplementation (per-implementation interceptors, access policy"

set p [parameter::get -parameter "per_instance_policy"]
? {::xotcl::Object isobject ${p}::[CalleeInterface canonicalName]} 1 \
    "Verifying existance of per-implementation policy object"

?+ {${p}::[CalleeInterface canonicalName] destroy} "Cleanup policy object"


# / / / / / / / / / / / / / / / / / / /
# non-xorb'ed contract at design time!
# on-time synchronisation.
?+ {
  ServiceImplementation FtsContentProviderImpl \
	     -name ::xowiki::ExamplePage \
	     -implements ::template::FtsContentProvider \
	     -using {
	       ::xorb::Delegate datasource -proxies ::xowiki::datasource
	       ::xorb::Method url {
		 revision_id:required
	       } {doc} {
		 # render item link
		 return "link"
	       }
	     }
} "Defining an implementation for an existing, originally non-xorb'ed contract"
  
?+ {
  FtsContentProviderImpl deploy -now
} "Use deployment mechanism to sync implementation"

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# Skeleton: Generation / Broker Interaction
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

# / / / / / / / / / / / / /
# for basic tests
# remove 
# - ::xorb::ServantAdapter
# - ::xorb::ReturnValueChecker

if {[::xorb::Skeleton info instmixin *ServantAdapter] ne {}} {
  ::xorb::Skeleton instmixin delete ::xorb::ServantAdapter
}

if {[::xorb::Skeleton info instmixin *ReturnValueChecker] ne {}} {
  ::xorb::Skeleton instmixin delete ::xorb::ReturnValueChecker
}

# / / / / / / / / / / / / /
test section "Skeleton: Generation / Broker Interaction"
ns_log notice "----------Generation--------------"
::xorb::Skeleton mixin add ::xorb::SkeletonCache

? {expr {[lsearch -glob [::xorb::Skeleton info mixin] \
	      ::xorb::SkeletonCache] ne "-1"}} 1 \
    "Availability of caching optimisation for skeletons"
ns_write bindings_before=[XorbManager do ::xorb::manager::Broker array get bindings]

?++ {expr {[[[::xorb::Skeleton generate \
		  -contract ::template::myTreaty \
		  -impl ::template::myImplementation] info class] info class] eq "::xorb::ServiceImplementation"}} 1 "Skeleton: Generating skeleton object (contract + impl passed as arguments)" 

? {llength [ns_cache names xorb_skeleton_cache *myTreaty]} 1 "Caching of contract skeleton"

? {llength [ns_cache names xorb_skeleton_cache *myImplementation]} 1 "Caching of implementation skeleton"

?++ {expr {[[[::xorb::Skeleton generate -impl ::template::myImplementation] info class] info class] eq "::xorb::ServiceImplementation"}} 1 "Skeleton: Generating skeleton object (only impl passed as argument)" 

# / / / / / / / / / / / / /
myTreaty mixin add ::xorb::Synchronizable
myTreaty slot m4 destroy
? {catch {myTreaty sync}} 0 "Synchronising contract with backend: updated contract / clearing cache from skeleton representation (update)."
myTreaty mixin delete ::xorb::Synchronizable

? {llength [ns_cache names xorb_skeleton_cache *myTreaty]} 0 "Clearing cache when updating contract"

# # / / / / / / / / / / / / /
# myImplementation mixin add ::xorb::Synchronizable
myImplementation slot m4 destroy
? {catch {myImplementation sync}} 0 "Synchronising implementation with backend: updated implementation / clearing cache from skeleton representation (update)."
#myImplementation mixin delete ::xorb::Synchronizable

? {llength [ns_cache names xorb_skeleton_cache *myImplementation]} 0 "Clearing cache when updating implementation"

::xorb::Skeleton mixin delete ::xorb::SkeletonCache

? {expr {[lsearch -glob [::xorb::Skeleton info mixin] \
	      ::xorb::SkeletonCache] eq "-1"}} 1 \
    "Removed caching optimisation for skeletons"

test subsection "Adapting for positional arguments (::xorb::ServantAdapter)"

# / / / / / / / / / / / / /
# identifying types of servants

# proc
proc servantProc {arg1 arg2 arg3} {}
set servant "::template::servantProc"
? {ServantAdapter identify $servant} 0 "Identifying servant as proc" 

# object n°1
::xotcl::Object ServantObj
ServantObj proc servantMethod {-arg1 -arg2 -arg3} {}
set servant "::template::ServantObj::servantMethod"
? {ServantAdapter identify $servant} 1 "Identifying servant as object"

# object n°2 (uncanonical name)
set servant "::template::ServantObj servantMethod"
? {ServantAdapter identify $servant} 1 \
    "Identifying servant as object by non-canonical reference"
# class
::xotcl::Class ServantClass
ServantClass instproc servantMethod {-arg1 -arg2 -arg3} {}
set servant "::template::ServantClass::servantMethod"
? {ServantAdapter identify $servant} 2 "Identifying servant as class" 

# / / / / / / / / / / / / /
# retrieving arg declarations

set servant "::template::servantProc"
? {ServantAdapter getDeclaration $servant} {arg1 arg2 arg3} \
    "Retrieving argument declaration from proc servant"

set servant "::template::ServantObj servantMethod"
? {ServantAdapter getDeclaration $servant} {-arg1 -arg2 -arg3} \
    "Retrieving argument declaration from object servant"

set servant "::template::ServantClass servantMethod"
? {ServantAdapter getDeclaration $servant} {-arg1 -arg2 -arg3} \
    "Retrieving argument declaration from class servant"

set servant "::template::myproc2"
?-- {ServantAdapter getDeclaration $servant} \
    ::xorb::exceptions::SkeletonGenerationException\
    "Retrieving argument declaration from invalid (non-existant) servant"

# / / / / / / / / / / / / / / / / /
# adapter + returnvaluechecker

Skeleton instmixin add ::xorb::ServantAdapter
Skeleton instmixin add ::xorb::ReturnValueChecker
ServantObj proc servantMethod {arg1 arg2 arg3} {}
ServantClass instproc servantMethod {-arg1 -arg2 -arg3} {}

::xorb::ServiceContract AATreaty -defines {
  ::xorb::Abstract m1 -arguments {
    arg1:string
    arg2:string
    arg3:string
  } -description "m1's description"
  ::xorb::Abstract m2 -arguments {
    arg1:string
    arg2:string
    arg3:string
  } -returns "returnValue:integer" -description "m2's description"
  ::xorb::Abstract m3 -arguments {
    arg1:string
    arg2:string
    arg3:string
  } -returns "returnValue:integer" -description "m3's description"
} -ad_doc {myTreaty's description}


::xorb::ServiceImplementation AAImplementation \
    -implements ::template::AATreaty \
    -using {
      ::xorb::Delegate m1 -proxies ::template::servantProc
      ::xorb::Delegate m2 -proxies {::template::ServantObj servantMethod} 
      ::xorb::Delegate m3 -proxies ::template::ServantClass::servantMethod
    }

AATreaty mixin add ::xorb::Synchronizable
? {catch {AATreaty sync}} 0 \
    "Synchronising contract with backend: arguments adapter (save)."
AATreaty mixin delete ::xorb::Synchronizable

AAImplementation mixin add ::xorb::Synchronizable
? {catch {AAImplementation sync}} 0 \
    "Synchronising implementation with backend: arguments adapter (save)."
AAImplementation mixin delete ::xorb::Synchronizable

?+ {set s [::xorb::Skeleton generate -impl ::template::AAImplementation]} \
    "Generating skeleton object for adapter test (I)" 

?++ {expr {[[$s info class] info class] eq "::xorb::ServiceImplementation"}} 1 \
    "Generating skeleton object for adapter test (II)" 

# / / / / / / / / / / / / /
# verifying return value
# checker
set contractClass [$s info mixin]
?++ {::xotcl::Object isobject ${contractClass}::rvc} 1 \
    "Creating manager for checking return value type constraints"
?++ {lsort [${contractClass}::rvc info procs]} [list m2 m3] \
    "Verifying manager for expected check procs."

test subsection "Invoker: Dispatching invocation calls"

# # # # # # # # # # # # # # #
# staging: set Default policy
# to "none"

::xorb::deployment::Default default_permission none

?+ {InvocationContext ::xo::cc -user_id 0} "Requiring invocation context object"

# / / / / / / / / / / / / / 
# a little helper to translate
# arguments to anythings


::xotcl::Class AnythingUs -parameter {
  signature
  arguments
}
AnythingUs instproc now {} {
  my instvar signature arguments
  my proc __parse__ [lindex $signature 0] {
    #foreach v [info vars] { uplevel [list set parsedArgs($v) [set $v]]}
    if {[info exists returnObjs]} {
      return $returnObjs
    }
  }
  my debug sig=[lindex $signature 0],args_decl=[my info nonposargs __parse__]
  # call parser
  my debug args=[lindex $arguments 0]
  ::xotcl::nonposArgs mixin add \
      ::xorb::datatypes::Anything::CheckOption+Uplift
  set r [eval my __parse__ [lindex $arguments 0]]
  ::xotcl::nonposArgs mixin delete \
      ::xorb::datatypes::Anything::CheckOption+Uplift
  my debug ANYS=$r
  return $r
}

# / / / / / / / / / / / / /
# preparing call to 
# AAImplementation -> m1
::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m1
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]

?+ {set i [Invoker new]} "Creating invoker instance (1st call)"

# / / / / / / / / / / / / / / / / / / / /
# 1st call test
# - to tcl proc
# - ! involved np-args to p-args conversion
# - no return value check

proc servantProc {arg1 arg2 arg3} {
  ns_write "<pre>servantProc:</pre>"
  ns_write "<pre>arg1=$arg1,arg2=$arg2,arg3=$arg3</pre>"
}
?+ {$i invoke} [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# / / / / / / / / / / / / / / / / / / / /
# 2nd call test (AAImplementation -> m2)
# - ! to obj proc
# - ! argument conversion
# - ! return value check

::xo::cc virtualCall m2
# --
ServantObj proc servantMethod {arg1 arg2 arg3} {
  ns_write "<pre>[self]->[self proc]:</pre>"
  ns_write "<pre>arg1=$arg1,arg2=$arg2,arg3=$arg3</pre>"
  return 1
}

?+ {set i [Invoker new]} "Creating invoker instance (2nd call)"
#ns_write 2nd-call-invoke=[$i invoke]
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# / / / / / / / / / / / / / / / / / / / /
# 3rd call test (AAImplementation -> m3)
# - ! to obj proc
# - ! argument conversion
# - ! return value check

::xo::cc virtualCall m3
# --
ServantClass instproc servantMethod {
  -arg1:required 
  -arg2:required 
  -arg3:required
} {
  ns_write "<pre>[self]->[self proc]:</pre>"
  ns_write "<pre>arg1=$arg1,arg2=$arg2,arg3=$arg3</pre>"
  return 1
}

?+ {set i [Invoker new]} "Creating invoker instance (3rd call)"
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# / / / / / / / / / / / / /
# ReturnValueTypeMismatch

ServantClass instproc servantMethod {
  -arg1:required 
  -arg2:required 
  -arg3:required
} {
  ns_write "<pre>[self]->[self proc]:</pre>"
  ns_write "<pre>arg1=$arg1,arg2=$arg2,arg3=$arg3</pre>"
  return one
}

?+ {set i [Invoker new]} "Creating invoker instance (ReturnValueTypeMismatch)"
?-- {[$i invoke] set __value__} "::xorb::exceptions::ReturnValueTypeMismatch" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), non-conforming return value
}]


# / / / / / / / / / / / / /
# preparing call to non-existant
# method on Implementation
# AAImplementation -> m4
::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m4
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]

?+ {set i [Invoker new]} \
    "Creating invoker instance (non-existant servant (method))"
?-- {[$i invoke] set __value__} "::xorb::exceptions::InvocationException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), non-existant servant (method)
}]

# / / / / / / / / / / / / /
# preparing call to 
# method on Implementation
# no adhereing to contracted
# signature
# AAImplementation -> m4
::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]


?+ {set i [Invoker new]} \
    "Creating invoker instance (record mismatch (contract))"
?-- {[$i invoke] set __value__} "::xorb::exceptions::InvocationException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), contract mismatch (contract)
}]


# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# unstaging
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

# # # # # # # # # # # # # # #
# re-set Default policy
# to "public"
::xorb::deployment::Default default_permission public

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# Access policies
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test subsection "Adapters"

# / / / / / / / / / / / / /
# define an implementation
# in terms of an adapter to
# a piece of existing code.

# ::xorb::ServiceContract AATreaty -defines {
#   ::xorb::Abstract m1 -arguments {
#     arg1:string
#     arg2:string
#     arg3:string
#   } -description "m1's description"
#   ::xorb::Abstract m2 -arguments {
#     arg1:string
#     arg2:string
#     arg3:string
#   } -returns "returnValue:integer" -description "m2's description"
#   ::xorb::Abstract m3 -arguments {
#     arg1:string
#     arg2:string
#     arg3:string
#   } -returns "returnValue:integer" -description "m3's description"
# } -ad_doc {myTreaty's description}

# # # # # # # # # # # # # # #
# staging: set Default policy
# to "none"

::xorb::deployment::Default default_permission none

# / / / / / / / / / / / / /
# 1) legacy classes
# the legacy piece
::xotcl::Class LegacyClass
LegacyClass ad_instproc legacyM3 {
  -arg1
  -arg2:integer
} {doc} {
  ns_write "<pre>[self]-:[self proc] invoked</pre>"
}
LegacyClass ad_instproc legacyM2 {
  -arg1
  -arg2
  -arg3
} {doc} { ns_write "[self]-:[self proc] invoked" }
LegacyClass ad_instproc legacyM1 {
  -arg1
  -arg2
  -arg3
} {doc} { ns_write "[self]-:[self proc] invoked" }

# relate it/ make it compatible
# to AATreaty->m3

ClassAdapter AA-2-LC-Adapter \
    -implements ::template::AATreaty \
    -adapts {
      m3	{::template::LegacyClass legacyM3}
      m2	{::template::LegacyClass legacyM2}
      m1	{::template::LegacyClass legacyM1}
    }

?+ {
  AA-2-LC-Adapter deploy
} "Use deployment mechanism to sync 'adaptor implementation'"

# setting the call environment
# 1) NEGATIVE test -> no record adaptation to legacy instproc!
::xo::cc virtualObject ::template::AA-2-LC-Adapter
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]

#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} "Creating invoker instance ('adaptor implementation' - class)"
?-- {[$i invoke] set __value__} "::xorb::exceptions::ServantDispatchException" [subst {
  Dispatching invocation call (negative class adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# adapter method (handle signature mismatches)
AA-2-LC-Adapter ad_instproc legacyM3 {
  -arg1
  -arg2
  -arg3
} {doc} {
  if {![string is integer $arg2]} {set arg2 123}
  next -arg1 $arg3 -arg2 $arg2;#LegacyClass->legacyClass
}

# 2) POSITIVE test
?+ {set i [Invoker new]} "Creating invoker instance ('adaptor implementation' - class)"
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call (positive class adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# / / / / / / / / / / / / /
# 2) legacy objects
# the legacy piece
::xotcl::Object LegacyObject
LegacyObject ad_proc legacyM3 {
  -arg1
  -arg2:integer
} {doc} {
  ns_write "<pre>[self]-:[self proc] invoked</pre>"
}
LegacyObject ad_proc legacyM2 {
  -arg1
  -arg2
  -arg3
} {doc} { ns_write "<pre>[self]-:[self proc] invoked</pre>" }
LegacyObject ad_proc legacyM1 {
  -arg1
  -arg2
  -arg3
} {doc} { ns_write "<pre>[self]-:[self proc] invoked</pre>" }

# relate it/ make it compatible
# to AATreaty->m3

ObjectAdapter AA-2-LO-Adapter \
    -implements ::template::AATreaty \
    -adapts {
      m3	{::template::LegacyObject legacyM3}
      m2	{::template::LegacyObject legacyM2}
      m1	{::template::LegacyObject legacyM1}
    }

?+ {
  AA-2-LO-Adapter deploy
} "Use deployment mechanism to sync 'adaptor implementation'"

# setting the call environment
# 1) NEGATIVE test -> no record adaptation to legacy instproc!
::xo::cc virtualObject ::template::AA-2-LO-Adapter
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} "Creating invoker instance ('adaptor implementation' - object)"
?-- {[$i invoke] set __value__} "::xorb::exceptions::ServantDispatchException" [subst {
  Dispatching invocation call (negative class adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# adapter method (handle signature mismatches)
AA-2-LO-Adapter ad_instproc legacyM3 {
  -arg1
  -arg2
  -arg3
} {doc} {
  if {![string is integer $arg2]} {set arg2 123}
  next -arg1 $arg3 -arg2 $arg2;#LegacyClass->legacyClass
}

# 2) POSITIVE test
?+ {set i [Invoker new]} "Creating invoker instance ('adaptor implementation' - object)"
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call (positive class adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# 3) legacy procs
# the legacy piece
ad_proc legacyM3 {
  -arg1
  -arg2
} {doc} {
  ns_write "<pre>[info vars] invoked</pre>"
}
ad_proc legacyM2 {
  -arg1
  -arg2
  -arg3
} {doc} { ns_write "<pre>[info current] invoked</pre>" }
ad_proc legacyM1 {
  -arg1
  -arg2
  -arg3
} {doc} { ns_write "<pre>[info current] invoked</pre>" }

# relate it/ make it compatible
# to AATreaty->m3

ProcAdapter AA-2-LP-Adapter \
    -implements ::template::AATreaty \
    -adapts {
      m3	::template::legacyM3
      m2	::template::legacyM2
      m1	::template::legacyM1
    }

?+ {
  AA-2-LP-Adapter deploy -now
} "Use deployment mechanism to sync 'adaptor implementation'"

# setting the call environment
# 1) NEGATIVE test -> no record adaptation to legacy instproc!
::xo::cc virtualObject ::template::AA-2-LP-Adapter
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} "Creating invoker instance ('adaptor implementation' - proc)"
?-- {[$i invoke] set __value__} "::xorb::exceptions::ServantDispatchException" [subst {
  Dispatching invocation call (negative proc adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# adapter method (handle signature mismatches)
AA-2-LP-Adapter ad_instproc legacyM3 {
  -arg1
  -arg2
  -arg3
} {doc} {
  if {![string is integer $arg2]} {set arg2 123}
  next -arg1 $arg3 -arg2 $arg2;#legacyM3 proc
}

# 2) POSITIVE test
?+ {set i [Invoker new]} "Creating invoker instance ('adaptor implementation' - proc)"
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call (positive proc adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# / / / / / / / / / / / / / / / / / / / /
# applied test:
# 	- use Adapter and Implementation
#	facilities in one specification
#	object
#	- deployment + invocation test

# 1) servant

namespace eval ::mSearch {
  ad_proc doSearch {
    -keywords
    -key
    -offset
  } {doSearch's doc} {
    # ns_write returns 1 
    ns_write "<pre>[info vars] invoked</pre>"
  }
} 

# 2) adapter

?+ { ProcAdapter AATreaty-2-mSearch-Adapter \
	 -implements ::template::AATreaty \
	 -using {
	   ::xorb::Method m2 {
	     arg1
	     arg2
	     arg3
	   } {m2's doc} {
	     # ns_write returns 1 
	     ns_write "<pre>[info vars] invoked</pre>"
	   }
	   ::xorb::Method m3 {
	     arg1
	     arg2
	     arg3
	   } {m3's doc} {
	     # ns_write returns 1 
	     ns_write "<pre>[info vars] invoked</pre>"
	   }
	 } -adapts {
	   m1	::mSearch::doSearch
	 }
 
 AATreaty-2-mSearch-Adapter instproc doSearch {
    -arg1
    -arg2
    -arg3
  } {
    next -key $arg1 -keywords $arg2 -offset $arg3 ;# -> ::mSearch::doSearch
  }
} "Declaring ProcAdapter plus implementation elements ('methods')"

?+ {AATreaty-2-mSearch-Adapter deploy} "Deploying 'AATreaty-2-mSearch-Adapter'"

# 3) POSITIVE test -> m1

::xo::cc virtualObject ::template::AATreaty-2-mSearch-Adapter
::xo::cc virtualCall m1
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]

#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} "Creating invoker instance ('AATreaty-2-mSearch-Adapter' - mixed proc adapter)"
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call (positive MIXED proc adaptor test): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# 3a) POSITIVE test -> m2
::xo::cc virtualObject ::template::AATreaty-2-mSearch-Adapter
::xo::cc virtualCall m2
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]

#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} "Creating invoker instance ('AATreaty-2-mSearch-Adapter' - mixed proc adapter)"
#ns_write SER=[[$i invoke] serialize]
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call (positive MIXED proc adaptor test, calling m2): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# 3b) POSITIVE test -> m3

::xo::cc virtualObject ::template::AATreaty-2-mSearch-Adapter
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]

#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} "Creating invoker instance ('AATreaty-2-mSearch-Adapter' - mixed proc adapter)"
?++ {[$i invoke] set __value__} 1 [subst {
  Dispatching invocation call (positive MIXED proc adaptor test, calling m3): [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]).
}]

# # # # # # # # # # # # # # #
# re-set Default policy
# to "public"
::xorb::deployment::Default default_permission public

# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# Access policies
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

test subsection "Invocation access policies"

# / / / / / / / / / / / / /
# Policy test 1:
# - per-implementation defaults
# - private (modifier) primitive
::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

ServantClass instproc servantMethod {
  -arg1:required 
  -arg2:required 
  -arg3:required
} {
  ns_write "<pre>[self]->[self proc]:</pre>"
  ns_write "<pre>arg1=$arg1,arg2=$arg2,arg3=$arg3</pre>"
  return 1
}

?+ {set i [Invoker new]} \
    "Creating invoker instance (Policy test 1)"

::xorb::deployment::Default contains {
  ::xotcl::Object AAImplementation -set default_permission public
}

# negative test
?-- {$i invoke} "::xorb::exceptions::BreachOfPolicyException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), negative (denying) policy check ('public')
}]

# positive test
ServantClass ad_instproc servantMethod {-arg1 -arg2 -arg3} {} {  
  return 1
}
?+ {$i invoke}  [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), positive (granting) policy check ('public')
}]

# - cleanup
set index "::template::ServantClass instproc servantMethod"
set msg ""
catch { nsv_unset api_proc_doc $index } msg
? {nsv_exists api_proc_doc $index} 0 "Cleaning shared array api_proc_doc"
# / / / / / / / / / / / / /
# Policy test 2:
# - per-implementation, per-call rules
# - deny primitive

::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

ServantClass instproc servantMethod {
  -arg1:required 
  -arg2:required 
  -arg3:required
} {
  ns_write "<pre>[self]->[self proc]:</pre>"
  ns_write "<pre>arg1=$arg1,arg2=$arg2,arg3=$arg3</pre>"
  return 1
}

?+ {set i [Invoker new]} \
    "Creating invoker instance (Policy test 2)"

::xorb::deployment::Default contains {
  ::xotcl::Object AAImplementation -array set require_permission {
    m3 	deny
    m1	none
    m2	none
  }
}

# negative test
?-- {$i invoke} "::xorb::exceptions::BreachOfPolicyException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), negative (denying) policy check ('deny')
}]

# / / / / / / / / / / / / /
# Policy test 3:
# - per-implementation, per-call rules
# - login primitive

::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} \
    "Creating invoker instance (Policy test 3)"

::xorb::deployment::Default contains {
  ::xotcl::Object AAImplementation -array set require_permission {
    m3 	login
    m1	none
    m2	none
  }
}

# negative test
?-- {$i invoke} "::xorb::exceptions::BreachOfPolicyException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), negative (denying) policy check ('login')
}]

# positive test
::xo::cc user_id 1
?+ {$i invoke}  [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), positive (granting) policy check ('login')
}]
#cleanup
::xorb::deployment::Default::AAImplementation destroy
# / / / / / / / / / / / / /
# Policy test 4:
# - per-policy defaults
# - isImplementation condition
# - none, login primitives

::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]

?+ {set i [Invoker new]} \
    "Creating invoker instance (Policy test 4)"

::xorb::deployment::Default default_permission \
    {{{{isImplementation ::template::AAImplementation} login} none}}

# negative test
::xo::cc user_id 0
?-- {$i invoke} "::xorb::exceptions::BreachOfPolicyException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), negative (denying) policy check 
  ('isImplementation')
}]

# positive test
::xo::cc user_id 1
?+ {$i invoke}  [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), positive (granting) policy check
  ('isImplementation')
}]


# / / / / / / / / / / / / /
# Policy test 5:
# - per-policy defaults
# - isProtocol condition
# - none, login primitives

::xo::cc virtualObject ::template::AAImplementation
::xo::cc virtualCall m3
set aus  [AnythingUs new \
	      -signature {{-arg1:string -arg2:string -arg3:string}} \
	      -arguments {{-arg1 v1 -arg2 v2 -arg3 v3}}]
::xo::cc virtualArgs [$aus now]
#::xo::cc virtualArgs [list -arg1 v1 -arg2 v2 -arg3 v3]
::xo::cc protocol ::xosoap::Soap

?+ {set i [Invoker new]} \
    "Creating invoker instance (Policy test 5)"

::xorb::deployment::Default default_permission \
    {{{{isProtocol ::xorb::protocols::RemotingPlugin} login} none}}
    

# negative test
::xo::cc user_id 0
?-- {$i invoke} "::xorb::exceptions::BreachOfPolicyException" [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), negative (denying) policy check 
  ('isProtocol')
}]

# positive test 1
::xo::cc user_id 1
?+ {$i invoke}  [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), positive (granting) policy check
  ('isProtocol', condition fulfilled)
}]

# positive test 2
::xo::cc user_id 0
::xo::cc protocol ::xorb::protocols::Tcl
?+ {$i invoke}  [subst {
  Dispatching invocation call: [::xo::cc virtualObject]->[::xo::cc virtualCall]\
      ([::xo::cc virtualArgs]), positive (granting) policy check
  ('isProtocol', condition NOT fulfilled)
}]


::xorb::deployment::Default default_permission public

test subsection "Implementations: unstaging"
#myImplementation mixin add ::xorb::Synchronizable
# / / / / / / / / / / / / / / / / / / /
myImplementation sync -delete

? { db_0or1row impl_deleted \
  [myImplementation subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 0 "Staging: test implementation (id:[myImplementation object_id]) was removed."

# !!!!!!!!!!!!
myImplementation mixin delete ::xorb::Synchronizable
# / / / / / / / / / / / / / / / / / / /

myTreaty mixin add ::xorb::Synchronizable
myTreaty sync -delete

? { db_0or1row contract_deleted \
  [myTreaty subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
 } 0 "Staging: test contract (id:[myTreaty object_id]) was removed."

myTreaty mixin delete ::xorb::Synchronizable

AAImplementation mixin add ::xorb::Synchronizable
AAImplementation sync -delete

? { db_0or1row impl_deleted \
  [AAImplementation subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 0 "Staging: AAImplementation (id:[AAImplementation object_id]) was removed."

AAImplementation mixin delete ::xorb::Synchronizable

AA-2-LC-Adapter mixin add ::xorb::Synchronizable
AA-2-LC-Adapter sync -delete

? { db_0or1row impl_deleted \
  [AA-2-LC-Adapter subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 0 "Staging: AA-2-LC-Adapter (id:[AA-2-LC-Adapter object_id]) was removed."

AA-2-LC-Adapter mixin delete ::xorb::Synchronizable

AA-2-LO-Adapter mixin add ::xorb::Synchronizable
AA-2-LO-Adapter sync -delete

? { db_0or1row impl_deleted \
  [AA-2-LO-Adapter subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 0 "Staging: AA-2-LO-Adapter (id:[AA-2-LO-Adapter object_id]) was removed."

AA-2-LO-Adapter mixin delete ::xorb::Synchronizable

AA-2-LP-Adapter mixin add ::xorb::Synchronizable
AA-2-LP-Adapter sync -delete

? { db_0or1row impl_deleted \
  [AA-2-LP-Adapter subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 0 "Staging: AA-2-LP-Adapter (id:[AA-2-LP-Adapter object_id]) was removed."

AA-2-LP-Adapter mixin delete ::xorb::Synchronizable

AATreaty-2-mSearch-Adapter mixin add ::xorb::Synchronizable
AATreaty-2-mSearch-Adapter sync -delete

? { db_0or1row impl_deleted \
  [AATreaty-2-mSearch-Adapter subst { select * 
  from acs_sc_impls
    where impl_id = $object_id }]
 } 0 "Staging: AA-2-LP-Adapter (id:[AATreaty-2-mSearch-Adapter object_id]) was removed."

AATreaty-2-mSearch-Adapter mixin delete ::xorb::Synchronizable

AATreaty mixin add ::xorb::Synchronizable
AATreaty sync -delete

? { db_0or1row contract_deleted \
  [AATreaty subst { select * 
  from acs_sc_contracts
    where contract_id = $object_id }]
 } 0 "Staging: AATreaty (id:[AATreaty object_id]) was removed."

AATreaty mixin delete ::xorb::Synchronizable


# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# cleanup
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
test section "Cleanup"

db_dml db_cleanup $cleanupSQL

# 2) cleanup objects


if {[::xotcl::Object isobject myTreaty]} {
  myTreaty destroy
}
if {[::xotcl::Object isobject myImplementation]} {
  myImplementation destroy
}

# 3) cleanup cache
set keys [ns_cache names xorb_skeleton_cache *]
foreach k $keys {ns_cache flush xorb_skeleton_cache $k}
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #
# # # # # # # # # # # # # #

ns_write "<p>
<hr>
 Tests passed: [test set passed]<br>
 Tests failed: [test set failed]<br>
 Tests Time: [t1 diff -start]ms<br>
" 