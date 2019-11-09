;;;; package.lisp

(defpackage #:farcall
  (:use #:cl)
  (:export #:start-server
           #:stop-server
           #:set-authorizer
           #:register-rpc
           #:unregister-rpc
           #:defrpc))
