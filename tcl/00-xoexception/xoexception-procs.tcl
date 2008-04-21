
#package require XOTcl
#package require xox

#::xox::Package ::xoexception
#::xoexception load

::xo::library doc {

  Java-inspired exception handling facility, originally coming
  bundled in xotcllib, see 
  http://xotcllib.cvs.sourceforge.net/xotcllib/xoexception/
  Slightly adapted for OpenACS deployment by
  stefan.sobernig@wu-wien.ac.at; 
  see LICENSE for distribution-specific details.

  @author ben.thomasson@gmail.com
  
}

namespace eval xoexception { 
proc try { args } {

    uplevel ::xoexception::Throwable try $args
}
namespace export try
}
