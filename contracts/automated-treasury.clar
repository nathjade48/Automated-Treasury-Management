(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-proposal-not-found (err u103))
(define-constant err-invalid-proposal (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-stream-not-found (err u107))
(define-constant err-stream-finished (err u108))
(define-constant err-not-unlocked (err u109))
(define-constant err-no-locked-shares (err u110))
(define-constant err-not-revocable (err u111))
(define-constant err-flash-loan-failed (err u112))
(define-constant one-tenth u10)

(define-constant ROLE_ADMIN u0)
(define-constant ROLE_STRATEGIST u1)

(use-trait proposal-trait .proposal-trait.proposal-trait)
(use-trait integrated-strategy-trait .integrated-strategy-trait.integrated-strategy-trait)

(define-trait flash-loan-user-trait
  (
    (execute (uint uint) (response bool uint))
  )
)

(define-data-var treasury-balance uint u0)
(define-data-var total-invested uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var governance-threshold uint u2)
(define-data-var stream-nonce uint u0)

(define-map active-strategies
  principal
  uint
)
(define-map approved-executors
  principal
  bool
)

(define-map protocol-roles
  {
    role: uint,
    account: principal,
  }
  bool
)

(map-set protocol-roles {
  role: ROLE_ADMIN,
  account: tx-sender,
} true
)

(define-read-only (has-role
    (role uint)
    (account principal)
  )
  (default-to false
    (map-get? protocol-roles {
      role: role,
      account: account,
    })
  )
)

(define-public (grant-role
    (role uint)
    (account principal)
  )
  (begin
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    (ok (map-set protocol-roles {
      role: role,
      account: account,
    }
      true
    ))
  )
)

(define-public (revoke-role
    (role uint)
    (account principal)
  )
  (begin
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    ;; Prevent the last admin from revoking themselves
    (asserts! (not (and (is-eq role ROLE_ADMIN) (is-eq account tx-sender)))
      err-unauthorized
    )
    (ok (map-delete protocol-roles {
      role: role,
      account: account,
    }))
  )
)

(define-map governance-proposals
  uint
  {
    proposal-id: uint,
    proposal-type: (string-ascii 20),
    executor: principal,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 10),
    timestamp: uint,
  }
)
(define-map voter-records
  {
    proposal-id: uint,
    voter: principal,
  }
  bool
)

(define-map vesting-streams
  uint
  {
    recipient: principal,
    total-amount: uint,
    claimed-amount: uint,
    start-height: uint,
    end-height: uint,
    active: bool,
    revocable: bool,
  }
)
(define-map voting-escrow-balances
  principal
  {
    locked-shares: uint,
    unlock-height: uint,
  }
)

(define-public (lock-shares-for-voting
    (share-amount uint)
    (lock-period uint)
  )
  (let (
      (current-shares (unwrap-panic (contract-call? .treasury-token get-balance tx-sender)))
      (existing-lock (default-to {
        locked-shares: u0,
        unlock-height: u0,
      }
        (map-get? voting-escrow-balances tx-sender)
      ))
    )
    (asserts! (> share-amount u0) err-invalid-amount)
    (asserts! (> lock-period u0) err-invalid-amount)
    (asserts!
      (>= current-shares (+ (get locked-shares existing-lock) share-amount))
      err-insufficient-funds
    )

    (let (
        (new-locked-amount (+ (get locked-shares existing-lock) share-amount))
        (new-unlock-height (+ stacks-block-height lock-period))
      )
      (let ((final-unlock-height (if (> new-unlock-height (get unlock-height existing-lock))
          new-unlock-height
          (get unlock-height existing-lock)
        )))
        (map-set voting-escrow-balances tx-sender {
          locked-shares: new-locked-amount,
          unlock-height: final-unlock-height,
        })
        (ok true)
      )
    )
  )
)

