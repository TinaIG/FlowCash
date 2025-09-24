;; FlowCash - Continuous Payment Streaming Protocol
;; A smart contract for seamless payment flows and automated value distribution on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-flow-not-found (err u601))
(define-constant err-balance-insufficient (err u602))
(define-constant err-invalid-params (err u603))
(define-constant err-flow-ended (err u604))
(define-constant err-unauthorized (err u605))

;; Data Variables
(define-data-var service-fee-rate uint u300) ;; 3% service fee
(define-data-var minimum-flow-amount uint u1000) ;; Minimum 1000 micro-STX per flow

;; Data Maps
(define-map cash-flows
    { flow-id: uint }
    {
        sender: principal,
        receiver: principal,
        tokens-per-block: uint,
        total-amount: uint,
        start-block: uint,
        end-block: uint,
        withdrawn-tokens: uint,
        flow-active: bool
    }
)

(define-map user-balances
    { user: principal }
    { balance: uint }
)

(define-map flow-counter
    { counter-active: bool }
    { total-flows: uint }
)

;; Initialize flow counter
(map-set flow-counter { counter-active: true } { total-flows: u0 })

;; Read-only functions

(define-read-only (get-flow-details (flow-id uint))
    (map-get? cash-flows { flow-id: flow-id })
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-service-fee-rate)
    (var-get service-fee-rate)
)

(define-read-only (get-minimum-flow-amount)
    (var-get minimum-flow-amount)
)

(define-read-only (calculate-available-tokens (flow-id uint))
    (match (map-get? cash-flows { flow-id: flow-id })
        flow-details
        (let
            (
                (current-block stacks-block-height)
                (start-block (get start-block flow-details))
                (end-block (get end-block flow-details))
                (tokens-per-block (get tokens-per-block flow-details))
                (withdrawn-tokens (get withdrawn-tokens flow-details))
                (flow-active (get flow-active flow-details))
            )
            (if (and flow-active (>= current-block start-block))
                (let
                    (
                        (blocks-elapsed (if (>= current-block end-block)
                                       (- end-block start-block)
                                       (- current-block start-block)))
                        (tokens-earned (* blocks-elapsed tokens-per-block))
                    )
                    (if (>= tokens-earned withdrawn-tokens)
                        (ok (- tokens-earned withdrawn-tokens))
                        (ok u0)
                    )
                )
                (ok u0)
            )
        )
        (err err-flow-not-found)
    )
)

;; Public functions

(define-public (deposit-funds (amount uint))
    (let
        (
            (current-balance (get-user-balance tx-sender))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-balances 
            { user: tx-sender } 
            { balance: (+ current-balance amount) }
        )
        (ok true)
    )
)

(define-public (withdraw-funds (amount uint))
    (let
        (
            (current-balance (get-user-balance tx-sender))
        )
        (asserts! (>= current-balance amount) err-balance-insufficient)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set user-balances 
            { user: tx-sender } 
            { balance: (- current-balance amount) }
        )
        (ok true)
    )
)

(define-public (create-cash-flow (receiver principal) (tokens-per-block uint) (flow-duration uint))
    (let
        (
            (flow-id (+ (default-to u0 (get total-flows (map-get? flow-counter { counter-active: true }))) u1))
            (total-amount (* tokens-per-block flow-duration))
            (sender-balance (get-user-balance tx-sender))
        )
        ;; Validate inputs
        (asserts! (>= total-amount (var-get minimum-flow-amount)) err-invalid-params)
        (asserts! (> tokens-per-block u0) err-invalid-params)
        (asserts! (> flow-duration u0) err-invalid-params)
        (asserts! (>= sender-balance total-amount) err-balance-insufficient)
        
        ;; Reserve tokens from sender balance
        (map-set user-balances 
            { user: tx-sender } 
            { balance: (- sender-balance total-amount) }
        )
        
        ;; Create cash flow
        (map-set cash-flows
            { flow-id: flow-id }
            {
                sender: tx-sender,
                receiver: receiver,
                tokens-per-block: tokens-per-block,
                total-amount: total-amount,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height flow-duration),
                withdrawn-tokens: u0,
                flow-active: true
            }
        )
        
        ;; Update flow counter
        (map-set flow-counter { counter-active: true } { total-flows: flow-id })
        
        (ok flow-id)
    )
)

