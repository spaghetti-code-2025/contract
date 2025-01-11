module myAddress::translation_request_fund {
    use std::error;
    use std::signer;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;

    const E_INSUFFICIENT_DEPOSIT: u64 = 1;
    const E_MISSION_NOT_COMPLETED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_MISSION_NOT_FOUND: u64 = 4;
    const E_INVALID_RATIO: u64 = 5;

    struct TranslationRequestLockElement has key, store {
        creator_account_id: address,
        original_amount: u64,
        stake: Coin<AptosCoin>
    }

    struct TranslationRequestLockTable has key {
        data: Table<String, TranslationRequestLockElement>,
    }

    fun init_module(sender: &signer) {
        move_to(sender, TranslationRequestLockTable {
            data: table::new(),
        });
    }

    public fun lock_funds(user: &signer, amount: u64, request_id: String) acquires TranslationRequestLockTable {
        let sender = signer::address_of(user);

        validate_funds(user, amount);

        let stake_coin = coin::withdraw<AptosCoin>(user, amount);

        let lock_element = TranslationRequestLockElement {
            creator_account_id: sender,
            original_amount: amount,
            stake: stake_coin,
        };

        let lock_table = borrow_global_mut<TranslationRequestLockTable>(@myAddress);
        table::add(&mut lock_table.data, request_id, lock_element);
    }

    fun validate_funds(user: &signer, amount: u64) {
        let sender = signer::address_of(user);
        assert!(coin::balance<AptosCoin>(sender) >= amount, error::invalid_argument(E_INSUFFICIENT_DEPOSIT));
    }

    public fun distribute_funds(
        admin: &signer,
        request_id: String,
        target_address: address,
        target_amount: u64,
    ) acquires TranslationRequestLockTable {
        let lock_table = borrow_global_mut<TranslationRequestLockTable>(@myAddress);

        let lock_element = table::remove(&mut lock_table.data, request_id);
        let total_amount = coin::value(&lock_element.stake);
        assert!(total_amount >= target_amount, error::invalid_argument(E_INSUFFICIENT_DEPOSIT));

        let target_coin = coin::extract(&mut lock_element.stake, target_amount);
        coin::deposit(target_address, target_coin);

        table::add(&mut lock_table.data, request_id, lock_element);
    }

    #[view]
    public fun get_locked_amount(request_id: String): u64 acquires TranslationRequestLockTable {
        let lock_table = borrow_global<TranslationRequestLockTable>(@myAddress);
        let lock_element = table::borrow(&lock_table.data, request_id);
        coin::value(&lock_element.stake)
    }

    #[view]
    public fun get_creator_address(request_id: String): address acquires TranslationRequestLockTable {
        let lock_table = borrow_global<TranslationRequestLockTable>(@myAddress);
        let lock_element = table::borrow(&lock_table.data, request_id);
        lock_element.creator_account_id
    }
}