(define-public (unlock-shares)
  (let ((lock-info (map-get? voting-escrow-balances tx-sender)))
    (asserts! (is-some lock-info) err-no-locked-shares)
    (let ((current-lock (unwrap! lock-info err-no-locked-shares)))
      (asserts! (> (get locked-shares current-lock) u0) err-no-locked-shares)
      (asserts! (>= stacks-block-height (get unlock-height current-lock))
        err-not-unlocked
      )

      (map-delete voting-escrow-balances tx-sender)
      (ok (get locked-shares current-lock))
    )
  )
)
(define-public (deposit-to-treasury (amount uint))
  (let (
      (total-assets (+ (var-get treasury-balance) (var-get total-invested)))
      (total-shares (unwrap-panic (contract-call? .treasury-token get-total-supply)))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((shares-to-mint (if (is-eq total-shares u0)
        amount
        (/ (* amount total-shares) total-assets)
      )))
      (var-set treasury-balance (+ (var-get treasury-balance) amount))
      (try! (contract-call? .treasury-token mint shares-to-mint tx-sender))
      (ok shares-to-mint)
    )
  )
)

(define-public (withdraw-from-treasury (share-amount uint))
  (let (
      (recipient tx-sender)
      (total-assets (+ (var-get treasury-balance) (var-get total-invested)))
      (total-shares (unwrap-panic (contract-call? .treasury-token get-total-supply)))
      (locked-info (default-to {
        locked-shares: u0,
        unlock-height: u0,
      }
        (map-get? voting-escrow-balances tx-sender)
      ))
      (current-shares (unwrap-panic (contract-call? .treasury-token get-balance tx-sender)))
    )
    (asserts! (> share-amount u0) err-invalid-amount)
    (asserts! (> total-shares u0) err-invalid-amount)
    (asserts!
      (<= share-amount (- current-shares (get locked-shares locked-info)))
      err-insufficient-funds
    )
    (let ((stx-to-return (/ (* share-amount total-assets) total-shares)))
      (asserts! (<= stx-to-return (var-get treasury-balance))
        err-insufficient-funds
      )
      (try! (contract-call? .treasury-token burn share-amount tx-sender))
      (var-set treasury-balance (- (var-get treasury-balance) stx-to-return))
      (try! (as-contract (stx-transfer? stx-to-return tx-sender recipient)))
      (ok stx-to-return)
    )
  )
)

(define-public (flash-loan
    (receiver <flash-loan-user-trait>)
    (amount uint)
  )
  (let (
      (fee (/ (* amount u5) u1000)) ;; 0.5% fee
      (total-due (+ amount fee))
      (treasury (var-get treasury-balance))
      (caller tx-sender)
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount treasury) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? amount tx-sender caller)))
    (var-set treasury-balance (- treasury amount))

    (asserts! (unwrap! (contract-call? receiver execute amount fee) err-flash-loan-failed) err-flash-loan-failed)
    
    (try! (stx-transfer? total-due caller (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) total-due))
    
    (ok fee)
  )
)

(define-public (invest-in-strategy
    (strategy <integrated-strategy-trait>)
    (amount uint)
  )
  (let (
      (strategy-address (contract-of strategy))
      (current-invested (default-to u0 (map-get? active-strategies strategy-address)))
      (treasury (var-get treasury-balance))
    )
    (asserts!
      (or (has-role ROLE_ADMIN tx-sender) (has-role ROLE_STRATEGIST tx-sender))
      err-unauthorized
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount treasury) err-insufficient-funds)

    (try! (as-contract (contract-call? strategy deposit amount)))

    (let ((new-invested (+ current-invested amount)))
      (map-set active-strategies strategy-address new-invested)
      (var-set total-invested (+ (var-get total-invested) amount))
      (var-set treasury-balance (- treasury amount))
      (ok true)
    )
  )
)

(define-public (claim-strategy-rewards (strategy <integrated-strategy-trait>))
  (let (
      (strategy-address (contract-of strategy))
      (current-allocation (default-to u0 (map-get? active-strategies strategy-address)))
    )
    (asserts!
      (or (has-role ROLE_ADMIN tx-sender) (has-role ROLE_STRATEGIST tx-sender))
      err-unauthorized
    )
    (asserts! (> current-allocation u0) err-insufficient-funds)

    (let ((harvested-amount (try! (as-contract (contract-call? strategy harvest)))))
      (var-set treasury-balance (+ (var-get treasury-balance) harvested-amount))
      (ok harvested-amount)
    )
  )
)

