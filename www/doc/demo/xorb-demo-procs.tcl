# # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # #
# # Demo scenarios: xorb interface
# # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # #

namespace eval ::xorb::demo {

  namespace import -force ::xorb::*

  #     ___________________
  #   ,'                   `.
  #  /                       \
  # |  1) New implementation  |
  # |     + existing contract |
  #  \                       /
  #   `._______   _________,'
  #           / ,'
  #          /,'
  #         /'
  # / / / / / / / / / / / / / / / / / / / /
  # - 	an implementation to an existing
  #	contract, not specified in or by
  #	xorb
  # -	Example: FtsContentProvider
  # -	Servant: ::xowiki::CustomPage
  # - 	A simple example that only involves
  # 	Delegates (straight-forward 'aliases')

  # / / / / / / / / / / / / / / / / / / / /
  # Declaring step
  set i [ServiceImplementation new \
	     -name ::xowiki::CustomPage \
	     -implements FtsContentProvider \
	     -by {
	       ::xorb::Delegate datasource -proxies ::xowiki::datasource
	       ::xorb::Delegate url -proxies ::xowiki::url
	     }
	]

  # / / / / / / / / / / / / / / / / / / / /
  # Deploying involves
  # - 	a basic containment check (Is a contract
  #	fully contained/ implemented?)
  # -	Provided, that the containment condition
  #	holds, the implementation will be synchronized
  #	with the backend at a later stage
  # -	in the simplest case, deploy does not
  #	take any additional arguments
  # -	In more complex scenarios, it provides the
  #	the means to (1) add implementation-specific
  #	interceptors to xorb's interceptor chain and/ or
  #	(2) add per-implementation invocation access 
  #	settings (they will be added to the currently
  #	ruling per-instance policy).
  $i deploy

  #     ___________________
  #   ,'                   `.
  #  /                       \
  # |  1a) New Implementation |
  # |   + including servant!  |
  #  \                       /
  #   `._______   _________,'
  #           / ,'
  #          /,'
  #         /'
  # / / / / / / / / / / / / / / / / / / / /
  # - 	A slight variation of Ex. 1
  # - 	It is possible to declare the 
  #	specification object as servant object,
  #	by means of the Method attribute slot
  # -	Example: FtsContentProvider
  # -	Servant: ::xowiki::*
  # -	This requires the explicit naming of
  #	the specification+servant object!
  # -	Impl-specific invocation access info!
  # -	Impl-specific interceptor

  Interceptor TestPageInterceptor \
      -instproc handleRequest {requestObj} {next} \
      -instproc handleResponse {responseObj} {next}

  ServiceImplementation FtsContentProviderTestPageImpl \
	     -name ::xowiki::TestPage \
	     -implements FtsContentProvider \
	     -by {
	       ::xorb::Delegate datasource -proxies ::xowiki::datasource
	       ::xorb::Method url {
		 revision_id:required
	       } {doc} {
		 # render item link
		 return "link"
	       }
	     }
  
  FtsContentProviderTestPageImpl deploy \
      -defaultPermission public \
      -requirePermission {
	datasource	login
	url		none
      } -interceptors {
	::xorb::demo::TestPageInterceptor
      }

  #     ___________________
  #   ,'                   `.
  #  /                       \
  # |  2) New contract        |
  # |                         |
  #  \                       /
  #   `._______   _________,'
  #           / ,'
  #          /,'
  #         /'
  # / / / / / / / / / / / / / / / / / / / /
  # - 	Declaring a new contract
  # - 	Involves a contract specification object
  # -	Example: LightweightSQI
  # -	Argument declaration allows all data types
  #	available in acs_datatypes, and is extended
  #	by plug-ins (xosoap -> xs data types)
 
  ServiceContract LightweightSQI  -defines {
    ::xorb::Abstract synchronousQuery \
	-arguments {
	  targetSessionID:string
	  queryStatement:string
	  startResult:integer
	} -returns "returnValue:string" \
	-description {
	  This method places a query at the target.
	}
    ::xorb::Abstract setResultsFormat \
	-arguments {
	  targetSessionID:string
	  resultsFormat:string
	} -description {
	  This method allows the source to control the format 
	  of the results returned by the target.
	}
    ::xorb::Abstract setQueryLanguage \
	-arguments {
	  targetSessionID:string
	  queryLanguageID:string
	} -description {
	  This method allows the source to control the syntax used 
	  in the query statement by identifying the query language.
	}
  } -ad_doc {
    A lightweight SQI Target specification.
  }

  #     ___________________
  #   ,'                   `.
  #  /                       \
  # |  3) Adapter             |
  # |                         |
  #  \                       /
  #   `._______   _________,'
  #           / ,'
  #          /,'
  #         /'
  # / / / / / / / / / / / / / / / / / / / /
  # - 	Declaring an adapter
  # -	search package as implementation
  #	for LightweightSQI (see Ex. 2)

}


