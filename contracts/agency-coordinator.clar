;; Agency Coordinator Contract
;; Manages multi-agency coordination, prevents duplicate aid, and facilitates collaboration

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-AGENCY-NOT-FOUND (err u501))
(define-constant ERR-ALREADY-REGISTERED (err u502))
(define-constant ERR-COORDINATION-NOT-FOUND (err u503))
(define-constant ERR-DUPLICATE-AID-DETECTED (err u504))

;; Data Variables
(define-data-var next-agency-id uint u1)
(define-data-var next-coordination-id uint u1)

;; Data Maps
(define-map registered-agencies
  { agency-id: uint }
  {
    agency-address: principal,
    organization-name: (string-ascii 100),
    agency-type: (string-ascii 50),
    contact-info: (string-ascii 200),
    verification-status: (string-ascii 20),
    specializations: (list 5 (string-ascii 50)),
    registered-by: principal,
    registration-date: uint,
    last-active: uint
  }
)

(define-map agency-verifications
  { agency-address: principal }
  { verified: bool, verified-by: principal, verification-date: uint }
)

(define-map coordination-activities
  { coordination-id: uint }
  {
    disaster-id: uint,
    lead-agency: uint,
    participating-agencies: (list 10 uint),
    activity-type: (string-ascii 50),
    target-area: (string-ascii 100),
    start-date: uint,
    end-date: (optional uint),
    status: (string-ascii 20),
    resources-shared: (list 10 (string-ascii 50))
  }
)

(define-map aid-distribution-log
  { beneficiary: principal, aid-type: (string-ascii 50), disaster-id: uint }
  {
    providing-agencies: (list 10 uint),
    total-quantity: uint,
    distribution-dates: (list 10 uint),
    last-updated: uint
  }
)

(define-map agency-capabilities
  { agency-id: uint, capability: (string-ascii 50) }
  { available: bool, capacity: uint, current-utilization: uint }
)

(define-map coordination-requests
  { request-id: uint }
  {
    requesting-agency: uint,
    disaster-id: uint,
    requested-capability: (string-ascii 50),
    urgency-level: uint,
    target-agencies: (list 5 uint),
    request-date: uint,
    status: (string-ascii 20),
    response-deadline: uint
  }
)

;; Public Functions

;; Register new agency
(define-public (register-agency
  (agency-address principal)
  (organization-name (string-ascii 100))
  (agency-type (string-ascii 50))
  (contact-info (string-ascii 200))
  (specializations (list 5 (string-ascii 50))))
  (let ((agency-id (var-get next-agency-id)))
    (asserts! (is-none (map-get? agency-verifications { agency-address: agency-address })) ERR-ALREADY-REGISTERED)

    (map-set registered-agencies
      { agency-id: agency-id }
      {
        agency-address: agency-address,
        organization-name: organization-name,
        agency-type: agency-type,
        contact-info: contact-info,
        verification-status: "pending",
        specializations: specializations,
        registered-by: tx-sender,
        registration-date: block-height,
        last-active: block-height
      }
    )

    (map-set agency-verifications
      { agency-address: agency-address }
      { verified: false, verified-by: tx-sender, verification-date: u0 }
    )

    (var-set next-agency-id (+ agency-id u1))
    (ok agency-id)
  )
)

;; Verify agency
(define-public (verify-agency (agency-id uint))
  (let ((agency (unwrap! (map-get? registered-agencies { agency-id: agency-id }) ERR-AGENCY-NOT-FOUND)))
    (map-set registered-agencies
      { agency-id: agency-id }
      (merge agency { verification-status: "verified" })
    )

    (map-set agency-verifications
      { agency-address: (get agency-address agency) }
      { verified: true, verified-by: tx-sender, verification-date: block-height }
    )
    (ok true)
  )
)

;; Create coordination activity
(define-public (create-coordination
  (disaster-id uint)
  (lead-agency uint)
  (participating-agencies (list 10 uint))
  (activity-type (string-ascii 50))
  (target-area (string-ascii 100))
  (resources-shared (list 10 (string-ascii 50))))
  (let ((coordination-id (var-get next-coordination-id)))
    (asserts! (is-verified-agency-member tx-sender) ERR-NOT-AUTHORIZED)

    (map-set coordination-activities
      { coordination-id: coordination-id }
      {
        disaster-id: disaster-id,
        lead-agency: lead-agency,
        participating-agencies: participating-agencies,
        activity-type: activity-type,
        target-area: target-area,
        start-date: block-height,
        end-date: none,
        status: "active",
        resources-shared: resources-shared
      }
    )

    (var-set next-coordination-id (+ coordination-id u1))
    (ok coordination-id)
  )
)

