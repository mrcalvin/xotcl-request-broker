ad_library {
    
  xorb core library
  
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date January 30, 2006
  @cvs-id $Id$
  
}

namespace eval xorb {

  namespace import -force ::xoexception::try
  namespace import -force ::xorb::aux::*
  
  ####################################################
  # Implementing a chain of interceptors + flows
  ####################################################
  
  ::xotcl::Class InterceptorChain -ad_doc {}

  InterceptorChain instproc init args {

    # / / / / / / / / / / / / / / / / / / / / / / / /
    # nest an object into [self] that represents 
    # the mixin-hook for request interceptors ("request flow")
    ::xotcl::Object [self]::RequestFlow -proc handleRequest {requestObj} {
      #my log "---requestObj-4:$requestObj"
      set r $requestObj
      next 
      return $r
    }
    
    # / / / / / / / / / / / / / / / / / / / / / / / / 
    # nest an object into [self] that represents
    # the mixin-hook for response interceptors ("response flow")
    ::xotcl::Object [self]::ResponseFlow -proc handleResponse {responseObj} {
      set r $responseObj 
      next 
      return $r
    }
  }

  InterceptorChain instproc load {config} {
    set c [lsearch -glob -inline \
	       [Configuration allinstances] *$config]
    my log "c=$c,ptree=[::xo::cc getProtocolTree]"
    if {$c ne {}} {
      my log "unfold=[$c unfold]"
      [self]::RequestFlow mixin [$c unfold]
      [self]::ResponseFlow mixin [$c unfold -reverse]
    }
  }

  InterceptorChain instproc handleRequest {requestObj} {
    # / / / / / / / / / / / / / / / / / / / / / / / /
    # initialise a configuration, i.e. linearised sequence,
    # of interceptors
    set config [parameter::get -parameter "interceptor_config"]
    #my log "---reqestObj-3:$requestObj"
    my load [string toupper $config 0 0]
    return [[self]::RequestFlow handleRequest $requestObj]
  }

  InterceptorChain instproc handleResponse {responseObj} {
    return [[self]::ResponseFlow handleResponse $responseObj]
  }

  ####################################################
  # Configurations for the chain of interceptors
  ####################################################

  # / / / / / / / / / / / / / / / / / / / / / /
  # Configuration meta-class

  Class Configuration -superclass Class -parameter {
    {listen "all"}
    {position "1"}
    {protocol "all"}
  } -superclass {
    OrderedComposite
    ::xotcl::Class
  }
  
  # # # # # # # # # # # # # # # # #
  # # recreate fix is needed if 
  # # configurations are set dynamically
  # # (in the regression-test.tcl) or the
  # # like in order to preserve the
  # # structural information of the underlying
  # # ordered composite (i.e. its children)
  # #
  Configuration proc recreate {obj args} {
    my log "---BEFORE:[$obj serialize]"
    if {[$obj exists __children]} {
      set children [$obj set __children]
    }
    next;
    my log "---AFTER:[$obj serialize]"
    if {![$obj exists __children] && [info exists children]} {
      $obj set __children $children
    }
  }

  Configuration proc reverse {input} {
    set temp [list]
    for {set i [ expr [ llength $input ] - 1 ] } {$i >= 0} {incr i -1} {
      lappend temp [ lindex $input $i ]
    }
    return $temp
  }
  Configuration instproc reversedHeritage {} {
    set h [concat [self] [my info heritage]]
    return [[self class] reverse $h]
  }
  Configuration instproc unfold {-reverse:switch} {
    array set mixins [list]
    set l [my reversedHeritage]
    set interceptors [list]
    foreach pre $l {
      if {[$pre istype [self class]]} {
	my log "pre=$pre,mixin-exists?[my array exists mixins]"
	foreach {idx interceptor} [$pre records] {
	  if {[info exists mixins($idx)]} {
	    set item $mixins($idx)
	    set interceptor [lappend item [join $interceptor]]
	  } 
	  set mixins($idx) $interceptor
	}
      }
    }
    # lsort on keys of __mixins__
   foreach idx [lsort -increasing -integer [array names mixins]] {
      eval lappend interceptors $mixins($idx)
    }
    if {$reverse} {
      set interceptors [[self class] reverse $interceptors]
    }
    my log "INTERCEPTORS=$interceptors"
    return $interceptors
  }
Configuration instproc setDefaults {obj} {
    $obj instvar properties
    my log "sclass=[self class],params=[[self class] info parameter]"
    foreach {p dv} [join [[self class] info parameter]] {
      my log "---p:$p,---dv:$dv"
      if {![info exists properties($p)] || $properties($p) eq {}} {
	set properties($p) [my $p]
      } 
    }
    # # # # # # # # # # # #
    # # # # # # # # # # # #
    # # ::xorb::Standard 
    # # restrictions
    # # # # # # # # # # # # 
    # # # # # # # # # # # #
  
    my log "---arr=[array get properties]"
    if {[self] ne "::xorb::Standard"} {
      # position, if 0 then 1
      if {$properties(position) == 0} {
	set properties(position) [my position]
      }
    }
  }
  Configuration instproc records {} {
    array set temp [list]
    #set __children  [lsort -command [list my compare] \
			# -increasing [my info children]]
    my log "---CHILDREN=[my children],[my info children]"
    foreach proxyChild [my children] {
      my setDefaults $proxyChild
      $proxyChild instvar properties interceptor
      my log "---PROPS=[array get properties]"
      set pos $properties(position)
      set listen $properties(listen)
      set protocol $properties(protocol)
      # / / / / / / / / / / / / / / / / 
      # 1) resolve interceptor class
      set child $interceptor
      set gxpr [list]
      # / / / / / / / / / / / / / / / / 
      # 2) introduce mixin guards
      if {$listen ne "all"} {
	lappend gxpr "\[lsearch -glob [list $listen] \[::xo::cc virtualObject\]\] != -1"
      }
      
      if {$protocol ne {}} {
	# hierarchy of protocol plug-ins (starting with current offset)
	# escalate [::xo::cc protocol] -> e.g. Soap / Remote / All
	# hProtocols evaluate at runtime
	lappend gxpr "\[lsearch -glob \[::xo::cc getProtocolTree\] [list *$protocol]\] != -1"
      }
      if {$gxpr ne {}} {
	set child [list "$child -guard [list [join $gxpr { && }]]"]
      }
      my log "---CHILD=$child"
      if {[info exists temp($pos)]} {
	set item $temp($pos)

	set child [lappend item [join $child]]
      }
      set temp($pos) $child
    }
    return [array get temp]
  }

