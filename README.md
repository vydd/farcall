# farcall

Farcall is a Common Lisp library that lets you expose functions over HTTP using [JSON-RPC 2.0](https://www.jsonrpc.org/specification).

## Unstable API

Please keep in mind that the API should not be considered stable. This is expected to change in early 2020. Also, not every JSON-RPC (really, batching) feature is supported, and for such a tiny specification, this needs to change - in other words, Farcall should support the complete JSON-RPC 2.0 spec. If you need this for a production project, then maybe wait for a bit. If not - let's get started!

## Requirements

Currently only tested (and known to work) with

| CCL | Version 1.12-dev (v1.12-dev.5) DarwinX8664 |

If you decide to test the library, please post a PR with results.

## Installation

Farcall is currently not in [Quicklisp](https://www.quicklisp.org/beta/), so you should clone this repository into your `~/quicklisp/local-projects` folder before proceeding.

## Getting started

We're going to test the library by starting up a JSON-RPC server in a CL REPL, and then calling a method exposed by that server from a terminal window, using [curl](https://curl.haxx.se).

Type the following in the CL REPL:

```lisp
(ql:quickload :farcall)

(farcall:defrpc add (a b)
  "Adds two numbers"
  (+ a b))

(farcall:start-server)
```

_This will first load the library, then define a rpc method using a syntax that's completely similar to `DEFUN`, and will finally start the HTTP server on port 2000._

Then type the following in the terminal:

```sh
curl -H "Content-Type: application/json" localhost:2000/ -d'{"jsonrpc":"2.0","method":"add","params":[1,2],"id":"1"}'
```

_We're setting `application/json` as content type, as it's the only one supported by the specification (and farcall). The data we're sending is formatted as per specification - "jsonrpc" and "id" fields are mandatory._

If you've done everything correctly, this is the response you should receive:

```sh
{"jsonrpc":"2.0","id":"1","result":3}
```

## Why a new library

If you're happy with [fukamachi's jsonrpc](https://github.com/fukamachi/jsonrpc), with [cl-json's](https://common-lisp.net/project/cl-json/cl-json.html) included RPC capabilities, or any other library - that's great, and you should probably continue using it, at least until Farcall is stable.

The reason why I started this project is that:

- Other libraries weren't necessarily well documented. CL-JSON's docs are non existent, and I'm not really sure how easy it'd be to put its capabilities behind Hunchentoot.
- Reviewed libraries didn't work with HTTP out of the box. Fukamachi's jsonrpc looks great, but it only seems to support raw TCP & Websockets. I would guess it's possible to add another transport, but it felt like much more work than just writing the library from scratch.
- OpenRPC or other discovery & documentation mechanisms don't seem to be available elsewhere. In my opinion, this is an important feature for production APIs.
- Authorization is important for building most APIs. However, as JSON-RPC is not bound to any single protocol, it naturally does not specify how to do it in context of HTTP. Contemporary APIs are usually built with token based authorization in mind, and this is what Farcall is set to support. (The very method of authenticating the token and authorizing the provided request is left to the user.)

## Reference

### START-SERVER

function `(&optional (port 2000))`

Starts the JSON-RPC server on the provided port. Farcall uses Hunchentoot in the backend, and there is no need to run it separately.

### STOP-SERVER

function `()`

Stops the currently started JSON-RPC server.

### SET-AUTHORIZER

function `(authorizer)`

The authorization function set by this method will be used on all RPC requests. The function needs to be of type (lambda (rpc token)), where RPC is an alist obtained after parsing the JSON RPC payload, and TOKEN is the string obtained from Authorization HTTP header.

### REGISTER-RPC

function `(name)`

Registers an already defined FUNCTION as a rpc method with the given NAME. The disadvantage of using this instead of DEFRPC is twofold: Not only that there's more code to write, but recompiling the function on the fly will not work - REGISTER-RPC will have to be called again. The advantage, of course, is that REGISTER-RPC can be used to retrofit JSON RPC functionality when working with existing, unchangeable code.

### UNREGISTER-RPC

function `(name)`

Unregisters a defined RPC. No error is thrown if the NAME isn't registered.

### DEFRPC

macro `(name arglist &body body)`

Defines a remote procedure call using syntax similar to DEFUN. Should be used instead of REGISTER-RPC for new code.

## Plan

[ ] Complete JSON-RPC 2.0 support (add batching)
[ ] Settle on the API
[ ] Publish on Quicklisp
[ ] Implement [OpenRPC](https://open-rpc.org)
[ ] Implement the client part of the library with remote procedure
    stubs automatically generated from OpenRPC specification

## Resources

- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)

## Outro

For everything else, read the code or ask vydd at #lispgames.
Go make something pretty!

## License

MIT
