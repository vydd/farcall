;;;; farcall.lisp

(in-package #:farcall)

(defvar *rpc-table* (make-hash-table :test 'equal))
(defvar *rpc-request-id* nil)
(defvar *acceptor* nil)
(defvar *authorizer* (lambda (rpc token) (declare (ignorable rpc token)) t))

;;; Public API

(defun start-server (&optional (port 2000))
  (declare (type integer port))
  "Starts the JSON-RPC server on the provided port. Farcall uses Hunchentoot in the backend, and there is no need to run it separately. The server exposes / route for POST & GET methods. POST is used for JSON-RPC as per spec."
  (stop-server)
  (setf *acceptor* (make-instance 'easy-routes:routes-acceptor :port port))
  (hunchentoot:start *acceptor*))

(defun stop-server ()
  "Stops the currently started JSON-RPC server."
  (when *acceptor*
    (hunchentoot:stop *acceptor*)))

(defun set-authorizer (authorizer)
  (declare (type function authorizer))
  "The authorization function set by this method will be used on all RPC requests. The function needs to be of type (lambda (rpc token)), where RPC is an alist obtained after parsing the JSON RPC payload, and TOKEN is the string obtained from Authorization HTTP header."
  (setf *authorizer* authorizer))

(defun register-rpc (function name)
  (declare (type function function) (type string name))
  "Registers an already defined FUNCTION as a rpc method with the given NAME. The disadvantage of using this instead of DEFRPC is twofold: Not only that there's more code to write, but recompiling the function on the fly will not work - REGISTER-RPC will have to be called again. The advantage, of course, is that REGISTER-RPC can be used to retrofit JSON RPC functionality when working with existing, unchangeable code."
  (setf (gethash name *rpc-table*) function))

(defun unregister-rpc (name)
  (declare (type string name))
  "Unregisters a defined RPC. No error is thrown if the NAME isn't registered."
  (remhash name *rpc-table*))

(defmacro defrpc (name arglist &body body)
  "Defines a remote procedure call using syntax similar to DEFUN. Should be used instead of REGISTER-RPC for new code."
  `(progn
     (defun ,name ,arglist
       ,@body)
     (register-rpc #',name ,(cl-json:lisp-to-camel-case (string name)))))

;;; Private

(defun call-rpc (rpc)
  (let ((function (gethash (cdr (assoc :method rpc)) *rpc-table*))
        (params (cdr (assoc :params rpc))))
    (if (alistp params)
        (apply function (alexandria:alist-plist params))
        (apply function params))))

(defun valid-rpc-method-p (rpc)
  (handler-case
      (let ((function (gethash (cdr (assoc :method rpc)) *rpc-table*)))
        function)
    (condition () nil)))

(defun valid-rpc-params-p (rpc)
  (handler-case
      (let ((function (gethash (cdr (assoc :method rpc)) *rpc-table*)))
        (when function
          (let ((params (cdr (assoc :params rpc))))
            (cond
              ((alistp params)
               (not (set-exclusive-or
                     (mapcar #'alexandria:symbolicate (mapcar #'car params))
                     (trivial-arguments:arglist function))))
              ((listp params)
               (= (length params) (length (trivial-arguments:arglist function))))))))
    (condition () nil)))

(defun alistp (list)
  (consp (car list)))

(defun @auth (next)
  (let ((authorized
         (handler-case
             (funcall *authorizer*
                      (jsonrpc->rpc (hunchentoot:raw-post-data :force-text t))
                      (hunchentoot:header-in* "authorization"))
           (condition () nil))))
    (if authorized
        (funcall next)
        (progn
          (setf (hunchentoot:return-code*) 403)
          ""))))

(easy-routes:defroute get-methods ("/" :method :get) ()
  (setf (hunchentoot:content-type*) "application/json")
  (cl-json:encode-json-to-string
   (loop :for key :being :the :hash-keys :of *rpc-table*
      :collect (make-method-description key))))

(defun make-method-description (method)
  (let ((function (gethash method *rpc-table*)))
    `((:method . ,method)
      (:params . ,(trivial-arguments:arglist function))
      (:documentation . ,(documentation function 'function)))))

(easy-routes:defroute rpc ("/" :method :post :decorators (@auth)) ()
  (setf (hunchentoot:content-type*) "application/json")
  (cl-json:encode-json-to-string
   (let ((content-type (hunchentoot:header-in* "content-type")))
     (if (string-equal "application/json" content-type)
         (handler-case
             (let* ((rpc (jsonrpc->rpc (hunchentoot:raw-post-data :force-text t)))
                    (*rpc-request-id* (cdr (assoc :id rpc))))
               (if (valid-rpc-method-p rpc)
                   (if (valid-rpc-params-p rpc)
                       (jsonrpc-result (call-rpc rpc))
                       (jsonrpc-error "Invalid params for method \"~a\"."
                                      :vals (list (cdr (assoc :method rpc)))
                                      :code :invalid-params))
                   (jsonrpc-error "Method \"~a\" not found."
                                  :vals (list (cdr (assoc :method rpc)))
                                  :code :method-not-found)))
           (condition (c) (jsonrpc-error "Bad request."
                                         :data (format nil "~a" c))))
         (jsonrpc-error "Content-Type: ~a not supported. Use application/json."
                        :vals (list content-type)
                        :code :invalid-request)))))

(defun jsonrpc->rpc (payload)
  (let* ((jsonrpc (json:decode-json-from-string payload))
         (version (cdr (assoc :jsonrpc jsonrpc)))
         (method (cdr (assoc :method jsonrpc)))
         (params (cdr (assoc :params jsonrpc))))
    (when (not (assoc :id jsonrpc))
      (push '(:id . nil) jsonrpc))
    (when (and method params version
               (string-equal "2.0" (cdr (assoc :jsonrpc jsonrpc))))
      jsonrpc)))

(defun jsonrpc-result (result &key (id nil))
  `((:jsonrpc . "2.0")
    (:id . ,(or id *rpc-request-id*))
    (:result . ,result)))

(defun jsonrpc-error (message &key (vals (list)) (data nil) (code :internal-error) (id nil))
  (setf (hunchentoot:return-code*)
        (case code
          (:parse-error 400)
          (:invalid-request 400)
          (:method-not-found 404)
          (:invalid-params 400)
          (otherwise 500)))
  `((:jsonrpc . "2.0")
    (:id . ,(or id *rpc-request-id*))
    (:error . ((:message . ,(apply #'format (list* nil message vals)))
               (:code . ,(case code
                           (:parse-error -32700)
                           (:invalid-request -32600)
                           (:method-not-found -32601)
                           (:invalid-params -32602)
                           (:service-error -32000)
                           (otherwise -32603)))
               (:data . ,data)))))