  Configuration instproc compare {a b} {
    my setDefaults $a
    my setDefaults $b
    $a instvar {properties propertiesA}
    $b instvar {properties propertiesB}
    
    set x $propertiesA(position)
    set y $propertiesB(position)
    if {$x < $y} {
      return -1
    } elseif {$x > $y} {
      return 1
    } else {
      return 0
    }
  }

::xotcl::Class Configuration::Element -slots {
  Attribute interceptor
}

# / / / / / / / / / / / / / / / / / / / / / /
# base configuration; only provides for (de-)
# marshalling

  Configuration Standard

  ####################################################
  # Interceptor (Meta-)Class
  ####################################################


  ::xotcl::Class Interceptor -superclass ::xotcl::Class \
      -ad_doc {
	@author stefan.sobernig@wu-wien.ac.at
	@creation-date October 10, 2005     
      }

  ####################################################
  # LoggingInterceptor	
  ####################################################

  Interceptor LoggingInterceptor
  
  LoggingInterceptor instproc handleRequest {requestObj} {
    my log [$requestObj serialize]
    next
  }

  LoggingInterceptor instproc handleResponse {responseObj} {
    my log [$responseObj serialize]
    next
  }

  # / / / / / / / / / / / / / / / / / / / / / /
  # extended configuration; features basic message logging

  Configuration Extended -superclass Standard -contains {
    ::xorb::Configuration::Element new \
	-interceptor ::xorb::LoggingInterceptor \
	-array set properties {
	  listen all
	}
  }

  ####################################################
  # Request Message Handler
  ####################################################

  ::xotcl::Class RequestHandler -superclass InterceptorChain -ad_doc {    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date August 18, 2005 
  }										
  

  RequestHandler ad_instproc init {} {
    Upon intialisation, some credentials are prepared and 
    made instance variables. 
    They will later be used to populate a connection object.
    
    @author stefan.sobernig@wu-wien.ac.at
    @creation-date August 18, 2005
    
    @see xosoap::MessageHandler::preauth
  } {
    # / / / / / / / / / / / / / / / / / / /
    # provide for the chain of interceptor 
    # to be initialised
    next
  }

   RequestHandler ad_instproc handleRequest {requestObj} {} {	
    
    namespace import -force ::xosoap::visitor::*
    #my log "---requestObj-2:$requestObj"
    # / / / / / / / / / / / / / / /
    # 1) preprocessing (CoI)
    # having request processed by 
    # chain of interceptors
    # - demarshalling
    # - ...
    my log "NEXT=[self next]"
    set requestFlowResult [next];#InterceptorChain->handleRequest
    #my log "---requestFlowResult=$requestFlowResult"
    # / / / / / / / / / / / / / / /
    # 2) invocation data extraction
    # InvocationDataVisitor
    # - extract invocation data
    set visitor [InvocationDataVisitor new -volatile]
    $visitor releaseOn $requestFlowResult
    
    # / / / / / / / / / / / / / / /
    # 3) init invoker and dispatch
    
    set invoker [Invoker new -destroy_on_cleanup]
    set r [$invoker invoke]
    
    # / / / / / / / / / / / / / / /
    # 4) process result
    my log AFTER-INVOKE=$r,NEXT-1=[my procsearch handleResponse]
    my handleResponse $requestFlowResult $r
     
  }
  
  RequestHandler ad_instproc handleResponse {responseObj} {} {
    # / / / / / / / / / / / / / / / / / / / / /
    # 4) Pass response to response flow
    my log NEXT-3=[self next]
    set responseFlowResult [next $responseObj]
    #my dispatchResponse $responseFlowResult
    return $responseFlowResult;# protocol-specific mixin->dispatchResponse 
  }

  # template methods, has to be provided by implementations of 
  # protocol plug-ins!
  RequestHandler abstract instproc dispatchResponse {payload}
  RequestHandler abstract instproc unplug {}
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # rhandler
  
  RequestHandler create rhandler

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Base
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  ::xotcl::Class Base -superclass ::xotcl::Class -slots {
    Attribute deleteCmd
    Attribute middle 
    Attribute name -type "my qname" -proc qname {value} {
      # / / / / / / / / / / / /
      # 1) The name may not be set
      # to a autogenerated value,
      # pointing to the xotcl namespace,
      # i.e. spec objects must not be
      # declared by calling 'new'
      # without specifying an explicit 
      # name
      # 2) transform object references
      # (when used as actual 'names') into
      # canonical and valid string format:
      # we replace all '::' by '__'
      if {[string first ::xotcl:: $value] != -1} {
	return 0
      } else {
	# provide for a canonical transformation of '::'
	my uplevel [subst {\$obj set \$var [string map {: _} $value]}]
	return 1
      }
    }
  }
  Base abstract instproc stream {}
  Base instproc getSignature {} {
    return [ns_sha1 [my stream]]
  }
Base instproc slotInfo {option} {
  switch $option {
    "ordered" {
      set ul [list]
      foreach s [my info slots] {
	lappend ul [list [$s name] $s]
      }
      return [join [lsort -index 0 $ul]]
    }
  }
}
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # ServiceContract 
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
# Attribute name -type "my qname" -proc qname {value} {
#       # / / / / / / / / / / / /
#       # The name may not be set
#       # to a autogenerated value,
#       # pointing to the xotcl namespace,
#       # i.e. spec objects must not be
#       # declared by calling 'new'
#       # without specifying an explicit 
#       # name
#       return [expr {[string first ::xotcl:: $value] == -1}]
#     }

  ::xotcl::Class ServiceContract -superclass Base -slots {
    Attribute description -default {}
    Attribute extends
  }

  ServiceContract instforward defines %self slots

  ServiceContract instproc ad_doc {desc} {
    my description $desc
    next 
  }
  ServiceContract instproc init args {
    if {![my exists name] || [my name] eq {}} {
      my name [namespace tail [self]]
    }
    my middle "contract"
    my deleteCmd {acs_sc::${middle}::delete -contract_id $id}
    next
  }
  ServiceContract instproc stream {} {
    my instvar homologues
    set obj [[self] new -volatile]
    set arr(name) [my name]
    set arr(description) [my description]
    set ops [list]
    #my log "orig-line=[lsort [my info slots]]"
    foreach {n s} [my slotInfo ordered] {
      #my log "+++obj-meth=[$obj info methods]"
      #my log "+++s=$s"
      if {[$s istype ::xorb::Abstract]} {
	lappend ops [$obj $n]
      } 
    }
    set arr(operations) [string trim [join $ops]]
    #my log "+++arr=[array get arr]"
    #my log "+++equal?[string equal [array get arr] [array get arr]]"
    return [array get arr]
  }
  
# # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # 
# recreation facility (automated
# sync) for explicitly named
# contract specification objects
#ServiceContract proc recreate {obj args} {
#  next
#  $obj mixin add ::xorb::Synchronizable
#  $obj sync
#  $obj mixin delete ::xorb::Synchronizable
#}

