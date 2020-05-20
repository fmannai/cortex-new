/** Provides classes for working with WebSocket-related APIs. */

import go

/**
 * A data-flow node that establishes a new WebSocket connection.
 *
 * Extend this class to refine existing API models. If you want to model new APIs,
 * extend `WebSocketRequestCall::Range` instead.
 */
class WebSocketRequestCall extends DataFlow::CallNode {
  WebSocketRequestCall::Range self;

  WebSocketRequestCall() { this = self }

  /** Gets the URL of the request. */
  DataFlow::Node getRequestUrl() { result = self.getRequestUrl() }
}

/** Provides classes for working with WebSocket request functions. */
module WebSocketRequestCall {
  /**
   * A data-flow node that establishes a new WebSocket connection.
   *
   * Extend this class to model new APIs. If you want to refine existing
   * API models, extend `WebSocketRequestCall` instead.
   */
  abstract class Range extends DataFlow::CallNode {
    /** Gets the URL of the request. */
    abstract DataFlow::Node getRequestUrl();
  }

  /**
   * A WebSocket request expression string used in an API function of the
   * `golang.org/x/net/websocket` package.
   */
  private class GolangXNetDialFunc extends Range {
    GolangXNetDialFunc() {
      // func Dial(url_, protocol, origin string) (ws *Conn, err error)
      this.getTarget().hasQualifiedName(package("golang.org/x/net", "websocket"), "Dial")
    }

    override DataFlow::Node getRequestUrl() { result = this.getArgument(0) }
  }

  /**
   * A WebSocket DialConfig expression string used in an API function
   * of the `golang.org/x/net/websocket` package.
   */
  private class GolangXNetDialConfigFunc extends Range {
    GolangXNetDialConfigFunc() {
      // func DialConfig(config *Config) (ws *Conn, err error)
      this.getTarget().hasQualifiedName(package("golang.org/x/net", "websocket"), "DialConfig")
    }

    override DataFlow::Node getRequestUrl() {
      exists(DataFlow::CallNode cn |
        // func NewConfig(server, origin string) (config *Config, err error)
        cn.getTarget().hasQualifiedName(package("golang.org/x/net", "websocket"), "NewConfig") and
        this.getArgument(0) = cn.getResult(0).getASuccessor*() and
        result = cn.getArgument(0)
      )
    }
  }

  /**
   * A WebSocket request expression string used in an API function
   * of the `github.com/gorilla/websocket` package.
   */
  private class GorillaWebsocketDialFunc extends Range {
    DataFlow::Node url;

    GorillaWebsocketDialFunc() {
      // func (d *Dialer) Dial(urlStr string, requestHeader http.Header) (*Conn, *http.Response, error)
      // func (d *Dialer) DialContext(ctx context.Context, urlStr string, requestHeader http.Header) (*Conn, *http.Response, error)
      exists(string name, Method f |
        f = this.getTarget() and
        f.hasQualifiedName(package("github.com/gorilla", "websocket"), "Dialer", name)
      |
        name = "Dial" and this.getArgument(0) = url
        or
        name = "DialContext" and this.getArgument(1) = url
      )
    }

    override DataFlow::Node getRequestUrl() { result = url }
  }

  /**
   * A WebSocket request expression string used in an API function
   * of the `github.com/gobwas/ws` package.
   */
  private class GobwasWsDialFunc extends Range {
    GobwasWsDialFunc() {
      //  func (d Dialer) Dial(ctx context.Context, urlstr string) (conn net.Conn, br *bufio.Reader, hs Handshake, err error)
      exists(Method m |
        m.hasQualifiedName(package("github.com/gobwas", "ws"), "Dialer", "Dial") and
        m = this.getTarget()
      )
      or
      // func Dial(ctx context.Context, urlstr string) (net.Conn, *bufio.Reader, Handshake, error)
      this.getTarget().hasQualifiedName(package("github.com/gobwas", "ws"), "Dial")
    }

    override DataFlow::Node getRequestUrl() { result = this.getArgument(1) }
  }

  /**
   * A WebSocket request expression string used in an API function
   * of the `nhooyr.io/websocket` package.
   */
  private class NhooyrWebsocketDialFunc extends Range {
    NhooyrWebsocketDialFunc() {
      // func Dial(ctx context.Context, u string, opts *DialOptions) (*Conn, *http.Response, error)
      this.getTarget().hasQualifiedName(package("nhooyr.io", "websocket"), "Dial")
    }

    override DataFlow::Node getRequestUrl() { result = this.getArgument(1) }
  }

  /**
   * A WebSocket request expression string used in an API function
   * of the `github.com/sacOO7/gowebsocket` package.
   */
  private class SacOO7DialFunc extends Range {
    SacOO7DialFunc() {
      // func BuildProxy(Url string) func(*http.Request) (*url.URL, error)
      // func New(url string) Socket
      this.getTarget().hasQualifiedName("github.com/sacOO7/gowebsocket", ["New", "BuildProxy"])
    }

    override DataFlow::Node getRequestUrl() { result = this.getArgument(0) }
  }
}

