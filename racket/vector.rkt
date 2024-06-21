#lang racket

(provide
  (contract-out
    [vadd        (-> (listof real?) ... (listof real?))]
    [vsub        (-> (listof real?) (listof real?) (listof real?))]
    [vmul        (-> real? (listof real?) (listof real?))]
    [vneg        (-> (listof real?) (listof real?))]
    [dot-product (-> (listof real?) (listof real?) real?)]
    [norm        (-> (listof real?) real?)]
    [project     (-> (listof real?) (listof real?) (listof real?))]
    [normalize   (-> (listof real?) (listof real?))]))

(define (vadd . vs) (apply map + vs))

(define (vsub u v) (map - u v))

(define (vmul c v) (map (lambda (x) (* x c)) v))

(define (vneg v) (map (lambda (x) (- x)) v))

(define (dot-product u v) (foldl + 0 (map * u v)))

(define (norm v) (sqrt (dot-product v v)))

(define (project u v) (vmul (/ (dot-product u v) (dot-product v v)) v))

(define (normalize v) (vmul (/ 1 (norm v)) v))
