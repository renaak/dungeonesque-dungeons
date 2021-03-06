;; Copyright 2020 Bastien Léonard. All rights reserved.

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:

;;    1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.

;;    2. Redistributions in binary form must reproduce the above
;;    copyright notice, this list of conditions and the following
;;    disclaimer in the documentation and/or other materials provided
;;    with the distribution.

;; THIS SOFTWARE IS PROVIDED BY BASTIEN LÉONARD ``AS IS'' AND ANY
;; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
;; PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL BASTIEN LÉONARD OR
;; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
;; USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
;; OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;; SUCH DAMAGE.

(import-macros {: with-saved-color} :macros)

(local colors (require :colors))
(local fonts (require :fonts))
(local scaled (require :screen-scaling))
(local utils (require :utils))

(local FOREGROUND-COLOR colors.WHITE)
(local BACKGROUND-COLOR colors.BLACK)
(local BACKGROUND-PADDING (scaled 64))
(local ITEM-MARGIN (scaled 100))
(local ITEM-WIDTH (scaled 100))
(local ITEM-HEIGHT (scaled 100))
(local ICON-SIZE (scaled 64))

(lambda width [inventory-length]
  (if (= inventory-length 0)
      0
      (+ (* inventory-length ITEM-WIDTH)
         (* (- inventory-length 1) ITEM-MARGIN))))

(lambda height [font]
  (+ ITEM-HEIGHT (* (font:getHeight) 2) (* BACKGROUND-PADDING 2)))

(lambda x [inventory-length]
  (/ (- (love.graphics.getWidth) (width inventory-length)) 2))

(lambda y [font]
  (- (love.graphics.getHeight) (height font) 1))

(lambda print-text [x y text font]
  (love.graphics.print text
                       font
                       (+ x
                          (/ (- ITEM-WIDTH (font:getWidth text))
                             2))
                       y)
  nil)

(lambda draw-item-icon [item-kind x y]
  (let [(tile-row tile-column) (tileset:tile-of-item-kind item-kind)
        scale-x (utils.round (/ ICON-SIZE tileset.tile-width))
        scale-y (utils.round (/ ICON-SIZE tileset.tile-height))]
    (love.graphics.draw tileset.image
                        (love.graphics.newQuad (* tile-column tileset.tile-width)
                                               (* tile-row tileset.tile-height)
                                               tileset.tile-width
                                               tileset.tile-height
                                               tileset.width
                                               tileset.height)
                        x
                        y
                        0
                        scale-x
                        scale-y))
  nil)

(let [class {}]
  (lambda class.new []
    (setmetatable {} {:__index class}))
  (lambda class.draw [self inventory]
    (when (= (inventory:length) 0)
      (lua :return))

    (let [font (fonts.get 30)]
      (var x (x (inventory:length)))

      (with-saved-color
       (love.graphics.setColor (unpack BACKGROUND-COLOR))
       (love.graphics.rectangle :fill
                                (- x BACKGROUND-PADDING)
                                (y font)
                                (+ (width (inventory:length))
                                   (* BACKGROUND_PADDING 2))
                                (+ (height font)
                                   (* BACKGROUND-PADDING 2)))

       (each [i item (ipairs (inventory:items))]
         (var y (+ (y font) BACKGROUND-PADDING))
         (love.graphics.setColor (unpack FOREGROUND-COLOR))
         (print-text x y (tostring i) font)
         (set y (+ y (font:getHeight)))
         (love.graphics.rectangle :line
                                  x
                                  y
                                  ITEM-WIDTH
                                  ITEM-HEIGHT)
         (love.graphics.setColor (unpack (tileset:color-of-item-kind
                                          item.kind)))
         (let [y (+ y (/ (- ITEM-HEIGHT ICON-SIZE) 2))]
           (draw-item-icon item.kind
                           (+ x (/ (- ITEM-WIDTH ICON-SIZE) 2))
                           y))
         (love.graphics.setColor (unpack FOREGROUND-COLOR))
         (set y (+ y ITEM_HEIGHT))
         (print-text x
                     y
                     (: "%sx %s"
                        :format
                        item.uses
                        (item.kind:name))
                     font)
         (set x (+ x ITEM-WIDTH ITEM-MARGIN)))))
    nil)
  class)
