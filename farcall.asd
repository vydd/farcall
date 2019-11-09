;;;; farcall.asd

(asdf:defsystem #:farcall
  :description "Farcall lets you expose functions over HTTP using JSON-RPC 2.0."
  :author "Danilo Vidovic (vydd)"
  :license  "MIT"
  :version "0.1.0"
  :serial t
  :depends-on (#:alexandria
               #:cl-json
               #:easy-routes
               #:hunchentoot
               #:trivial-arguments)
  :components ((:file "package")
               (:file "farcall")))
