#lang racket

(require "vector.rkt")

(provide
  shape<%>
  sphere%
  plane%)

(define shape<%>
  (interface ()
    [reflectivity (->m real?)]
    [color (->m (listof real?) (listof real?))]
    [normal (->m (listof real?) (listof real?))]
    [collision-time (->m (listof real?) (listof real?) (or/c #f real?))]))

(define sphere%
  (class* object%
    (shape<%>)
    (init reflect shape-color center radius)

    (define refl reflect)
    (define col shape-color)
    (define cen center)
    (define rad radius)

    (super-new)

    (define/public (reflectivity)
      refl)

    (define/public (color pt)
      col)

    (define/public (normal pt)
      (vsub pt cen))

    (define/public (collision-time pt vec)
      (let* ([a (dot-product vec vec)]
             [v (vsub pt cen)]
             [b (* 2 (dot-product vec v))]
             [c (- (dot-product v v) (* rad rad))]
             [discr (- (* b b) (* 4 a c))])
        (if (< discr 0)
          #f
          (let ([t1 (/ (+ (- b) (sqrt discr)) (* 2 a))]
                [t2 (/ (- (- b) (sqrt discr)) (* 2 a))])
            (cond
              [(and (< t1 0) (< t2 0)) #f]
              [(< t1 0) t2]
              [(< t2 0) t1]
              [else (min t1 t2)])))))))

(define plane%
  (class* object%
    (shape<%>)
    (init reflect shape-color point normal-v checkerboard check-color orientation)

    (define refl reflect)
    (define col shape-color)
    (define pt point)
    (define nm normal-v)
    (define check checkerboard)
    (define ch-color check-color)
    (define ori orientation)

    (super-new)

    (define/public (reflectivity)
      refl)

    (define/public (color p)
      (if check
        (let* ([v (vsub p pt)]
               [x (project v ori)]
               [y (vsub v x)]
               [ix (round (norm x))]
               [iy (round (norm y))])
          (if (zero? (modulo (+ ix iy) 2))
            col
            ch-color))
        col))

    (define/public (normal p)
      nm)

    (define/public (collision-time p v)
      (let ([ang (dot-product nm v)])
        (if (< (abs ang) 1e-6)
          #f
          (let ([t (/ (dot-product nm (vsub pt p)) ang)])
            (if (< t 0)
              #f
              t)))))))
