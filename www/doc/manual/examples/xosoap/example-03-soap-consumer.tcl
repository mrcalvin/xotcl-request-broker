# -) prerequisites
namespace import ::xorb::stub::*
namespace import ::xosoap::client::*

# 1-) create a 'glue' object
set glueObject [SoapGlueObject new \
		    -endpoint "http://websrv.cs.fsu.edu/~engelen/interop2.cgi" \
		    -action "http://websrv.cs.fsu.edu/~engelen/interop2.cgi" \
		    -callNamespace http://soapinterop.org/ \
		    -messageStyle ::xosoap::RpcEncoded]

# 2-) create an ordinary XOTcl object and turn it into a proxy client
::xotcl::Object EchoClient -glueobject $glueObject

# 3-) create the interface of the 'client proxy' using ad_glue keyword
# Note the structure of the declarative call, it does not take a method body!
EchoClient ad_glue -returns xsFloat\
    proc echoFloat {
      -inputFloat:xsFloat,glue
    } {
      By calling this proc, a remote call is issued \
	  against the previously defined endpoint
    }

# 3-) issue the call
ns_write [EchoClient echoFloat -inputFloat 1.61805]