  # only to be called in main thread (upon init), later also upon recreation?
  ServiceContract proc sync {} {
    foreach i [[self] allinstances] {
      my log "SYNC'ING:$i"
      $i mixin add ::xorb::Synchronizable
      $i [self proc]
      $i mixin delete ::xorb::Synchronizable
    }
  }


# / / / / / / / / / / / / / / / / /
# provide after_init hook 
ad_after_server_initialization synchronise_contracts {
  ::xorb::ServiceContract sync
}

  # only to be called in manager thread (upon init)
  ServiceContract proc fetch {
			      -container:required 
			      {-id ""}
			      -recreate:switch
			    } {
    set isRecreation [expr {$id ne {} && $recreate}]
    set sql {
      select distinct ctrs.contract_name,
                      ctrs.contract_id, 
                      ctrs.contract_desc
      from   	      acs_sc_contracts ctrs
    }
    if {$id ne {}} {
      append sql {where     ctrs.contract_id = :id}
    }
     #my log "XXX:here for $container, recreate?$isRecreation"
    db_foreach defined_contracts $sql {
      set c $container
      if {!$isRecreation} {
	set c [[self] new -childof $container] 
      }
      $c mixin add ::xorb::Persistent
      $c id $contract_id 
      $c name $contract_name
      $c description $contract_desc
      $c [self proc]
      if {!$isRecreation} {
	# create registry entry
	$container set items([$c name],[$c id]) $c
      }
      #my log "c=[$c name] ($c) created"
      # # # # # # # # # # # # # # # 
      # leave it in the persistent role?
      # $c mixin delete Persistent
      # # # # # # # # # # # # # # #
     
    }

  }

  ::xotcl::Class Abstract -superclass ::xotcl::Slot -slots {
    Attribute arguments -default {}
    Attribute returns -default {}
    Attribute description
  }

  Abstract instproc get {domain slot} {
    set arr(input) [join [my arguments]]
    set arr(output)  [join [my returns]]
    set arr(description) [string trim [my description]]
    set arrOperation([my name]) [string trim [array get arr]]
    return [string trim [array get arrOperation]]
  }
  
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # ServiceImplementation 
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
  ::xotcl::Class Delegate -superclass ::xotcl::Slot -slots {
    Attribute proxies -type "my qref" -proc qref {value} {
      if {$value eq {}} {
	return 0
      } else {
	my uplevel {$obj set $var [regsub {\s+} $value ::]}
	return 1    
      }
    } 
  }
  
  Delegate instproc init {-selfproxy:switch} {
    if {$selfproxy} {
      my instvar domain
      my proxies "${domain}::__[namespace tail [self]]__" 
    }
    next --noArgs
  }
Delegate instproc get {domain slot} {
    return "[my name] [my proxies]"
  }
  
  Delegate instproc get {domain slot} {
    return "[my name] [my proxies]"
  }
  
  ::xotcl::Class Method -superclass Delegate 
  
Method instproc init {{arguments {}} {doc {}} {body {}} args} {
  my instvar domain
  set dashedArgs [list]
  foreach a $arguments {
    lappend dashedArgs -$a
  }
  set name [namespace tail [self]]
  if {$body ne {}} {
    $domain ad_instproc __${name}__ $dashedArgs $doc $body 
  }
  next -selfproxy
}

# Attribute name -type "my qname" -proc qname {value} {
#       # / / / / / / / / / / / /
#       # The name may not be set
#       # to a autogenerated value,
#       # pointing to the xotcl namespace,
#       # i.e. spec objects must not be
#       # declared by calling 'new'
#       # without specifying an explicit 
#       # name
#       return [expr {[string first ::xotcl:: $value] == -1}]
#     }

  Class ServiceImplementation -superclass Base -slots {
    Attribute implements
    Attribute prettyName -default {}
    Attribute owner -default {}
  
  }
  ServiceImplementation instproc init args {
    if {![my exists name] || [my name] eq {}} {
      my name [namespace tail [self]]
    }
    if {![my exists prettyName] || [my prettyName] eq {}} {
      my prettyName [my name]
    }
    my middle "impl"
    my deleteCmd {acs_sc::${middle}::delete -contract_name $implements -impl_name $name}
    next
  }
ServiceImplementation instforward using %self slots
ServiceImplementation instproc stream {} {
    set obj [[self] new -volatile]
    set arr(name) [my name]
    set arr(pretty_name) [my prettyName]
    set arr(owner) [my owner]
    set arr(contract_name) [my implements]
  set ops [list]
  my log "orig-line=[my slotInfo ordered]"
  foreach {n s} [my slotInfo ordered] {
    #my log "+++s=$s"
    #my log "+++obj-meth=[$obj info methods], call=[$s name]"
    if {[$s istype ::xorb::Delegate]} {
      lappend ops [$obj $n] 
    }
  }
    set arr(aliases) [join $ops]
    return [array get arr]
  }

ServiceImplementation proc recreate {obj args} {
  next;
  # # # # # # # # # # # # 
  # the information whether 
  # a variable is set will be 
  # used by ServiceImplementation->deploy
  # to decide whether to sync instantly
  # or queue the sync in the upon-init
  # batch process!
  $obj set __recreated__ 1
}

# only to be called in manager thread (upon init)
ServiceImplementation proc sync {} {
  my instvar __syncees__
  if {[info exists __syncees__] && [llength $__syncees__] > 0} {
    foreach s $__syncees__ {
      my log "SYNC'ING: $s"
      $s mixin add ::xorb::Synchronizable
      $s [self proc]
      $s mixin delete ::xorb::Synchronizable
    }
  }
}

# / / / / / / / / / / / / / / / / /
# provide after_init hook 
ad_after_server_initialization synchronise_implementations {
  ::xorb::ServiceImplementation sync
}

