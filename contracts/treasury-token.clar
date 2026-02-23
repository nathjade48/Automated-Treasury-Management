(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token t-stx)

(define-constant err-unauthorized (err u100))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-unauthorized)
    (try! (ft-transfer? t-stx amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "Treasury Share Token")
)

(define-read-only (get-symbol)
  (ok "t-STX")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance t-stx who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply t-stx))
)

(define-read-only (get-token-uri)
  (ok none)
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq contract-caller .automated-treasury) err-unauthorized)
    (ft-mint? t-stx amount recipient)
  )
)

(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (is-eq contract-caller .automated-treasury) err-unauthorized)
    (ft-burn? t-stx amount sender)
  )
)