;; Log aid distribution to prevent duplicates
(define-public (log-aid-distribution
  (beneficiary principal)
  (aid-type (string-ascii 50))
  (disaster-id uint)
  (providing-agency uint)
  (quantity uint))
  (let ((existing-log (map-get? aid-distribution-log { beneficiary: beneficiary, aid-type: aid-type, disaster-id: disaster-id })))
    (asserts! (is-verified-agency-member tx-sender) ERR-NOT-AUTHORIZED)

    (match existing-log
      existing-record
      ;; Update existing log
      (map-set aid-distribution-log
        { beneficiary: beneficiary, aid-type: aid-type, disaster-id: disaster-id }
        (merge existing-record {
          providing-agencies: (unwrap-panic (as-max-len? (append (get providing-agencies existing-record) providing-agency) u10)),
          total-quantity: (+ (get total-quantity existing-record) quantity),
          distribution-dates: (unwrap-panic (as-max-len? (append (get distribution-dates existing-record) block-height) u10)),
          last-updated: block-height
        })
      )
      ;; Create new log
      (map-set aid-distribution-log
        { beneficiary: beneficiary, aid-type: aid-type, disaster-id: disaster-id }
        {
          providing-agencies: (list providing-agency),
          total-quantity: quantity,
          distribution-dates: (list block-height),
          last-updated: block-height
        }
      )
    )
    (ok true)
  )
)

;; Set agency capability
(define-public (set-agency-capability
  (agency-id uint)
  (capability (string-ascii 50))
  (capacity uint))
  (begin
    (asserts! (is-verified-agency-member tx-sender) ERR-NOT-AUTHORIZED)

    (map-set agency-capabilities
      { agency-id: agency-id, capability: capability }
      { available: true, capacity: capacity, current-utilization: u0 }
    )
    (ok true)
  )
)

;; Update agency activity
(define-public (update-agency-activity (agency-id uint))
  (let ((agency (unwrap! (map-get? registered-agencies { agency-id: agency-id }) ERR-AGENCY-NOT-FOUND)))
    (asserts! (is-verified-agency-member tx-sender) ERR-NOT-AUTHORIZED)

    (map-set registered-agencies
      { agency-id: agency-id }
      (merge agency { last-active: block-height })
    )
    (ok true)
  )
)

;; Complete coordination activity
(define-public (complete-coordination (coordination-id uint))
  (let ((coordination (unwrap! (map-get? coordination-activities { coordination-id: coordination-id }) ERR-COORDINATION-NOT-FOUND)))
    (asserts! (is-verified-agency-member tx-sender) ERR-NOT-AUTHORIZED)

    (map-set coordination-activities
      { coordination-id: coordination-id }
      (merge coordination {
        end-date: (some block-height),
        status: "completed"
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get agency details
(define-read-only (get-agency (agency-id uint))
  (map-get? registered-agencies { agency-id: agency-id })
)

;; Get coordination activity
(define-read-only (get-coordination (coordination-id uint))
  (map-get? coordination-activities { coordination-id: coordination-id })
)

;; Check if agency is verified
(define-read-only (is-agency-verified (agency-address principal))
  (default-to false
    (get verified
      (map-get? agency-verifications { agency-address: agency-address })
    )
  )
)

;; Check if user is verified agency member
(define-read-only (is-verified-agency-member (user principal))
  (is-agency-verified user)
)

;; Get aid distribution log
(define-read-only (get-aid-distribution-log (beneficiary principal) (aid-type (string-ascii 50)) (disaster-id uint))
  (map-get? aid-distribution-log { beneficiary: beneficiary, aid-type: aid-type, disaster-id: disaster-id })
)

;; Check for potential duplicate aid
(define-read-only (check-duplicate-aid (beneficiary principal) (aid-type (string-ascii 50)) (disaster-id uint))
  (let ((existing-log (map-get? aid-distribution-log { beneficiary: beneficiary, aid-type: aid-type, disaster-id: disaster-id })))
    (match existing-log
      log-data
      (> (len (get providing-agencies log-data)) u0)
      false
    )
  )
)

;; Get agency capability
(define-read-only (get-agency-capability (agency-id uint) (capability (string-ascii 50)))
  (map-get? agency-capabilities { agency-id: agency-id, capability: capability })
)

;; Get agency specializations
(define-read-only (get-agency-specializations (agency-id uint))
  (get specializations (map-get? registered-agencies { agency-id: agency-id }))
)