  ServiceImplementation proc fetch {
	-container:required 
	{-id ""} 
	-recreate:switch
      } {
    set isRecreation [expr {$id ne {} && $recreate}]
    set sql {
      select distinct ia.impl_name, ia.impl_id, impls.impl_pretty_name,
      impls.impl_owner_name,
      impls.impl_contract_name
      from   	acs_sc_bindings binds,
      acs_sc_impl_aliases ia,
      acs_sc_impls impls
      where  	ia.impl_id = impls.impl_id 
    }
    if {$id ne {}} {
      append sql {
	and
	impls.impl_id = :id
      }
    }
    #my log "XXX:here for $container, recreate?$isRecreation"
    db_foreach bound_impls $sql {
      set i $container
      if {!$isRecreation} {
	set i [[self] new -childof $container] 
      }
      $i mixin add ::xorb::Persistent
      $i id $impl_id 
      $i name $impl_name
      $i prettyName $impl_pretty_name
      $i owner $impl_owner_name
      $i implements $impl_contract_name
      $i [self proc]
      if {!$isRecreation} {
	# create registry entry
	$container set items([$i name],[$i id]) $i
      }
      #my log "i=[$i name] ($i) created"
      # # # # # # # # # # # # # # # # 
      # keep persistent role?
      # $i mixin delete Persistent
    }
  }
  

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Basic Interface: IDepository 
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #

  ::xotcl::Class IDepository
  IDepository abstract instproc save args
  IDepository abstract instproc delete args
  IDepository abstract instproc update args

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Mixin: Synchronizable
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
  ::xotcl::Class Synchronizable -superclass IDepository -slots {
    # Repository knows this id as newId
    Attribute id
  }
  Synchronizable instproc update args {
    eval my delete $args
    eval my save $args
  }
  Synchronizable instproc sync {-delete:switch} {
    # clear the state (oldId etc.) from previous syncs
    my clearState
    # continue with new sync
    array set __status__ [my action]
    my log "PRE_ACTION:exists?[info exists __status__(action)]"
    if {[info exists __status__(action)]} {
      set action $__status__(action)
      my log "ACTION([self])=$action"
      my filter notificationFilter
      my id [expr {[info exists __status__(id)]?$__status__(id):{}}]
      if {$delete && $action ne "save"} {
	my delete
      } elseif {$action ne {}} {
	my $action
      }
      my filter delete notificationFilter
    }
    
  }
  Synchronizable instproc save args {
    set spec [my stream]
    if {[my middle] eq "impl"} { 
      my id [::acs_sc::[my middle]::new_from_spec -spec $spec]
    } else {
      # / / / / / / / / / / / / / / / /
      # We now provide our own tcl/db wrapping
      # for storing new contracts, as this
      # is required by the way we use
      # checkoptions to declare and validate
      # an extensible set of types used
      # in protocol plug-ins!
      # NOTE: ::acs_sc::contract::new_from_spec 
      # is no longer used.
      # A point in case for the poor level of
      # re-usability of existing package code,
      # here in terms of extensibility!
      
      # OLD: my id [::acs_sc::[my middle]::new_from_spec -spec $spec]
      my id [my saveContract $spec]
    }
  }

