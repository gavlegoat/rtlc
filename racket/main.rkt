#lang racket

(require racket/draw)
(require json)
(require "shapes.rkt")
(require "vector.rkt")

(define scene%
  (class object%
    (init lt cam)

    (define light lt)
    (define camera cam)
    (define ambient 0.2)
    (define specular 0.5)
    (define specular-power 8)
    (define max-reflections 6)
    (define background '(135 206 235))
    (define objects '())

    (super-new)

    (define/public (add-object obj)
      (set! objects (cons obj objects)))

    (define/public (intersection pt vec)
      (foldl (lambda (t o a)
               (if (and t (> t 0) (or (not a) (> (car a) t)))
                 (cons t o)
                 a))
             #f
             (map (lambda (o) (send o collision-time pt vec)) objects)
             objects))

    (define/public (color-ray pt vec rs)
      (let ([int (send this intersection pt vec)])
        (if int
          (let* ([obj (cdr int)]
                 [col (vadd pt (vmul (car int) vec))]
                 [refl (send obj reflectivity)]
                 [amb (* ambient (- 1 refl))]
                 [l-amb (vmul amb (send obj color col))]
                 [norm (normalize (send obj normal col))]
                 [light-dir (normalize (vsub light col))]
                 [op (normalize (vneg vec))]
                 [l-refl (if (and (< rs max-reflections) (> refl 0.003))
                           (let ([ref (vadd op (vmul 2 (vsub (project op norm) op)))])
                             (vmul (* (- 1 amb) refl)
                                   (send this
                                         color-ray
                                         (vadd col (vmul 1e-6 ref))
                                         ref
                                         (+ 1 rs))))
                           '(0 0 0))])
            (if (send this intersection (vadd col (vmul 1e-6 light-dir)) light-dir)
              (vadd l-amb l-refl)
              (let* ([l-diff (vmul (* (- 1 amb) (- 1 refl)
                                      (max 0 (dot-product norm light-dir)))
                                   (send obj color col))]
                     [half (normalize (vadd light-dir op))]
                     [l-spec (vmul (* specular (expt (max 0 (dot-product half norm))
                                                     specular-power))
                                   '(255 255 255))])
                (vadd l-amb l-refl l-diff l-spec))))
          background)))

    (define/public (color-point pt)
      (send this color-ray pt (vsub pt camera) 0))))

(define (parse-scene config-file)
  (let ([json (with-input-from-file config-file (lambda () (read-json)))])
    (define scene (make-object scene%
                               (hash-ref json 'light)
                               (hash-ref json 'camera)))
    (for ([d (hash-ref json 'objects)])
      (send scene add-object
            (if (equal? (hash-ref d 'type) "sphere")
              (make-object sphere%
                           (hash-ref d 'reflectivity)
                           (hash-ref d 'color)
                           (hash-ref d 'center)
                           (hash-ref d 'radius))
              (if (hash-ref d 'checkerboard)
                (make-object plane%
                             (hash-ref d 'reflectivity)
                             (hash-ref d 'color)
                             (hash-ref d 'point)
                             (hash-ref d 'normal)
                             #t
                             (hash-ref d 'color2)
                             (hash-ref d 'orientation))
                (make-object plane%
                             (hash-ref d 'reflectivity)
                             (hash-ref d 'color)
                             (hash-ref d 'point)
                             (hash-ref d 'normal)
                             #f
                             '(0 0 0)
                             '(0 0 0))))))
    (values scene (hash-ref json 'antialias))))

(define (main config-file output-file)
  (let-values ([(scene antialias) (parse-scene config-file)])
    (define width 512)
    (define height 512)
    (define img (make-object bitmap% width height))
    (define dc (new bitmap-dc% [bitmap img]))

    (for ([i (range width)])
      (for ([j (range height)])
        (define c '(0 0 0))
        (for ([k (range antialias)])
          (let* ([x (/ (+ i (random)) width)]
                 [y (- 1 (/ (+ j (random)) width))]
                 [p (list x 0 y)])
              (set! c (vadd c (send scene color-point p)))))
        (send dc set-pixel i j
              (apply make-object color%
                     (map (lambda (x) (min 255 (max 0 (exact-round (/ x antialias)))))
                          c)))))

    (send img save-file output-file 'png)))

(command-line
 #:args (config-file output-file)
 (main config-file output-file))
