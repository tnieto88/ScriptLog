using namespace System.Collections
using namespace System.IO

class LogMessage {
    [datetime] $TimeStamp
    [string] $Message
    [LogLevel] $Level
    [ScriptLogInfo] $ScriptLogInfo

    [string] ToString() {
        return $this.Message
    }
}