  Synchronizable instproc expandMessageTypeElement {
    msgTypeName 
    element
    idx
  } {
    # / / / / / / / / / / / / / / / / /
    # Includes the necessary changes to 
    # support new type system.
    # The overall code piece is more ore less copied
    # from acs_sc::msg_type::parse_spec

    # / / / / / / / / / / / / / / / / /
    # adaptation (1): being more careful
    # with semicolons being delimiters.
    # Needed when using absolut 
    # object references in type descriptors,
    # for instance.
    set first [string first : $element]    
    set 1 [string range $element 0 [expr {$first-1}]]  
    set 2 [string range $element [expr {$first+1}] end]        
    set elementv [list $1 $2]
    set flagsv [split [lindex $elementv 1] ","]    
    set elementName [string trim [lindex $elementv 0]]
    # old multiple handling
    if { [llength $flagsv] > 1 } {               
      set idx [lsearch $flagsv "multiple"]         
      if { [llength $flagsv] > 2 || $idx == -1 } { 
	error {Only one modified flag allowed, 
	  and that's multiple as in foo:integer,multiple}               
      }               
      # Remove the 'multiple' flag        
      set flagsv [lreplace $flagsv $idx $idx]               
      set elementType "[lindex $flagsv 0]"              
      set isset_p "t"         
    } else {              
      set elementType [lindex $flagsv 0]    
      set isset_p "f"
    }
    # / / / / / / / / / / / / / / / / /
    # adaptation (2): the actual split
    # of the type descriptor into
    # the key element and the extended
    # type info.
    set elementConstraints [db_null]
    ::xorb::datatypes::Anything tokenise $elementType
    if {$typeInfo ne {}} {set elementConstraints $typeInfo}
    # return call script
    return [subst {
      select acs_sc_msg_type__new_element(
            '$msgTypeName',
            '$elementName',
            '$hook',
            '$isset_p',
            '$idx',
            '$elementConstraints'
        );
    }]
  }

  Synchronizable instproc saveContract {spec} {

    array set specification $spec
    set contractName $specification(name)
    set contractDescription $specification(description)

    db_transaction {
      # 1) store contract object
      set id [db_exec_plsql insert_contract {
	select acs_sc_contract__new(
            :contractName,
            :contractDescription
	    );
      }]
      # / / / / / / / / / / / / / / / / / / /
      # operations: we bulk up all necessary
      # pl/pgsql calls and execute them at once
      # per operation.
 
      foreach {operation oInfo} $specification(operations) {
	set sql {}
	# retrieve operation details
	array set oDetails {
	  description {}
	  input {}
	  output {}
	  is_cachable_p "f"
	}
	array set oDetails $oInfo
	# create message type: Input
	set inputTypeName "${contractName}.${operation}.InputType"
	append sql [subst {
	  select acs_sc_msg_type__new(
            '$inputTypeName',
            ''
	    );
      }]
	# create elements of message types
	set inputIdx 0
	foreach element $oDetails(input) {
	  append sql [my expandMessageTypeElement \
			  $inputTypeName \
			  $element \
			  $inputIdx]
	  incr inputIdx
	}
	# create message type: Output
	set outputTypeName "${contractName}.${operation}.OutputType"
      
	append sql [subst {
	  select acs_sc_msg_type__new(
            '$outputTypeName',
            ''
	    );
	}]
	# create elements of message types
	set outputIdx 0
	foreach element $oDetails(output) {
	  append sql [my expandMessageTypeElement \
			  $outputTypeName \
			  $element \
			  $outputIdx]
	  incr outputIdx
	}
	# finally, sum up by creating the operation itself
	set desc $oDetails(description) 
	set icp $oDetails(is_cachable_p)
	append sql [subst {
	  select acs_sc_operation__new(
            :contractName,
            :operation, 
            :desc,
            :icp,
            :inputIdx,
            :inputTypeName, 
            :outputTypeName
	    );
	}]
	# 2) execute bulk call per operation
	my log SQL=$sql
	db_exec_plsql insert_operation $sql
      }
    }
    # TODO: add exception handling
    my log ID=$id
    return $id
  } 

  Synchronizable instproc delete args {
    my instvar id
    if {[info exists id] && $id ne {}} {
      eval [my subst [my deleteCmd]]
      my setState oldId $id
    }
  }

  Synchronizable instproc action {} {
    my log "==orig-stream==> [my stream]"
    set sig [my getSignature]
    return [::XorbManager do ::xorb::manager::Repository getAction [my info class] [my name] $sig] 
  }
  Synchronizable instproc setState {key value} {
    my instvar __state__
    set __state__($key) $value
  }
  Synchronizable instproc getState {key} {
    if {[my exists __state__($key)]} {
      my instvar __state__
      return $__state__($key)
    }
  }
  Synchronizable instproc clearState {} {
    if {[my array exists __state__]} {
      my array unset __state__
    }
  }

  Synchronizable instproc notificationFilter args {
    set cp [self calledproc]
    set sp [self callingproc]
    
    # pre-observer
    set r [next]
    # post-observer
    # --- notification
    set c [[self class] info superclass]
    if {[lsearch -exact [$c info instprocs] $cp] != -1} {
      set newId [expr {[my exists id]?[my id]:""}]
      set oldId [my getState oldId]
      if {$newId == $oldId} {
	set newId ""
      }
      #my log "++cp++$cp,++sp++$sp,++c++$c,inst=[$c info instprocs]"
      #my log "+++oldId=$oldId,newId=$newId, sp=$sp, cp=$cp"
      if {$sp ne "update"} {
	#my log "forwarding XorbManager do ::xorb::manager::Repository event $cp [my info class] $oldId $newId"
	eval XorbManager do ::xorb::manager::Repository event $cp [my info class] $oldId $newId  
      }
    }
    return $r
  }

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Mixin: Persistent
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #

  ::xotcl::Class Persistent -slots {
    Attribute id
    Attribute bindings
  } -instproc fetch {} {
    set m [namespace tail [my info class]]
    if {[my info methods $m] == $m} {
      my $m
    }  
  }

  Persistent instproc ServiceContract {} {
    my instvar id
    db_foreach ops_for_contract {
      select	ops.operation_id, ops.operation_name, ops.operation_desc  
      from   	acs_sc_operations ops
      where  	ops.contract_id = :id
    } {
      my slots "::xorb::Abstract new -name $operation_name -description [list $operation_desc] -mixin [self class] -id $operation_id" 
    }
    foreach s [my info slots] {
      $s fetch
      $s mixin delete [self class]
    }
  }
  
  Persistent instproc Abstract {} {
    my instvar id 
    set arr(InputType) arguments
    set arr(OutputType) returns
    array set r [list]
    db_foreach select_sigelements_for_op {
      
      select	msgs.msg_type_id, msgs.msg_type_name
      from   	acs_sc_operations ops,
      acs_sc_msg_types msgs
      where  	ops.operation_id = :id
      and		(ops.operation_inputtype_id = msgs.msg_type_id
			 or ops.operation_outputtype_id = msgs.msg_type_id)
      
    } {
      set r([lindex [split $msg_type_name "."] 2]) $msg_type_id      
    }
    foreach {type id} [array get r] {
      set s $arr($type)
      my fetch[string toupper $s 0 0] $r($type)    
    }
  }

  Persistent instproc fetchArguments {id} {
    
    if {$id ne {}} {
      set value [list]
      db_foreach select_args {
	select	el.element_name, msgs.msg_type_name, el.element_msg_type_isset_p, el.element_constraints
	from   	acs_sc_msg_type_elements el,acs_sc_msg_types msgs
	where  	el.msg_type_id = :id
	and	el.element_msg_type_id = msgs.msg_type_id
	order by el.element_pos ASC
      } {
	
	if {$element_constraints ne [db_null]} {
	  set msg_type_name "$msg_type_name$element_constraints"
	}
	lappend value $element_name:$msg_type_name
      }
      #my log "+++id=$id;value=[join $value];next=[self next]"
      my arguments [join $value]
    }
  }
  
  Persistent instproc fetchReturns {id} {
    
    if {$id ne {}} {
      set value [list]
      db_foreach select_rtv {
	select	el.element_name, msgs.msg_type_name, el.element_pos, el.element_msg_type_isset_p, el.element_constraints 
	from   	acs_sc_msg_type_elements el,acs_sc_msg_types msgs
	where  	el.msg_type_id = :id
	and	el.element_msg_type_id = msgs.msg_type_id
	order by el.element_pos ASC
      } {
	if {$element_constraints ne [db_null]} {
	  set msg_type_name "$msg_type_name$element_constraints"
	}
	lappend value $element_name:$msg_type_name
      }
      #my log "+++id=$id;value=[join $value];next=[self next]"
      my returns [join $value]
    }
  }

  Persistent instproc ServiceImplementation {} {
    my instvar id
    db_foreach select_aliases_for_impl {
      select 	al.impl_operation_name,al.impl_alias
      from	acs_sc_impl_aliases al
      where 	al.impl_id = :id
    } {
      my slots "::xorb::Delegate new -name $impl_operation_name -proxies $impl_alias"
    }
  }

  ::xotcl::Class Persistent::Recreate -instproc recreate {obj args} {
    # get all implementations bound in the old state
    set oldId [$obj id]
    set newId [lindex $args 0]
    set repos [$obj info parent]
    #my log "obj=$obj,args=$args,oldId=$oldId,newId=$newId"
    # if {[$obj istype ServiceContract]} {
    #  # / / / / / / / / / / / / / / / / / /
    # # get current bindings
    #$obj instvar id
    #      set sql {
    #	select impl_id 
    #	from acs_sc_bindings 
    #	where contract_id = :id
    #     }
    #    set __bindings__ [db_list current_bindings $sql] 
    #     my log "stored bindings=$__bindings__"
    #}
    # / / / / / / / / / / / / / / / / / /
    # get current repository entry -> items array
    #my log "RECREATE=>next=[self next], oldId=$oldId, newId=$newId"
    next
    # new state
    [$obj info class] fetch -recreate -container $obj -id $newId
    # / / / / / / / / / / / / / / / / / /
    # set new repository item -> items array
    $repos instvar items
    set items([$obj name],[$obj id]) $obj
    #my log "==repository-update==> item '[$obj name],$oldId' replaced by '[$obj name],[$obj id]'"
    # / / / / / / / / / / / / / / / / / /
    # re-inject bindings (TODO: re-publish -> conformance check?)
    # foreach <i> conforms <yes> | <no> => <yes> => update 
    ::xorb::manager::Broker event update [$obj info class] $oldId $newId
    # / / / / / / / / / / / / / / /  
    # clear items from old entry
    unset items([$obj name],$oldId)
    # / / / / / / / / / / / / / / /
    # clear skeleton cache; new skeleton
    # will be acquired lazily
    #my log "BEFORE-CLEAR"
    ::xorb::SkeletonCache remove [$obj name]
    #my log "AFTER-CLEAR"
  } 

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Factory / Mixin: Skeleton
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #

  ::xotcl::Class Skeleton -set lightweight 0
  
  Skeleton proc getContract {-lightweight:switch -name:required} {
    try { 
      array set stream [XorbManager do \
			    ::xorb::manager::Broker stream \
			    -what ServiceContract \
			    -conditions Boundness \
			    -contract $name] 
      my set lightweight $lightweight
      # contract obj
      Abstract instmixin add [self]
      eval $stream(contract)
      Abstract instmixin delete [self]
      
      if {$lightweight} {
	my clearVars [self]::$name
	[self]::${name}::slot destroy
      }
      
      #/ / / / / / / / / / /
      # provide for cleanup
      [self]::$name mixin {}
      [self]::$name destroy_on_cleanup

    } catch {error e} {
      error [::xorb::exceptions::SkeletonGenerationException new \
		 "contract: $name, msg: $e"]
    }

    return [self]::$name
    
  }

  Skeleton proc getImplementation {-lightweight:switch -name:required} {
    try { 
      array set stream [XorbManager do \
			    ::xorb::manager::Broker stream \
			    -what ServiceImplementation \
			    -conditions Boundness \
			    -impl $name] 
      #my log "stream=[array get stream]"
      my set lightweight $lightweight
      # contract obj
      Delegate instmixin add [self]
      eval $stream(impl)
      Delegate instmixin delete [self]
      
      if {$lightweight} {
	my clearVars [self]::$name
	[self]::${name}::slot destroy
      }
      
      #/ / / / / / / / / / /
      # provide for cleanup
      [self]::$name mixin {}
      [self]::$name destroy_on_cleanup

    } catch {Exception e} {
      #rethrow
      error $e
    } catch {error e} {
      global errorInfo
      error [::xorb::exceptions::SkeletonGenerationException new \
		 "impl: $name, msg: $errorInfo"]
    }
    return [self]::$name
  }

  Skeleton proc generate {{-contract ""} -impl:required} {
    try {

      #set implObj [my getImplementation -lightweight -name $impl]
      set implObj [my getImplementation -name $impl]
      #my log "ser=[$implObj serialize]"
      #set contractObj [my getContract -lightweight -name [$implObj implements]]
      set contractObj [my getContract -name [$implObj implements]]
      my log "SER=[$contractObj serialize]"
      
      # TODO: contract class as mixin or instmixin?
      set skeletonObj [$implObj new -mixin $contractObj] 
      
    } catch {Exception e} {
      error [::xorb::exceptions::SkeletonGenerationException new \
 		 "contract: $contract, impl: $impl, msg: [$e message]"]
    } catch {error e} {
      global errorInfo
      error [::xorb::exceptions::SkeletonGenerationException new \
 		 "contract: $contract, impl: $impl, msg: $errorInfo"]
    }

    if {[info exists skeletonObj]} {
      return $skeletonObj
    }
  }
  Skeleton proc clearVars {obj} {
    foreach v [$obj info vars] {
      if {$v ne "implements" && $v ne "registry"} {
	$obj unset $v 
      }
    }
  }
  Skeleton instproc destroy {} {
    foreach m [my info mixin] {
      $m destroy
    }
    next
  }
  Skeleton instproc init args {
    my instvar __skeleton__
    [self class] instvar lightweight
    set __skeleton__ [my set domain]
    set target [namespace tail [my info class]]
    my $target
    
    # / / / / / / / / / / / / / / /
    # clear from slot object
    if {$lightweight} {
      my destroy
    }
  }
  Skeleton instproc Abstract args {
    my instvar __skeleton__
    set arguments [list]
    foreach arg [my arguments] {
      # / / / / / / / / / / / / / / / /
      # TODO: default to 'required' or
      # leave it to the declaration?
      lappend arguments -$arg,required
    }
   
    my log HERE
    $__skeleton__ instproc [my name] $arguments [subst {
      # / / / / / / / / / / / / / / / /
      # a generic container for storing
      # validated, uplifted values of 
      # anythings
      # see Class Anything::CheckOption+Uplift
      # in xorb-datatypes-procs.tcl
      array set uplift \[list\]
      set r \[eval next \[array get uplift\]\]
      [expr {[my exists __rvc_call__]?\
		 [subst { ::xoexception::try {
		   set r \[[my set __rvc_call__] \$r\]
		 } catch {error e} {
		   error \[::xorb::exceptions::ReturnValueTypeMismatch new \$e\]
		 }}]:""}]
      return \$r
    }]
  }
  Skeleton instproc Delegate args {
    my instvar __skeleton__
    eval $__skeleton__ instforward [my name] [my proxies]
  }

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Class: ReturnValueChecker
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
  ::xotcl::Class ReturnValueChecker -proc __require__ {context} {
    if {![::xotcl::Object isobject ${context}::rvc]} {
      [self] create ${context}::rvc
    } 
    return ${context}::rvc
  }
  ReturnValueChecker instproc Abstract args {
    my instvar __skeleton__
    # / / / / / / / / / / / / / /
    # provide for return value
    # verification
    if {[my returns] ne {}} {
      set rvc [ReturnValueChecker __require__ $__skeleton__]
      $rvc __add__\
	  -call [my name]\
	  -declaration [my returns]
      set npLabel [lindex [split [my returns] :] 0]
      my set __rvc_call__ [concat $rvc [my name] -$npLabel]
    }
    next;# Skeleton->Abstract
  }
  ReturnValueChecker instproc __add__ {
    -call:required
    -declaration:required
  } {
    if {$declaration ne {}} {
      foreach d $declaration {
	lappend nargs -$d
      }
      my proc $call [join $nargs] {
	# / / / / / / / / / / / /
	# provide for the repackaging
	# of the return value(s) as
	# anythings
	# TODO: multiple values/ anythings
	if {[info exists returnObjs]} {
	  return $returnObjs 
	}
      }
    }
  }

  # - - - - enable - - - -
  Skeleton instmixin add ReturnValueChecker
  
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Class: ServantAdapter
  # - provide for argument conversion (if necessary)
  # - attach lifecycle manager to servant
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
  ::xotcl::Class ServantAdapter \
      -instproc Delegate args {
	my instvar __skeleton__ 
	set servant [my proxies]
	set declaration [[self class] getDeclaration $servant]
	
	# / / / / / / / / / / / /
	# provide for activation
	# record(s)
	set qservant [[self class] getCanonical $servant]
	set __type__ [[self class] identify $servant]
	# keep information from spec object in skeleton obj for
	# later use (in policy validation, for instance)
	$__skeleton__ set registry([my name]) [list $qservant $__type__]
	# - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	set isLifecycled 0
	if {$__type__ eq "1" || $__type__ eq "2" || $__type__ eq "3"} {
	  # servant is either object or class
	  # activation / lifecycling is applicable
	  set s [namespace qualifiers $qservant]
	  set m [namespace tail $qservant]
	  set isLifecycled 1
	  [my info class] slot proxies mixin add ::xotcl::Slot::Nocheck
	  my proxies [concat $s $m]
	  [my info class] slot proxies mixin delete ::xotcl::Slot::Nocheck
	 }

	$__skeleton__ instproc [my name] args [subst {
	  set d [concat \[list $declaration\]]
	  ::xoexception::try {
	    if {\$d ne {} && \[string first - \$d\] == -1 && \
		    \[string first - \$args\] != -1} {
	      array set arr \$args
	      set nargs \[list\]
	      foreach a \$d {
		lappend nargs \$arr(-\$a)
	      }
	    } 
	    [expr {$isLifecycled?[subst {
	      # activate
	      $s mixin add [self class]::LifeCycleManager;
	      $s __activate__;
	    }]:""}]
	  
	    # enforce ruling deployment policy
	    # TODO: when called from protocol plug-in
	    # package, it cannot resolve the context
	    # of the broker package and therefore
	    # not retrieve the package parameters!
	    # set rulingPolicy \[parameter::get -parameter "per_instance_policy"\]
	    # simple solution: add package param to xotcl-soap etc.
	    # but what does this mean for brokerage in general
	    # (when a simple acs::sc::invoke is called from within the sphere
	    # of other packages?)
	    set rulingPolicy ::xorb::deployment::Default
	    my log rulingPolicy=\$rulingPolicy
	    set p \[\$rulingPolicy check_permissions $__skeleton__ \[self proc\]\]
	    if {\$p} {  
	      ::xoexception::try {
		set r \[eval my __[my name] \[expr { 
		\[info exists nargs\]?\$nargs:\$args 
		}\]\] 
	      } catch {Exception e} {
		error \$e
	      } catch {error e} {
		global errorInfo
		error \[::xorb::exceptions::ServantDispatchException new \
		    "Dispatching call [my name] to servant failed: \$errorInfo"\]
	      }
	      
	    } else {
	      error \[::xorb::exceptions::BreachOfPolicyException new "[subst {
		Invoking on '$qservant' through '${__skeleton__}->[my name]' is
		not permitted under the ruling access policy ('\$rulingPolicy').
	      }]"\]
	    }
	    
	    [expr {$isLifecycled?[subst {
	      # deactivate
	      $s __deactivate__;
	      $s mixin delete [self class]::LifeCycleManager;
	    }]:""}]
	  } catch {Exception e} {
	    #rethrow
	    my log "---PERROR=\[\$e message\]"
	    error \$e
	  } catch {error e} {
	    global errorInfo
	    error \[::xorb::exceptions::ArgumentTransformationException\
		new \$errorInfo\]
	  }
	  if {\[info exists r\]} {
	    # return result
	    return \$r
	  }
	}]
	my name __[my name]
	next;# Skeleton->Delegate
      }\
      -proc getCanonical {noncanonical} {
	regsub {\s+} $noncanonical :: canonical
	return $canonical
      }\
      -proc getDeclaration {servant} {
	set servant [my getCanonical $servant]
	set type [my identify $servant]
	set obj [namespace qualifiers $servant]
	set p [namespace tail $servant]
	switch -- $type {
	  0 { return [info args $servant] }
	  1 {
	    if {[$obj istype ::xorb::Adapter]} {
	      return {}
	    } else {
	      return [concat [$obj info nonposargs $p] [$obj info args $p]]
	    }
	  }
	  2 {
	    if {[$obj istype ::xorb::Adapter]} {
	      return {}
	    } else {
	      return [concat [$obj info instnonposargs $p] \
			[$obj info instargs $p]]
	    }
	  }
	  -1 {error [::xorb::exceptions::SkeletonGenerationException new \
			 [subst {
			   The servant ($servant) could not be resolved 
			   as valid type (proc, object, class). It might not
			   even exist.}]]
	  }
	}
      }\
      -proc identify {servant} {
	# / / / / / / / / / /
	# provide for canonical
	# reference
	set servant [my getCanonical $servant]
	set parent [namespace qualifiers $servant]
	set tail [namespace tail $servant]
	if {[info procs $servant] ne {} \
		&& ![::xotcl::Object isobject $parent]} {
	  # servant is pure tcl proc or ad_proc
	  return 0
	} elseif {[::xotcl::Object isobject $parent] && \
		      ([info procs $servant] ne {} || \
			   [$parent istype ::xorb::ObjectAdapter] || \
			   [$parent istype ::xorb::ProcAdapter])} {
	  # servant is ::xotcl::Object->proc
	  return 1
	} elseif {[::xotcl::Object isclass $parent] && \
		       ([$parent info instprocs $tail] ne {} || \
			    [$parent istype ::xorb::ClassAdapter])} {
	  # servant is ::xotcl::Class->instproc
	  return 2
	} else {
	  # non-identifiable servant
	  return -1;
	}
      }
  