(define-public (withdraw-from-strategy
    (strategy <integrated-strategy-trait>)
    (amount uint)
  )
  (let (
      (strategy-address (contract-of strategy))
      (current-invested (default-to u0 (map-get? active-strategies strategy-address)))
    )
    (asserts!
      (or (has-role ROLE_ADMIN tx-sender) (has-role ROLE_STRATEGIST tx-sender))
      err-unauthorized
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount current-invested) err-insufficient-funds)

    (try! (as-contract (contract-call? strategy withdraw amount)))

    (let ((new-invested (- current-invested amount)))
      (map-set active-strategies strategy-address new-invested)
      (var-set total-invested (- (var-get total-invested) amount))
      (var-set treasury-balance (+ (var-get treasury-balance) amount))
      (ok true)
    )
  )
)

(define-public (create-proposal (proposal <proposal-trait>))
  (begin
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    (let (
        (proposal-id (var-get proposal-counter))
        (executor (contract-of proposal))
      )
      (begin
        (map-set governance-proposals proposal-id {
          proposal-id: proposal-id,
          proposal-type: "executable",
          executor: executor,
          votes-for: u0,
          votes-against: u0,
          status: "active",
          timestamp: stacks-block-height,
        })
        (map-set approved-executors executor true)
        (var-set proposal-counter (+ proposal-id u1))
        (ok proposal-id)
      )
    )
  )
)

(define-public (vote-on-proposal
    (proposal-id uint)
    (vote-for bool)
  )
  (let (
      (proposal (map-get? governance-proposals proposal-id))
      (lock-info (default-to {
        locked-shares: u0,
        unlock-height: u0,
      }
        (map-get? voting-escrow-balances tx-sender)
      ))
      (voter-stake (get locked-shares lock-info))
    )
    (asserts! (is-some proposal) err-proposal-not-found)
    (asserts! (> voter-stake u0) err-insufficient-funds)

    (asserts!
      (not (default-to false
        (map-get? voter-records {
          proposal-id: proposal-id,
          voter: tx-sender,
        })
      ))
      err-already-voted
    )
    (let ((current-proposal (unwrap! proposal err-proposal-not-found)))
      (begin
        (map-set voter-records {
          proposal-id: proposal-id,
          voter: tx-sender,
        }
          true
        )
        (if vote-for
          (let ((new-votes-for (+ (get votes-for current-proposal) voter-stake)))
            (map-set governance-proposals proposal-id
              (merge current-proposal { votes-for: new-votes-for })
            )
          )
          (let ((new-votes-against (+ (get votes-against current-proposal) voter-stake)))
            (map-set governance-proposals proposal-id
              (merge current-proposal { votes-against: new-votes-against })
            )
          )
        )
        (ok true)
      )
    )
  )
)

(define-public (execute-proposal
    (proposal-id uint)
    (proposal <proposal-trait>)
  )
  (let ((proposal-data (map-get? governance-proposals proposal-id)))
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    (asserts! (is-some proposal-data) err-proposal-not-found)
    (let ((current-proposal (unwrap! proposal-data err-proposal-not-found)))
      (asserts! (is-eq (contract-of proposal) (get executor current-proposal))
        err-invalid-proposal
      )
      (asserts! (is-eq (get status current-proposal) "active")
        err-invalid-proposal
      )
      (asserts!
        (>= (get votes-for current-proposal) (var-get governance-threshold))
        err-invalid-proposal
      )
      (let ((executed-proposal (merge current-proposal { status: "executed" })))
        (map-set governance-proposals proposal-id executed-proposal)
        (try! (as-contract (contract-call? proposal execute)))
        (ok true)
      )
    )
  )
)

(define-public (create-vesting-stream
    (recipient principal)
    (amount uint)
    (duration uint)
    (revocable bool)
  )
  (begin
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-amount)
    (asserts! (<= amount (var-get treasury-balance)) err-insufficient-funds)
    (let (
        (stream-id (var-get stream-nonce))
        (end-height (+ stacks-block-height duration))
      )
      (map-set vesting-streams stream-id {
        recipient: recipient,
        total-amount: amount,
        claimed-amount: u0,
        start-height: stacks-block-height,
        end-height: end-height,
        active: true,
        revocable: revocable,
      })
      (var-set treasury-balance (- (var-get treasury-balance) amount))
      (var-set stream-nonce (+ stream-id u1))
      (ok stream-id)
    )
  )
)

