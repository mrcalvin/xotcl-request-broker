# -) prerequisites
namespace import ::xosoap::client::*
namespace import ::xorb::stub::*

# 1-) create and populate a 'glue' object
set glueObject [SoapGlueObject new \
		    -endpoint "http://websrv.cs.fsu.edu/~engelen/interop2.cgi"\
		    -action "http://websrv.cs.fsu.edu/~engelen/interop2.cgi" \
		    -callNamespace http://soapinterop.org/ \
		    -messageStyle ::xosoap::RpcEncoded]

# 2-) create a 'client proxy'
ProxyObject EchoClient -glueobject $glueObject

# 3-) create the interface of the 'client proxy'
EchoClient ad_proc -returns xsFloat \
    echoFloat {-inputFloat:xsFloat} {
      By calling this proc, a remote call is issued \
	  against the previously defined endpoint
    } {}

# 4-) issue the call
ns_write [EchoClient echoFloat -inputFloat 1.6180339887]\n

# 5-) specify a decorator (a mixin class in XOTcl terms)

::xotcl::Class ProxyDecorator
SoapGlueObject ProxyDecorator::GlueObject \
    -endpoint "http://dietrich.ganx4.com/nusoap/testbed/round2_base_server.php"\
    -messageStyle ::xosoap::RpcEncoded
ProxyDecorator instproc glueobject args {
  return [self class]::GlueObject
}

# 6-) decorate the client proxy

EchoClient mixin add ::template::ProxyDecorator

# 7-) re-issue the call

ns_write [EchoClient echoFloat -inputFloat 1.6180339887]