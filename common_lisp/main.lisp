(load "~/quicklisp/setup.lisp")
(require :yason)
(require :zpng)

;;;; Vector operations

(defun dot-product (u v)
  (apply #'+ (mapcar #'* u v)))

(defun magnitude (v)
  (sqrt (dot-product v v)))

(defun normalize (v)
  (let ((m (magnitude v)))
    (mapcar (lambda (x) (/ x m)) v)))

(defun project (u v)
  (let ((x (/ (dot-product u v) (dot-product v v))))
    (mapcar (lambda (b) (* x b)) v)))

;;;; Data types

(defclass shape ()
  ((color
     :initarg :color
     :reader color)
   (reflectiity
     :initarg :refl
     :reader reflectivity)))

(defclass sphere (shape)
  ((center
     :initarg :center
     :reader center)
   (radius
     :initarg :radius
     :reader radius)))

(defclass plane (shape)
  ((point
     :initarg :point
     :reader point)
   (normal
     :initarg :normal
     :reader normal)
   (checkerboard
     :initarg :check
     :reader checkerboard)
   (check-color
     :initarg :color2
     :reader check-color)
   (orientation
     :initarg :ori
     :reader orientation)))

(defgeneric collision-time (shape ray))
(defgeneric color-at (shape point))
(defgeneric normal-vector (shape point))

(defmethod collision-time ((shape sphere) ray)
  (let* ((a (dot-product (cdr ray) (cdr ray)))
         (v (mapcar #'- (car ray) (center shape)))
         (b (* 2 (dot-product (cdr ray) v)))
         (r (radius shape))
         (c (- (dot-product v v) (* r r)))
         (d (- (* b b) (* 4 a c))))
    (if (< d 0)
      nil
      (let ((t1 (/ (- (+ b (sqrt d))) (* 2 a)))
            (t2 (/ (- (- b (sqrt d))) (* 2 a))))
        (cond
          ((and (< t1 0) (< t2 0)) nil)
          ((< t1 0) t2)
          ((< t2 0) t1)
          (t (min t1 t2)))))))

(defmethod collision-time ((shape plane) ray)
  (let ((angle (dot-product (cdr ray) (normal shape))))
    (if (< (abs angle) 1e-6)
      nil
      (let ((time (/ (dot-product (normal shape)
                                  (mapcar #'- (point shape) (car ray))) angle)))
        (if (< time 0) nil time)))))

(defmethod normal-vector ((shape sphere) point)
  (mapcar #'- point (center shape)))

(defmethod normal-vector ((shape plane) point)
  (normal shape))

(defmethod color-at ((shape sphere) point)
  (color shape))

(defmethod color-at ((shape plane) point)
  (if (checkerboard shape)
    (let* ((u (mapcar #'- (point shape) point))
           (v (project u (orientation shape)))
           (x (round (magnitude v)))
           (y (round (magnitude (mapcar #'- u v)))))
      (if (evenp (+ x y))
        (color shape)
        (check-color shape)))
    (color shape)))

(defclass scene ()
  ((camera
     :initarg :camera
     :reader camera)
   (light
     :initarg :light
     :reader light)
   (ambient
     :initarg :amb
     :reader ambient)
   (specular
     :initarg :spec
     :reader specular)
   (spec-power
     :initarg :specpow
     :reader spec-power)
   (max-refls
     :initarg :maxrefls
     :reader max-refls)
   (background-color
     :initarg :bg
     :reader background)
   (antialias
     :initarg :aa
     :reader antialias)
   (objects
     :initform '()
     :accessor objects)))

(defmethod add-object ((obj scene) o)
  (setf (objects obj) (cons o (objects obj))))

(defun min-by (lst key)
  (reduce (lambda (acc e) (if (< (funcall key e) (funcall key acc)) e acc))
          (cdr lst)
          :initial-value (car lst)))

(defmethod nearest-intersection ((obj scene) ray)
  (let* ((ts (mapcar (lambda (o) (cons o (collision-time o ray))) (objects obj)))
         (times (remove-if (lambda (e) (null (cdr e))) ts)))
    (if (null times)
      nil
      (min-by times #'cdr))))

(defun color-ray (scene ray refls)
  (let ((ni (nearest-intersection scene ray)))
    (if (null ni)
      (background scene)
      (let* ((col (mapcar (lambda (x y) (+ x (* (cdr ni) y))) (car ray) (cdr ray)))
             (refl (reflectivity (car ni)))
             (amb (* (ambient scene) (- 1.0 refl)))
             (obj-color (color-at (car ni) col))
             (l-amb (mapcar (lambda (x) (* x amb)) obj-color))
             (light-dir (normalize (mapcar #'- (light scene) col)))
             (vneg (normalize (mapcar #'- (cdr ray))))
             (norm (normalize (normal-vector (car ni) col)))
             (l-refl (if (and (< refls (max-refls scene)) (> refl 0.003))
                       (let ((ref (mapcar (lambda (x y) (+ x (* 2 (- y x))))
                                          vneg
                                          (project vneg norm))))
                         (mapcar (lambda (x) (* (- 1.0 amb) refl x))
                                 (color-ray scene
                                            (cons (mapcar (lambda (x y) (+ x (* 1e-6 y)))
                                                          col
                                                          ref)
                                                  ref)
                                            (1+ refls))))
                       '(0.0 0.0 0.0))))
        (if (null (nearest-intersection scene
                                        (cons (mapcar (lambda (x y)
                                                        (+ x (* 1e-6 y)))
                                                      col
                                                      light-dir)
                                              light-dir)))
          (let* ((diff-factor (* (- 1.0 amb) (- 1.0 refl) (max 0.0 (dot-product norm light-dir))))
                 (l-diff (mapcar (lambda (x) (* x diff-factor)) obj-color))
                 (half (normalize (mapcar #'+ light-dir vneg)))
                 (l-spec (mapcar (lambda (x) (* (specular scene)
                                                (max 0.0 (expt (dot-product half norm) (spec-power scene)))
                                                x))
                                 '(255.0 255.0 255.0))))
            (mapcar #'+ l-amb l-refl l-spec l-diff))
          (mapcar #'+ l-amb l-refl))))))

(defun color-point (scene point)
  (color-ray scene (cons point (mapcar #'- point (camera scene))) 0))

(defun color-pixel-once (scene i j scale)
  (let* ((ix (float (/ i scale)))
         (iy (- 1.0 (float (/ j scale))))
         (x (+ ix (random (/ 1.0 scale))))
         (y (+ iy (random (/ 1.0 scale)))))
    (color-point scene (list x 0 y))))

(defun color-pixel (scene i j scale)
  (loop with sum = '(0 0 0)
        for k from 1 to (antialias scene)
        do (setf sum (mapcar #'+ sum (color-pixel-once scene i j scale)))
        finally
        (return (mapcar
                  (lambda (x)
                    (min 255 (max 0 (round (/ x (antialias scene))))))
                  sum))))

(defun parse-object (obj)
  (let ((refl (gethash "reflectivity" obj))
        (color (gethash "color" obj)))
    (if (string= (gethash "type" obj) "sphere")
      (make-instance 'sphere
                     :color color
                     :refl refl
                     :center (gethash "center" obj)
                     :radius (gethash "radius" obj))
      (if (gethash 'checkerboard obj)
        (make-instance 'plane
                       :color color
                       :refl refl
                       :point (gethash "point" obj)
                       :normal (gethash "normal" obj)
                       :check t
                       :color2 (gethash "color2" obj)
                       :ori (gethash "orientation" obj))
        (make-instance 'plane
                       :color color
                       :refl refl
                       :point (gethash "point" obj)
                       :normal (gethash "normal" obj)
                       :check nil)))))

(defun parse-scene (filename)
  (let* ((json (with-open-file (file filename)
                 (yason:parse file)))
         (scene (make-instance 'scene
                               :camera (gethash "camera" json)
                               :light (gethash "light" json)
                               :amb 0.2
                               :spec 0.5
                               :specpow 8
                               :maxrefls 6
                               :bg '(135 206 235)
                               :aa (gethash "antialias" json))))
    (loop for obj in (gethash "objects" json)
          do (add-object scene (parse-object obj)))
    scene))

(defun write-image (scene filename width height)
  (let ((png (make-instance 'zpng:pixel-streamed-png
                            :color-type :truecolor
                            :width width
                            :height height)))
    (with-open-file (stream filename
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type '(unsigned-byte 8))
      (zpng:start-png png stream)
      (loop for y from 0 below height
            do (loop for x from 0 below width
                     do (zpng:write-pixel (color-pixel scene x y width) png)))
      (zpng:finish-png png))))

(defun main (scene-file output-file)
  (write-image (parse-scene scene-file) output-file 512 512))
