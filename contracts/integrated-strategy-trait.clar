(define-trait integrated-strategy-trait
  (
    (deposit (uint) (response bool uint))
    (withdraw (uint) (response bool uint))
    (harvest () (response uint uint))
    (get-strategy-tvl () (response uint uint))
  )
)