  Skeleton instmixin add ServantAdapter

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Mixin: LifeCycleManager
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
  ::xotcl::Class ServantAdapter::LifeCycleManager
  ServantAdapter::LifeCycleManager instproc __dispatch__ {mode} {
    ::xoexception::try {
      set type Object
      if {[::xotcl::Object isclass [self]]} {
	set type Class
      }
      set mode [string trim $mode __]
      my $mode$type 
    } catch {error e} {
      error [::xorb::exceptions::LifeCycleException new \
		 [subst {
		   Mode '$mode' for '[self]' (type=$type) failed.}]]
    }
  }
  ServantAdapter::LifeCycleManager instproc __activate__ args {
      my __dispatch__ [self proc]
  }
  ServantAdapter::LifeCycleManager instproc __deactivate__ args {
    my __dispatch__ [self proc]
  }
  
  # # # # # # # # # # # # # # # # 
  # default activation (Object, Class)
  
  ServantAdapter::LifeCycleManager instproc activateClass args {
    set class [self]
    # replace Class->unknown for the time of invocation
    $class proc unknown {method args} {
      set flyingServant [my new -childof [self] -volatile]
      eval $flyingServant $method $args
    }
    next
  }
  
  ServantAdapter::LifeCycleManager instproc activateObject args {
    # no default activation
  }

