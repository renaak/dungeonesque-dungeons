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

;; FIXME: test with failing require
;; FIXME: use placeholders in queries
;; FIXME: call (DATABASE:close)

(local module {})
(var sqlite nil)
(var DATABASE nil)
(var GAME-ID nil)
(var TURN-ID nil)

(let [(ok? result) (pcall require :lsqlite3)]
  (when ok?
    (set sqlite result)))

(lambda exec [database sql]
  (print sql)
  (let [result (database:exec sql)]
    (when (not= result sqlite.OK)
      (let [message (: "SQL failed with error code %s"
                       :format
                       result)]
        (if config.fatal-warnings?
            (error message)
            (io.stderr:write message)))))
  nil)

(lambda make-database []
  (lambda create-table [database name columns-sql]
    (exec database
          (: (.. "create table if not exists"
                 " %s (id integer primary key,"
                 " created_at text not null default current_timestamp"
                 " %s);")
             :format
             name
             columns-sql))
    nil)

  (print "Creating tracking database")
  (let [database (sqlite.open "../games.sqlite")]
    (create-table database :games "")
    (create-table database
                  :turns
                  (.. ", game_id integer"
                      ", damage_inflicted integer not null default 0"
                      ", foreign key (game_id) references games(id)"))
    database))

(lambda get-database []
  (when (= DATABASE nil)
    (set DATABASE (make-database)))

  DATABASE)

(lambda make-game-id []
  (var game-id nil)

  (let [database (get-database)]
    (exec database "insert into games (id) values (NULL);")
    (set game-id (database:last_insert_rowid))
    (print (: "Game ID is %s"
              :format
              game-id)))

  game-id)

(lambda get-game-id []
  (when (= GAME-ID nil)
    (set GAME-ID (make-game-id)))

  GAME-ID)

(lambda get-turn-id []
  (assert (not= TURN-ID nil) "Turn ID is nil")
  TURN-ID)

(lambda module.on-new-turn []
  (let [database (get-database)
        game-id (get-game-id)]
    (exec database
          (: "insert into turns (game_id) values (%s);"
             :format
             game-id))
    (set TURN-ID (database:last_insert_rowid))
    (print "Turn ID:" TURN-ID))
  nil)

(lambda module.hero-damaged [damage]
  (let [database (get-database)]
    (exec database (: (.. "update turns"
                          " set damage_inflicted=%s"
                          " where id=%s")
                      :format
                      damage
                      (get-turn-id))))
  nil)

module
