;; Beneficiary System Contract
;; Manages beneficiary registration, needs assessment, and aid tracking

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-BENEFICIARY-NOT-FOUND (err u301))
(define-constant ERR-ALREADY-REGISTERED (err u302))
(define-constant ERR-INVALID-NEEDS (err u303))
(define-constant ERR-DUPLICATE-AID (err u304))

;; Data Variables
(define-data-var next-beneficiary-id uint u1)
(define-data-var next-assessment-id uint u1)

;; Data Maps
(define-map beneficiaries
  { beneficiary-id: uint }
  {
    beneficiary-address: principal,
    disaster-id: uint,
    registration-hash: (buff 32),
    family-size: uint,
    vulnerability-score: uint,
    location: (string-ascii 100),
    registered-by: principal,
    registration-date: uint,
    status: (string-ascii 20),
    last-updated: uint
  }
)

(define-map needs-assessments
  { assessment-id: uint }
  {
    beneficiary-id: uint,
    needs-list: (list 10 (string-ascii 50)),
    priority-level: uint,
    assessed-by: principal,
    assessment-date: uint,
    verified: bool
  }
)

(define-map aid-received
  { beneficiary-id: uint, aid-type: (string-ascii 50) }
  {
    total-received: uint,
    last-received-date: uint,
    received-from: (list 10 principal),
    verified: bool
  }
)

(define-map authorized-assessors
  { assessor: principal }
  { authorized: bool, organization: (string-ascii 100) }
)

(define-map beneficiary-verification
  { beneficiary-address: principal, disaster-id: uint }
  { verified: bool, verification-date: uint, verified-by: principal }
)

;; Public Functions

;; Register new beneficiary
(define-public (register-beneficiary
  (beneficiary-address principal)
  (disaster-id uint)
  (registration-hash (buff 32))
  (family-size uint)
  (location (string-ascii 100)))
  (let ((beneficiary-id (var-get next-beneficiary-id)))
    (asserts! (is-none (map-get? beneficiary-verification { beneficiary-address: beneficiary-address, disaster-id: disaster-id })) ERR-ALREADY-REGISTERED)

    (map-set beneficiaries
      { beneficiary-id: beneficiary-id }
      {
        beneficiary-address: beneficiary-address,
        disaster-id: disaster-id,
        registration-hash: registration-hash,
        family-size: family-size,
        vulnerability-score: u0,
        location: location,
        registered-by: tx-sender,
        registration-date: block-height,
        status: "registered",
        last-updated: block-height
      }
    )

    (map-set beneficiary-verification
      { beneficiary-address: beneficiary-address, disaster-id: disaster-id }
      { verified: false, verification-date: u0, verified-by: tx-sender }
    )

    (var-set next-beneficiary-id (+ beneficiary-id u1))
    (ok beneficiary-id)
  )
)