  # # # # # # # # # # # # # # # # 
  # default deactivation (Object, Class)
  
  ServantAdapter::LifeCycleManager instproc deactivateClass  args {
    set class [self]
    $class proc unknown {} {} 
    next
  }
  
  ServantAdapter::LifeCycleManager instproc deactivateObject args {
    # no default deactivation
  }
  
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Mixin: SkeletonCache
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #

  ::xotcl::Class SkeletonCache
  # / / / / / / / / / / / / / / / /
  # In case of cached skeleton objects
  # we need to avoid initialisation of
  # slot objects so skeleton methods
  # are not overwritten; this is not needed
  # if we use lightweight mode, however,
  # we avoid that mode to be able to use
  # use cached skeleton objects for 
  # wsdl etc. generation
::xotcl::Class SkeletonCache::Abstract -instproc init args {}
::xotcl::Class SkeletonCache::Delegate -instproc init args {}

  SkeletonCache proc remove {key} {
    #my log "Cache clearing called (key=$key)"
    ns_cache flush xorb_skeleton_cache ::xorb::Skeleton::$key
  }
  SkeletonCache instproc getContract {
    -lightweight:switch
    -name:required
  } {
    #my log "CACHE-BEFORE: [ns_cache names xorb_skeleton_cache]"
    #set suffix -[expr {$lightweight?"light":"heavy"}]
    set value [ns_cache eval xorb_skeleton_cache [self]::$name {
      set obj [next]
      set cl [$obj info class]
      set code [::Serializer deepSerialize $obj]
      #my log "serialised+stored ([string bytelength $code]): $code"
      return $code
    }]
    #my log "CACHE-AFTER: [ns_cache names xorb_skeleton_cache]"
    if {![info exists obj]} {
      #my log "ALREADY STORED: follow-up call"
      if {![my isobject [self]::$name]} {
	#my log "OBJECT does not exist: eval $value"
	# / / / / / / / / / / / / / / / /
	# In case of cached skeleton objects
	# we need to avoid initialisation of
	# slot objects so skeleton methods
	# are not overwritten; this is not needed
	# if we use lightweight mode, however,
	# we avoid that mode to be able to use
	# use cached skeleton objects for 
	# wsdl etc. generation
	Abstract instmixin add [self class]::Abstract
	eval $value
	Abstract instmixin delete [self class]::Abstract
	[self]::$name destroy_on_cleanup
      }
      return [self]::$name
    } else {
      #my log "NOT STORED: first-time call"
      return $obj
    }
    
  }
   SkeletonCache instproc getImplementation {
    -lightweight:switch
    -name:required
  } {
    #set suffix -[expr {$lightweight?"light":"heavy"}]
    #my log "CACHE-BEFORE: [ns_cache names xorb_skeleton_cache]"
    set value [ns_cache eval xorb_skeleton_cache [self]::$name {
      set obj [next]
      set cl [$obj info class]
      set code [::Serializer deepSerialize $obj]
      #my log "serialised+stored ([string bytelength $code]): $code"
      return $code
    }]
    #my log "CACHE-AFTER: [ns_cache names xorb_skeleton_cache]"
    if {![info exists obj]} {
      #my log "ALREADY STORED: follow-up call"
      if {![my isobject [self]::$name]} {
	#my log "OBJECT does not exist: eval $value"
	# / / / / / / / / / / / / / / / /
	# In case of cached skeleton objects
	# we need to avoid initialisation of
	# slot objects so skeleton methods
	# are not overwritten; this is not needed
	# if we use lightweight mode, however,
	# we avoid that mode to be able to use
	# use cached skeleton objects for 
	# wsdl etc. generation
	Delegate instmixin add [self class]::Delegate
	eval $value
	Delegate instmixin delete [self class]::Delegate
	[self]::$name destroy_on_cleanup
      }
      return [self]::$name
    } else {
      #my log "NOT STORED: first-time call"
      return $obj
    }
    
  }

