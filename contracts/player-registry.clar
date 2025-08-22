;; Player Registry Contract
;; Manages player registration, profiles, and team management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PLAYER-EXISTS (err u101))
(define-constant ERR-PLAYER-NOT-FOUND (err u102))
(define-constant ERR-TEAM-NOT-FOUND (err u103))
(define-constant ERR-TEAM-FULL (err u104))
(define-constant ERR-INVALID-INPUT (err u105))
(define-constant ERR-ALREADY-IN-TEAM (err u106))

;; Data Variables
(define-data-var next-player-id uint u1)
(define-data-var next-team-id uint u1)

;; Data Maps
(define-map players uint {
  username: (string-ascii 50),
  skill-rating: uint,
  reputation-score: uint,
  team-id: (optional uint),
  total-matches: uint,
  wins: uint,
  losses: uint,
  violations: uint,
  registered-at: uint,
  owner: principal
})

(define-map teams uint {
  name: (string-ascii 100),
  captain: uint,
  members: (list 10 uint),
  member-count: uint,
  max-members: uint,
  created-at: uint,
  total-wins: uint,
  total-losses: uint
})

(define-map player-usernames (string-ascii 50) uint)
(define-map team-names (string-ascii 100) uint)
(define-map player-principals principal uint)

;; Public Functions

;; Register a new player
(define-public (register-player (username (string-ascii 50)) (initial-rating uint))
  (let ((player-id (var-get next-player-id)))
    (asserts! (> (len username) u0) ERR-INVALID-INPUT)
    (asserts! (< initial-rating u5000) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? player-usernames username)) ERR-PLAYER-EXISTS)
    (asserts! (is-none (map-get? player-principals tx-sender)) ERR-PLAYER-EXISTS)

    (map-set players player-id {
      username: username,
      skill-rating: initial-rating,
      reputation-score: u1000,
      team-id: none,
      total-matches: u0,
      wins: u0,
      losses: u0,
      violations: u0,
      registered-at: block-height,
      owner: tx-sender
    })

    (map-set player-usernames username player-id)
    (map-set player-principals tx-sender player-id)
    (var-set next-player-id (+ player-id u1))

    (ok player-id)
  )
)

;; Create a new team
(define-public (create-team (team-name (string-ascii 100)) (max-members uint))
  (let ((team-id (var-get next-team-id))
        (player-id-opt (map-get? player-principals tx-sender)))
    (asserts! (> (len team-name) u0) ERR-INVALID-INPUT)
    (asserts! (and (> max-members u0) (< max-members u11)) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? team-names team-name)) ERR-PLAYER-EXISTS)
    (asserts! (is-some player-id-opt) ERR-PLAYER-NOT-FOUND)

    (let ((player-id (unwrap-panic player-id-opt))
          (player-data (unwrap-panic (map-get? players player-id))))
      (asserts! (is-none (get team-id player-data)) ERR-ALREADY-IN-TEAM)

      (map-set teams team-id {
        name: team-name,
        captain: player-id,
        members: (list player-id),
        member-count: u1,
        max-members: max-members,
        created-at: block-height,
        total-wins: u0,
        total-losses: u0
      })

      (map-set players player-id (merge player-data { team-id: (some team-id) }))
      (map-set team-names team-name team-id)
      (var-set next-team-id (+ team-id u1))

      (ok team-id)
    )
  )
)

;; Join an existing team
(define-public (join-team (team-id uint))
  (let ((player-id-opt (map-get? player-principals tx-sender)))
    (asserts! (is-some player-id-opt) ERR-PLAYER-NOT-FOUND)

    (let ((player-id (unwrap-panic player-id-opt))
          (player-data (unwrap-panic (map-get? players player-id)))
          (team-data-opt (map-get? teams team-id)))
      (asserts! (is-some team-data-opt) ERR-TEAM-NOT-FOUND)
      (asserts! (is-none (get team-id player-data)) ERR-ALREADY-IN-TEAM)

      (let ((team-data (unwrap-panic team-data-opt)))
        (asserts! (< (get member-count team-data) (get max-members team-data)) ERR-TEAM-FULL)

        (let ((new-members (unwrap-panic (as-max-len? (append (get members team-data) player-id) u10))))
          (map-set teams team-id (merge team-data {
            members: new-members,
            member-count: (+ (get member-count team-data) u1)
          }))

          (map-set players player-id (merge player-data { team-id: (some team-id) }))
          (ok true)
        )
      )
    )
  )
)

;; Leave current team
(define-public (leave-team)
  (let ((player-id-opt (map-get? player-principals tx-sender)))
    (asserts! (is-some player-id-opt) ERR-PLAYER-NOT-FOUND)

    (let ((player-id (unwrap-panic player-id-opt))
          (player-data (unwrap-panic (map-get? players player-id))))
      (asserts! (is-some (get team-id player-data)) ERR-TEAM-NOT-FOUND)

      (let ((team-id (unwrap-panic (get team-id player-data)))
            (team-data (unwrap-panic (map-get? teams team-id))))
        (let ((new-members (filter remove-player-from-list (get members team-data))))
          (if (is-eq (get captain team-data) player-id)
            ;; If captain is leaving, transfer captaincy or disband team
            (if (> (len new-members) u0)
              (map-set teams team-id (merge team-data {
                captain: (unwrap-panic (element-at new-members u0)),
                members: new-members,
                member-count: (- (get member-count team-data) u1)
              }))
              ;; Disband team if no members left
              (map-delete teams team-id)
            )
            ;; Regular member leaving
            (map-set teams team-id (merge team-data {
              members: new-members,
              member-count: (- (get member-count team-data) u1)
            }))
          )

          (map-set players player-id (merge player-data { team-id: none }))
          (ok true)
        )
      )
    )
  )
)

;; Update player skill rating
(define-public (update-rating (player-id uint) (new-rating uint))
  (let ((player-data-opt (map-get? players player-id)))
    (asserts! (is-some player-data-opt) ERR-PLAYER-NOT-FOUND)
    (asserts! (< new-rating u5000) ERR-INVALID-INPUT)

    (let ((player-data (unwrap-panic player-data-opt)))
      (map-set players player-id (merge player-data { skill-rating: new-rating }))
      (ok true)
    )
  )
)

;; Read-only Functions

;; Get player by ID
(define-read-only (get-player (player-id uint))
  (map-get? players player-id)
)

;; Get player by username
(define-read-only (get-player-by-username (username (string-ascii 50)))
  (match (map-get? player-usernames username)
    player-id (map-get? players player-id)
    none
  )
)

;; Get team by ID
(define-read-only (get-team (team-id uint))
  (map-get? teams team-id)
)

;; Get player's current team
(define-read-only (get-player-team (player-id uint))
  (match (map-get? players player-id)
    player-data (match (get team-id player-data)
      team-id (map-get? teams team-id)
      none
    )
    none
  )
)

;; Private Functions

;; Helper function to remove player from team member list
(define-private (remove-player-from-list (member uint))
  (let ((player-id-opt (map-get? player-principals tx-sender)))
    (if (is-some player-id-opt)
      (not (is-eq member (unwrap-panic player-id-opt)))
      true
    )
  )
)