;; Conduct needs assessment
(define-public (assess-needs
  (beneficiary-id uint)
  (needs-list (list 10 (string-ascii 50)))
  (priority-level uint))
  (let (
    (beneficiary (unwrap! (map-get? beneficiaries { beneficiary-id: beneficiary-id }) ERR-BENEFICIARY-NOT-FOUND))
    (assessment-id (var-get next-assessment-id))
  )
    (asserts! (is-authorized-assessor tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= priority-level u1) (<= priority-level u5)) ERR-INVALID-NEEDS)

    (map-set needs-assessments
      { assessment-id: assessment-id }
      {
        beneficiary-id: beneficiary-id,
        needs-list: needs-list,
        priority-level: priority-level,
        assessed-by: tx-sender,
        assessment-date: block-height,
        verified: false
      }
    )

    ;; Update beneficiary vulnerability score based on priority
    (map-set beneficiaries
      { beneficiary-id: beneficiary-id }
      (merge beneficiary {
        vulnerability-score: priority-level,
        status: "assessed",
        last-updated: block-height
      })
    )

    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Record aid received
(define-public (record-aid-received
  (beneficiary-id uint)
  (aid-type (string-ascii 50))
  (quantity uint))
  (let (
    (beneficiary (unwrap! (map-get? beneficiaries { beneficiary-id: beneficiary-id }) ERR-BENEFICIARY-NOT-FOUND))
    (existing-aid (map-get? aid-received { beneficiary-id: beneficiary-id, aid-type: aid-type }))
  )
    (asserts! (> quantity u0) ERR-INVALID-NEEDS)

    (match existing-aid
      existing-record
      ;; Update existing aid record
      (map-set aid-received
        { beneficiary-id: beneficiary-id, aid-type: aid-type }
        (merge existing-record {
          total-received: (+ (get total-received existing-record) quantity),
          last-received-date: block-height,
          received-from: (unwrap-panic (as-max-len? (append (get received-from existing-record) tx-sender) u10))
        })
      )
      ;; Create new aid record
      (map-set aid-received
        { beneficiary-id: beneficiary-id, aid-type: aid-type }
        {
          total-received: quantity,
          last-received-date: block-height,
          received-from: (list tx-sender),
          verified: false
        }
      )
    )

    ;; Update beneficiary status
    (map-set beneficiaries
      { beneficiary-id: beneficiary-id }
      (merge beneficiary {
        status: "receiving-aid",
        last-updated: block-height
      })
    )

    (ok true)
  )
)

;; Verify beneficiary
(define-public (verify-beneficiary (beneficiary-id uint))
  (let ((beneficiary (unwrap! (map-get? beneficiaries { beneficiary-id: beneficiary-id }) ERR-BENEFICIARY-NOT-FOUND)))
    (asserts! (is-authorized-assessor tx-sender) ERR-NOT-AUTHORIZED)

    (map-set beneficiary-verification
      { beneficiary-address: (get beneficiary-address beneficiary), disaster-id: (get disaster-id beneficiary) }
      { verified: true, verification-date: block-height, verified-by: tx-sender }
    )

    (map-set beneficiaries
      { beneficiary-id: beneficiary-id }
      (merge beneficiary {
        status: "verified",
        last-updated: block-height
      })
    )

    (ok true)
  )
)

;; Authorize assessor
(define-public (authorize-assessor (assessor principal) (organization (string-ascii 100)))
  (begin
    (map-set authorized-assessors
      { assessor: assessor }
      { authorized: true, organization: organization }
    )
    (ok true)
  )
)

;; Update vulnerability score
(define-public (update-vulnerability-score (beneficiary-id uint) (new-score uint))
  (let ((beneficiary (unwrap! (map-get? beneficiaries { beneficiary-id: beneficiary-id }) ERR-BENEFICIARY-NOT-FOUND)))
    (asserts! (is-authorized-assessor tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-score u1) (<= new-score u5)) ERR-INVALID-NEEDS)

    (map-set beneficiaries
      { beneficiary-id: beneficiary-id }
      (merge beneficiary {
        vulnerability-score: new-score,
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get beneficiary details
(define-read-only (get-beneficiary (beneficiary-id uint))
  (map-get? beneficiaries { beneficiary-id: beneficiary-id })
)

;; Get needs assessment
(define-read-only (get-needs-assessment (assessment-id uint))
  (map-get? needs-assessments { assessment-id: assessment-id })
)

;; Get aid received
(define-read-only (get-aid-received (beneficiary-id uint) (aid-type (string-ascii 50)))
  (map-get? aid-received { beneficiary-id: beneficiary-id, aid-type: aid-type })
)

;; Check if assessor is authorized
(define-read-only (is-authorized-assessor (assessor principal))
  (default-to false
    (get authorized
      (map-get? authorized-assessors { assessor: assessor })
    )
  )
)

;; Check if beneficiary is verified
(define-read-only (is-beneficiary-verified (beneficiary-address principal) (disaster-id uint))
  (default-to false
    (get verified
      (map-get? beneficiary-verification { beneficiary-address: beneficiary-address, disaster-id: disaster-id })
    )
  )
)

;; Get beneficiary status
(define-read-only (get-beneficiary-status (beneficiary-id uint))
  (get status (map-get? beneficiaries { beneficiary-id: beneficiary-id }))
)