(define-public (claim-vested-funds (stream-id uint))
  (let ((stream (unwrap! (map-get? vesting-streams stream-id) err-stream-not-found)))
    (asserts! (get active stream) err-stream-finished)
    (asserts! (is-eq tx-sender (get recipient stream)) err-unauthorized)
    (let (
        (current-height stacks-block-height)
        (start (get start-height stream))
        (end (get end-height stream))
        (total (get total-amount stream))
        (claimed (get claimed-amount stream))
      )
      (let ((vested (if (>= current-height end)
          total
          (/ (* total (- current-height start)) (- end start))
        )))
        (let ((claimable (- vested claimed)))
          (asserts! (> claimable u0) err-insufficient-funds)
          (try! (as-contract (stx-transfer? claimable tx-sender (get recipient stream))))
          (map-set vesting-streams stream-id
            (merge stream {
              claimed-amount: vested,
              active: (< vested total),
            })
          )
          (ok claimable)
        )
      )
    )
  )
)

(define-public (revoke-vesting-stream (stream-id uint))
  (let ((stream (unwrap! (map-get? vesting-streams stream-id) err-stream-not-found)))
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    (asserts! (get active stream) err-stream-finished)
    (asserts! (get revocable stream) err-not-revocable)
    (let (
         (current-height stacks-block-height)
        (start (get start-height stream))
        (end (get end-height stream))
        (total (get total-amount stream))
        (claimed (get claimed-amount stream))
      )
      (let ((vested (if (>= current-height end)
          total
          (/ (* total (- current-height start)) (- end start))
        )))
        (let ((unvested (- total vested)))
          (map-set vesting-streams stream-id
            (merge stream {
              total-amount: vested,
              end-height: current-height,
              active: (< claimed vested),
            })
          )
          (var-set treasury-balance (+ (var-get treasury-balance) unvested))
          (ok unvested)
        )
      )
    )
  )
)

(define-public (set-governance-threshold (new-threshold uint))
  (begin
    (asserts! (has-role ROLE_ADMIN tx-sender) err-unauthorized)
    (var-set governance-threshold new-threshold)
    (ok true)
  )
)

(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

(define-read-only (get-total-invested)
  (var-get total-invested)
)

(define-read-only (get-strategy-allocation (strategy principal))
  (default-to u0 (map-get? active-strategies strategy))
)

(define-read-only (get-total-assets)
  (+ (var-get treasury-balance) (var-get total-invested))
)

(define-read-only (get-exchange-rate)
  (let (
      (total-shares (unwrap-panic (contract-call? .treasury-token get-total-supply)))
      (total-assets (get-total-assets))
    )
    (if (is-eq total-shares u0)
      u1000000
      (/ (* total-assets u1000000) total-shares)
    )
  )
)

(define-read-only (get-user-deposit (user principal))
  (let (
      (user-shares (unwrap-panic (contract-call? .treasury-token get-balance user)))
      (total-shares (unwrap-panic (contract-call? .treasury-token get-total-supply)))
      (total-assets (get-total-assets))
    )
    (if (is-eq total-shares u0)
      u0
      (/ (* user-shares total-assets) total-shares)
    )
  )
)

(define-read-only (get-voting-power (user principal))
  (get locked-shares
    (default-to {
      locked-shares: u0,
      unlock-height: u0,
    }
      (map-get? voting-escrow-balances user)
    ))
)

(define-read-only (get-unlock-height (user principal))
  (get unlock-height
    (default-to {
      locked-shares: u0,
      unlock-height: u0,
    }
      (map-get? voting-escrow-balances user)
    ))
)

(define-read-only (get-governance-threshold)
  (var-get governance-threshold)
)

(define-read-only (get-vesting-stream (stream-id uint))
  (map-get? vesting-streams stream-id)
)

(define-read-only (get-stream-claimable-amount (stream-id uint))
  (let ((stream (unwrap! (map-get? vesting-streams stream-id) u0)))
    (let (
        (current-height stacks-block-height)
        (start (get start-height stream))
        (end (get end-height stream))
        (total (get total-amount stream))
        (claimed (get claimed-amount stream))
      )
      (if (not (get active stream))
        u0
        (let ((vested (if (>= current-height end)
            total
            (/ (* total (- current-height start)) (- end start))
          )))
          (- vested claimed)
        )
      )
    )
  )
)