  Skeleton mixin SkeletonCache

  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  # Class: Invoker
  # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # #
  
  ::xotcl::Class Invoker -parameter {
    impl
    call
    {arguments {}}
    skeleton
  }

  Invoker instproc init args {
    my instvar impl call arguments \
	skeleton
    # / / / / / / / / / / / / / / / / / /
    # 1) invocation data
    set impl [::xo::cc virtualObject]
    set call [::xo::cc virtualCall]
    set arguments [list]

    # / / / / / / / / / / / / / / / / / /
    # 1a) handle anythings
    
    foreach any [::xo::cc virtualArgs] {
      lappend arguments -[$any name] $any
    }
    
    if {$call eq {}} {
      error [::xorb::exceptions::InvocationException new \
		"No virtual call is specified in invocation request"]
    }

    # / / / / / / / / / / / / / / / / / /
    # 2) resolve skeleton
    set skeleton [Skeleton generate -impl $impl]
    if {![::xotcl::Object isobject $skeleton]} {
      error [::xorb::exceptions::InvocationException new \
		 "Skeleton for '$impl' could not be materialised"]
    }
  }

  Invoker instproc invoke {} {
    my instvar skeleton call arguments
    try {
      # / / / / / / / / / / / / /
      # TODO: set context for actual
      # invocation
      my log "NEXT=[$skeleton procsearch $call],arguments=$arguments"
      ::xotcl::nonposArgs mixin add \
	  ::xorb::datatypes::Anything::CheckOption+Uplift
      set result [eval $skeleton $call $arguments]
      ::xotcl::nonposArgs mixin delete \
	  ::xorb::datatypes::Anything::CheckOption+Uplift
      # / / / / / / / / / / / / /
      # TODO: remove context for actual
      # invocation
    } catch {Exception e} {
      # re-throw
      my log "---IERROR: [$e message]"
      error $e
    } catch {error e} {
      global errorInfo
      error [::xorb::exceptions::InvocationException new \
		 [subst {
		   Call '$call' on '$skeleton' ([$skeleton info class]) 
		   with args '$arguments' failed due to '$errorInfo'}]]
    }
    if {$result ne {}} {
      return $result
    }
  }
    
  namespace export ServiceContract ServiceImplementation Abstract \
      Delegate Method Synchronizable Persistent IDepository Skeleton \
      Invoker ServantAdapter ReturnValueChecker Configuration InterceptorChain \
      Standard Interceptor LoggingInterceptor Extended RequestHandler rhandler \
      
}