/*
 * A message written to a WebSocket, considered as a flow sink for reflected XSS.
 */

class WebsocketReaderAsSource extends UntrustedFlowSource::Range {
  WebsocketReaderAsSource() {
    exists(WebSocketReader r | this = r.getAnOutput().getNode(r.getACall()))
  }
}

/**
 * A function or a method which reads a message from a WebSocket connection.
 *
 * Extend this class to refine existing API models. If you want to model new APIs,
 * extend `WebSocketReader::Range` instead.
 */
class WebSocketReader extends Function {
  WebSocketReader::Range self;

  WebSocketReader() { this = self }

  /** Gets an output of this function that is read from a WebSocket connection. */
  FunctionOutput getAnOutput() { result = self.getAnOutput() }
}

/** Provides classes for working with messages read from a WebSocket. */
module WebSocketReader {
  /**
   * A function or a method which reads a message from a WebSocket connection
   *
   * Extend this class to model new APIs. If you want to refine existing API models,
   * extend `WebSocketReader` instead.
   */
  abstract class Range extends Function {
    /**Returns the parameter in which the function stores the message read. */
    abstract FunctionOutput getAnOutput();
  }

  /**
   * Models the `Receive` method of the `golang.org/x/net/websocket` package.
   */
  private class GolangXNetCodecRecv extends Range, Method {
    GolangXNetCodecRecv() {
      // func (cd Codec) Receive(ws *Conn, v interface{}) (err error)
      this.hasQualifiedName("golang.org/x/net/websocket", "Codec", "Receive")
    }

    override FunctionOutput getAnOutput() { result.isParameter(1) }
  }

  /**
   * Models the `Read` method of the `golang.org/x/net/websocket` package.
   */
  private class GolangXNetConnRead extends Range, Method {
    GolangXNetConnRead() {
      // func (ws *Conn) Read(msg []byte) (n int, err error)
      this.hasQualifiedName("golang.org/x/net/websocket", "Conn", "Read")
    }

    override FunctionOutput getAnOutput() { result.isParameter(0) }
  }

  /**
   * Models the `Read` method of the `nhooyr.io/websocket` package.
   */
  private class NhooyrWebsocketRead extends Range, Method {
    NhooyrWebsocketRead() {
      // func (c *Conn) Read(ctx context.Context) (MessageType, []byte, error)
      this.hasQualifiedName("nhooyr.io/websocket", "Conn", "Read")
    }

    override FunctionOutput getAnOutput() { result.isResult(1) }
  }

  /**
   * Models the `Reader` method of the `nhooyr.io/websocket` package.
   */
  private class NhooyrWebsocketReader extends Range, Method {
    NhooyrWebsocketReader() {
      // func (c *Conn) Reader(ctx context.Context) (MessageType, io.Reader, error)
      this.hasQualifiedName("nhooyr.io/websocket", "Conn", "Reader")
    }

    override FunctionOutput getAnOutput() { result.isResult(1) }
  }

  /**
   * Models the `ReadFrame`function of the `github.com/gobwas/ws` package.
   */
  private class GobwasWsReadFrame extends Range {
    GobwasWsReadFrame() {
      // func ReadFrame(r io.Reader) (f Frame, err error)
      this.hasQualifiedName("github.com/gobwas/ws", "ReadFrame")
    }

    override FunctionOutput getAnOutput() { result.isResult(0) }
  }

  /**
   * Models the `ReadHeader`function of the `github.com/gobwas/ws` package.
   */
  private class GobwasWsReadHeader extends Range {
    GobwasWsReadHeader() {
      // func ReadHeader(r io.Reader) (h Header, err error)
      this.hasQualifiedName("github.com/gobwas/ws", "ReadHeader")
    }

    override FunctionOutput getAnOutput() { result.isResult(0) }
  }

  /**
   * Models the `ReadJson` function of the `github.com/gorilla/websocket` package.
   */
  private class GorillaWebsocketReadJson extends Range {
    GorillaWebsocketReadJson() {
      // func ReadJSON(c *Conn, v interface{}) error
      this.hasQualifiedName("github.com/gorilla/websocket", "ReadJSON")
    }

    override FunctionOutput getAnOutput() { result.isParameter(1) }
  }

  /**
   * Models the `ReadJson` method of the `github.com/gorilla/websocket` package.
   */
  private class GorillaWebsocketConnReadJson extends Range, Method {
    GorillaWebsocketConnReadJson() {
      // func (c *Conn) ReadJSON(v interface{}) error
      this.hasQualifiedName("github.com/gorilla/websocket", "Conn", "ReadJSON")
    }

    override FunctionOutput getAnOutput() { result.isParameter(0) }
  }

  /**
   * Models the `ReadMessage` method of the `github.com/gorilla/websocket` package.
   */
  private class GorillaWebsocketReadMessage extends Range, Method {
    GorillaWebsocketReadMessage() {
      // func (c *Conn) ReadMessage() (messageType int, p []byte, err error)
      this.hasQualifiedName("github.com/gorilla/websocket", "Conn", "ReadMessage")
    }

    override FunctionOutput getAnOutput() { result.isResult(1) }
  }
}