(define-public (claim-flow-tokens (flow-id uint))
    (match (map-get? cash-flows { flow-id: flow-id })
        flow-details
        (let
            (
                (receiver (get receiver flow-details))
                (available-result (calculate-available-tokens flow-id))
            )
            (asserts! (is-eq tx-sender receiver) err-unauthorized)
            (asserts! (get flow-active flow-details) err-flow-ended)
            
            (match available-result
                available-amount
                (if (> available-amount u0)
                    (let
                        (
                            (service-fee (/ (* available-amount (var-get service-fee-rate)) u10000))
                            (net-claim (- available-amount service-fee))
                            (current-withdrawn (get withdrawn-tokens flow-details))
                        )
                        ;; Transfer to receiver
                        (try! (as-contract (stx-transfer? net-claim tx-sender receiver)))
                        
                        ;; Transfer service fee to owner
                        (try! (as-contract (stx-transfer? service-fee tx-sender contract-owner)))
                        
                        ;; Update flow withdrawn amount
                        (map-set cash-flows
                            { flow-id: flow-id }
                            (merge flow-details { withdrawn-tokens: (+ current-withdrawn available-amount) })
                        )
                        
                        (ok net-claim)
                    )
                    (ok u0)
                )
                error-code
                error-code
            )
        )
        err-flow-not-found
    )
)

(define-public (cancel-cash-flow (flow-id uint))
    (match (map-get? cash-flows { flow-id: flow-id })
        flow-details
        (let
            (
                (sender (get sender flow-details))
                (receiver (get receiver flow-details))
                (total-amount (get total-amount flow-details))
                (withdrawn-tokens (get withdrawn-tokens flow-details))
            )
            (asserts! (or (is-eq tx-sender sender) (is-eq tx-sender receiver)) err-unauthorized)
            (asserts! (get flow-active flow-details) err-flow-ended)
            
            ;; Process any pending claim for receiver
            (match (calculate-available-tokens flow-id)
                available-amount
                (if (> available-amount u0)
                    (let
                        (
                            (service-fee (/ (* available-amount (var-get service-fee-rate)) u10000))
                            (net-claim (- available-amount service-fee))
                        )
                        (try! (as-contract (stx-transfer? net-claim tx-sender receiver)))
                        (try! (as-contract (stx-transfer? service-fee tx-sender contract-owner)))
                        (map-set cash-flows
                            { flow-id: flow-id }
                            (merge flow-details { withdrawn-tokens: (+ withdrawn-tokens available-amount) })
                        )
                        true
                    )
                    true
                )
                error-code
                false
            )
            
            ;; Return unused tokens to sender
            (let
                (
                    (final-withdrawn (get withdrawn-tokens (unwrap-panic (map-get? cash-flows { flow-id: flow-id }))))
                    (unused-tokens (- total-amount final-withdrawn))
                    (sender-balance (get-user-balance sender))
                )
                (if (> unused-tokens u0)
                    (map-set user-balances 
                        { user: sender } 
                        { balance: (+ sender-balance unused-tokens) }
                    )
                    true
                )
            )
            
            ;; Mark flow as inactive
            (map-set cash-flows
                { flow-id: flow-id }
                (merge flow-details { flow-active: false })
            )
            
            (ok true)
        )
        err-flow-not-found
    )
)

;; Owner functions

(define-public (update-service-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee-rate u2000) err-invalid-params) ;; Max 20% fee
        (var-set service-fee-rate new-fee-rate)
        (ok true)
    )
)

(define-public (update-minimum-flow-amount (new-minimum uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set minimum-flow-amount new-minimum)
        (ok true)
    )
)