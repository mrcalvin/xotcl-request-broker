ad_library {
  
  Providing for (remoting) invocation contexts, based upon 
  the xotcl-core's context framework.

  @author stefan.sobernig@wu-wien.ac.at
  @creation-date 2007-01-25
  @cvs-id $Id$
}

namespace eval ::xorb::context {
  namespace import -force ::xoexception::try

  # # # # # # # # # # # # # #
  # # # # # # # # # # # # # #
  # # Generic extensions
  # # to ConnectionContext
  # # as it comes with 
  # # xotcl-core
  # # # # # # # # # # # # # #
  # # # # # # # # # # # # # #
  
  ::xo::ConnectionContext slots {
    Attribute httpMethod -default GET
  }

  ::xo::ConnectionContext instproc isGet {} {
    my instvar httpMethod
    return [expr {$httpMethod eq "GET"}]
  }

  ::xo::ConnectionContext instproc isPost {} {
    my instvar httpMethod
    return [expr {$httpMethod eq "POST"}]
  }

  # / / / / / / / / / / / / / / / / / / / / / / / / / / 
  # To avoid the escalation of the class tree and
  # keep the two concerns of invocation contexts seperated 
  # (i.e. provider-side vs. consumer-side / generic vs.
  # protocol-specific), we introduce a variation of
  # the TYPE OBJECT pattern for invocation data objects.
  # see Riehle et al. (2007): "Dynamic Object Model", 
  # in: PLPD 5, Addison-Wesley
  # - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # We, however, provide for slight adaptations,
  # involving behaviour sharing from type objects to the
  # component. Also, we use native XOTcl concepts to achieve
  # a more flexible design ...
  # - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # While the InvocationInformationType and its sub-classes
  # represent the protocol-specific concern, the basic 
  # InvocationInformation class tree realises provider- 
  # or consumer-side.

  # / / / / / / / / / / / / / / / / / / / / /
  # Class InvocationInformationType
  # - - - - - - - - - - - - - - - - - - - - - 
  # `- takes the role of the 'ComponentType' in the 
  # TYPE OBJECT structure
  Class InvocationInformationType -slots {
    Attribute name
  }

  # / / / / / / / / / / / / / / / / / / /
  # Basic 'invocation context' interface
  # - - - - - - - - - - - - - - - - - - -

  InvocationInformationType instproc setContext {key value} {
    my set context($key) $value
  }

  InvocationInformationType instproc getContext {key} {
    my instvar context
    if {[info exists context($key)]} {
      return $context($key)
    }
  }

  InvocationInformationType instproc contextExists {key} {
    my instvar context
    my debug EXISTS=[my serialize]
    return [info exists context($key)]
  }

  InvocationInformationType instproc clearContext {} {
    my instvar context
    array unset context
  }
 

  # / / / / / / / / / / / / / / / / / / / / /
  # Class InvocationInformation
  # - - - - - - - - - - - - - - - - - - - - - 
  # `- takes the role of the 'component' in the 
  # TYPE OBJECT structure

  ::xotcl::Class InvocationInformation -slots {
    # / / / / / / / / / / / / / / / / / / / / /
    # Being the 'component', each instance
    # refers to its type object by association
    # through contextType:
    Attribute informationType \
	-type ::xorb::context::InvocationInformationType
    # - - - - - - - - - - - - - - - - - - - - - 
    # Attributes shared by all invocation contexts
    # in the scope of both concerns.
    Attribute virtualObject
    Attribute virtualCall
    Attribute virtualArgs
    Attribute marshalledRequest
    Attribute marshalledResponse
    Attribute unmarshalledRequest
    Attribute unmarshalledResponse
    Attribute result
    Attribute proxy
    # only temporarily!
    Attribute asynchronous -default false
    # / / / / / / / / / / / / / / / / / / / / /
    # Candidates for being moved to
    # the basic InvocationInformationType class
    Attribute protocol -default ::xorb::AcsSc
    Attribute package -default {[::xorb::Package require]}
  }

  InvocationInformation instproc init args {
    # -- provide for type object acquisition,
    # in case, the typefilter has not taken
    # care of it at that point ...
    my acquireTypeObject
    next
  }

  InvocationInformation instproc acquireTypeObject {} {
    my instvar informationType
    if {![info exists informationType]} {
      set c [my info class]
      if {[$c exists __informationType]} {
	set informationType [[$c set __informationType] new -childof [self]]
      }
    }
  }

  # / / / / / / / / / / / / / / / / / /
  # type-object delegation by using
  # XOTcl per-instance filters ...
  
  InvocationInformation instproc typeFilter args {
    set cp [self calledproc]
    if {[my procsearch $cp] eq {}} {
      my acquireTypeObject
      if {[[my informationType] procsearch $cp] ne {}} {
	return [eval [my informationType] $cp $args]
      }
    }
    uplevel [list next]
  }

  InvocationInformation instfilter typeFilter

  # / / / / / / / / / / / / / / / / / /
  # solution based on unknown
  # - - - - - - - - - - - - - - - - - - 
  # Context instproc unknown {m args} {
  #  my instvar contextType
  #  if {[info exists contextType] && \
      #	  [my isobject $contextType] && \
      #	  [$contextType procsearch $m] ne {}} {
  #    return [eval $contextType $m $args]
  #  } else {
  #    error "Unable to dispatch to a method '$m'."
  #  }
  #}

  # / / / / / / / / / / / / / / / / / /
  # Some uniform interface for 
  # introspecting on the invocation
  # informations >shared< state ...

  InvocationInformation instproc isSet {attribute} {
    my instvar informationType
    my debug INFO=[::Serializer deepSerialize [self]]
    return [expr {[my exists $attribute] || \
		      [$informationType exists $attribute] || \
		      [my array exists $attribute] || \
		      [$informationType array exists $attribute]}]
  }

  InvocationInformation instproc clone {reference} {
    my copy $reference
    # -- adjust infotype reference
    set typeObject [my informationType]
    $reference informationType \
	[string map  [list [self] $reference] $typeObject]
    my debug CLONE=[::Serializer deepSerialize $reference]
    return $reference
  }

  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / / / / / /

  # / / / / / / / / / / / / / / / / / /
  # Concern: provider vs. consumer
  # - - - - - - - - - - - - - - - - - -
  # `- consumer side is realised by
  # ::xorb::stub::ContextObject ...

  ::xotcl::Class ProviderInformation -slots {
    # / / / / / / / / / / / / / / / / / /
    # TODO: candidate for removal?
    # Attribute method
    # - - - - - - - - - - - - - - - - - -
    Attribute transport -default ""
  } -superclass InvocationInformation

  namespace export InvocationInformation InvocationInformationType \
      ProviderInformation
}