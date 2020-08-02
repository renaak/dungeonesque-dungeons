(local Map (require :map))
(local random (require :random))
(local Room (require :room))
(local Tile (require :tile))
(local TileKind (require :tile-kind))
(local utils (require :utils))

(local MIN-ROOM-WIDTH 5)
(local MAX-ROOM-WIDTH 8)
(local MIN-ROOM-HEIGHT 5)
(local MAX-ROOM-HEIGHT 8)

(fn random-tile-constrained [map predicate i]
  (assert (not= map nil))
  (assert (not= predicate nil))
  (let [x (love.math.random 0 (- map.width 1))
        y (love.math.random 0 (- map.height 1))
        tile (map:get! x y)
        i (if (= i nil) 0 i)]
    (if (> i 1000)
        nil
        (if (predicate x y tile)
            tile
            (random-tile-constrained map predicate (+ i 1))))))

(lambda place-stairs [map]
  (let [stairs-count (math.max 1
                               (math.floor (* map.width
                                              map.height
                                              0.0006)))]
    (print (: "Placing %s stairs..." :format stairs-count))
    (for [i 1 stairs-count]
      (let [tile (random-tile-constrained
                  map
                  (lambda [x y tile]
                    (and (and (= tile.unit nil)
                              (= tile.kind TileKind.VOID))
                         (utils.all? (map:all-neighbors x y)
                                     (lambda [[x y tile]]
                                       (= tile.kind TileKind.VOID))))))]
        (when (= tile nil)
          (lua :break))
        (assert (= tile.kind TileKind.VOID))
        (set tile.kind TileKind.STAIRS-DOWN)))
    (print "Done placing stairs"))
  nil)

(lambda place-chests [map]
  (let [chests-count (math.max 1
                               (math.floor (* map.width
                                              map.height
                                              0.005)))]
    (print (: "Placing %s chests..."
              :format
              chests-count))
    (for [i 1 chests-count]
      (let [tile (random-tile-constrained
                  map
                  (lambda [x y tile]
                    (and (and (= tile.unit nil)
                              (= tile.kind TileKind.VOID))
                         (utils.all? (map:all-neighbors x y)
                                     (lambda [[x y tile]]
                                       (= tile.kind TileKind.VOID))))))]
        (when (= tile nil)
          (lua :break))
        (assert (= tile.kind TileKind.VOID))
        (set tile.kind TileKind.CHEST)))
    (print "Done placing chests"))


  nil)


(lambda place-decorations [map]
  (let [decorations-count (math.max 1
                                    (math.floor (* map.width
                                                   map.height
                                                   0.01)))]
    (print (: "Placing %s decorations..." :format decorations-count))
    (for [i 1 decorations-count]
      (let [tile (random-tile-constrained
                  map
                  (lambda [x y tile]
                    (and (and (= tile.unit nil)
                              (= tile.kind TileKind.VOID))
                         (utils.all? (map:all-neighbors x y)
                                     (lambda [[x y tile]]
                                       (= tile.kind TileKind.VOID))))))]
        (when (= tile nil)
          (lua :break))
        (assert (= tile.kind TileKind.VOID))
        (set tile.kind (random.random-entry [TileKind.SHELF
                                             TileKind.SHELF-WITH-SKULL
                                             TileKind.SKULL]))))
    (print "Done placing decorations"))
  nil)

(lambda populate-dungeon [map]
  (place-stairs map)
  (place-chests map)
  (place-decorations map)
  nil)

;; TODO: support Lua's for loop
(lambda each-room-tile [room map extra f]
  (for [x
        (- room.x extra)
        (+ room.x room.width -1 extra)]
    (for [y
          (- room.y extra)
          (+ room.y room.height -1 extra)]
      (if (map:valid? x y)
          (let [tile (map:get! x y)]
            (f x y tile))))))

(lambda random-room [map]
  (let [width (love.math.random MIN-ROOM-WIDTH
                                MAX-ROOM-WIDTH)
        height (love.math.random MIN-ROOM-HEIGHT
                                 MAX-ROOM-HEIGHT)
        y (love.math.random 0 (- map.height 1 height))
        x (love.math.random 0 (- map.width 1 width))]
    (Room.new x y width height)))

(lambda room-valid? [room map]
  (var valid true)
  ;; TODO: break early when we find an invalid tile
  (each-room-tile room
                  map
                  3
                  (lambda [x y tile]
                    (if (or (<= x 0)
                            (>= x map.width)
                            (<= y 0)
                            (>= y map.height))
                        (set valid false))
                    (if (not= tile.kind TileKind.WALL)
                        (set valid false))))
  valid)

;; TODO: make recursive
(lambda random-valid-room [map]
  (var room nil)
  (var valid false)
  (var i 0)
  ;; TODO: find a proper limit
  (while (and (not valid) (< i 1000))
    (set room (random-room map))
    (if (room-valid? room map)
        (set valid true))
    (set i (+ i 1)))
  (if (not valid)
      (error "Failed to find a room"))
  room)

(lambda room-center [room]
  (values (math.floor (+ room.x (/ room.width 2)))
          (math.floor (+ room.y (/ room.height 2)))))

(lambda set-tile-kind [map x y kind]
  (let [tile (map:get! x y)]
    (set tile.kind kind)))

(lambda connect-tiles [map a b]
  (set-tile-kind map (. a 1) (. a 2) TileKind.VOID)
  (if (or (not= (. a 1) (. b 1))
          (not= (. a 2) (. b 2)))
      ;; TODO: improve readability with pattern matching
      (let [a (if (< (. a 1) (. b 1))
                  [(+ (. a 1) 1) (. a 2)]
                  (> (. a 1) (. b 1))
                  [(- (. a 1) 1) (. a 2)]
                  (< (. a 2) (. b 2))
                  [(. a 1) (+ (. a 2) 1)]
                  (> (. a 2) (. b 2))
                  [(. a 1) (- (. a 2) 1)]
                  (assert false
                          "Should never happen"))]
        (connect-tiles map a b))))

(lambda connect-rooms [map a b]
  (connect-tiles map
                 [(room-center a)]
                 [(room-center b)]))

(lambda [width height]
  (let [map (Map:new {:width width
                      :height height
                      :make-tile (lambda []
                                   (Tile:new {:kind TileKind.WALL}))})
        rooms []
        rooms-count (math.max 1 (math.floor (/ (* width
                                                  height)
                                               (* MAX-ROOM-WIDTH
                                                  MAX-ROOM-HEIGHT
                                                  4))))]
    (for [i 1 rooms-count]
      (let [room (random-valid-room map)]
        (table.insert rooms room)
        (each-room-tile room
                        map
                        0
                        (lambda [x y tile]
                          (tset tile :kind TileKind.VOID)))))

    (print (: "Connecting %s rooms..."
              :format
              (length rooms)))
    (for [i 1 (- (length rooms) 1)]
      (connect-rooms map (. rooms 1) (. rooms (+ i 1))))
    (print "Done connecting rooms")
    (print "Populating dungeon...")
    (populate-dungeon map)
    (print "Done populating dungeon...")
    (values map rooms)))
