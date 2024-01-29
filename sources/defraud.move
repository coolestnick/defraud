module defraud::defraud {

    // Imports
    // use std::debug;
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    // Errors
    const ENotEnough: u64 = 0;
    const ERetailerPending: u64 = 1;
    const EUndeclaredClaim: u64 = 2;
    const ENotValidatedByBank: u64 = 3;
    const ENotOwner: u64 = 4;

    // Struct definitions
    struct AdminCap has key { id:UID }
    struct BankCap has key { id:UID }

    struct FraudTransac has key, store {
        id: UID,                            // Transaction object ID
        owner_address: address,             // Owner address
        bank_transac_id: u64,               // Bank Transaction ID
        police_claim_id: u64,               // Police claim ID
        
        amount: u64,                        // Transaction amount
        refund: Balance<SUI>,               // SUI Balance
        retailer_is_pending: bool,          // True if the retailer has refunded the customer

        bank_validation: bool,              // True if the bank has validated the fraud
    }

    // Module initializer
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx))
    }

    // Accessors
    public entry fun bank_transac_id(_: &BankCap, fraud_transac: &FraudTransac): u64 {
        fraud_transac.bank_transac_id
    }

    public entry fun amount(fraud_transac: &FraudTransac, ctx: &mut TxContext): u64 {
        assert!(fraud_transac.owner_address != tx_context::sender(ctx), ENotOwner);
        fraud_transac.amount
    }

    public entry fun claim_id(fraud_transac: &FraudTransac): u64 {
        fraud_transac.police_claim_id
    }

    public entry fun is_refunded(fraud_transac: &FraudTransac): u64 {
        balance::value(&fraud_transac.refund)
    }

    public entry fun bank_has_validated(fraud_transac: &FraudTransac): bool {
        fraud_transac.bank_validation
    }

    // Public - Entry functions
    public entry fun create_fraud_transac(tr_id: u64, claim_id:u64, amount: u64, ctx: &mut TxContext) {
        transfer::share_object(FraudTransac {
            owner_address: tx_context::sender(ctx),
            id: object::new(ctx),
            bank_transac_id: tr_id,
            police_claim_id: claim_id,
            amount: amount,
            refund: balance::zero(),
            retailer_is_pending: false,
            bank_validation: false
        });
    }

    public entry fun create_bank_cap(_: &AdminCap, bank_address: address, ctx: &mut TxContext) {
        transfer::transfer(BankCap { 
            id: object::new(ctx),
        }, bank_address);
    }

    public entry fun edit_claim_id(fraud_transac: &mut FraudTransac, claim_id: u64, ctx: &mut TxContext) {
        assert!(fraud_transac.owner_address != tx_context::sender(ctx), ENotOwner);
        assert!(fraud_transac.retailer_is_pending, ERetailerPending);
        fraud_transac.police_claim_id = claim_id;
    }

    public entry fun refund(fraud_transac: &mut FraudTransac, funds: &mut Coin<SUI>) {
        assert!(coin::value(funds) >= fraud_transac.amount, ENotEnough);
        assert!(fraud_transac.police_claim_id == 0, EUndeclaredClaim);

        let coin_balance = coin::balance_mut(funds);
        let paid = balance::split(coin_balance, fraud_transac.amount);

        balance::join(&mut fraud_transac.refund, paid);
    }

    public entry fun validate_with_bank(_: &BankCap, fraud_transac: &mut FraudTransac) {
        fraud_transac.bank_validation = true;
    }

    public entry fun claim_from_retailer(fraud_transac: &mut FraudTransac, retailer_address: address, ctx: &mut TxContext) {
        assert!(fraud_transac.owner_address != tx_context::sender(ctx), ENotOwner);
        assert!(fraud_transac.police_claim_id == 0, EUndeclaredClaim);

        // Transfer the balance
        let amount = balance::value(&fraud_transac.refund);
        let refund = coin::take(&mut fraud_transac.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));

        // Transfer the ownership
        fraud_transac.owner_address = retailer_address;
    }

    public entry fun claim_from_bank(fraud_transac: &mut FraudTransac, ctx: &mut TxContext) {
        assert!(fraud_transac.owner_address != tx_context::sender(ctx), ENotOwner);
        assert!(fraud_transac.retailer_is_pending, ERetailerPending);
        assert!(fraud_transac.bank_validation == false, ENotValidatedByBank);

        // Transfer the balance
        let amount = balance::value(&fraud_transac.refund);
        let refund = coin::take(&mut fraud_transac.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));
    }
}