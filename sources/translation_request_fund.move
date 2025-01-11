module myAddress::translation_request_fund {
    use std::error;
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_std::table;
    use aptos_std::table::Table;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;

    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INSUFFICIENT_DEPOSIT: u64 = 3;
    const E_MISSION_NOT_COMPLETED: u64 = 4;
    const E_NOT_AUTHORIZED: u64 = 5;
    const E_MISSION_NOT_FOUND: u64 = 6;
    const E_INVALID_RATIO: u64 = 7;

    // Resource account signer capability save
    struct ModuleData has key {
        resource_signer_cap: account::SignerCapability,
    }

    struct TranslationRequestLockElement has key, store {
        creator_account_id: address,
        original_amount: u64,
        stake: Coin<AptosCoin>
    }

    struct TranslationRequestLockTable has key {
        data: Table<String, TranslationRequestLockElement>,
    }

    fun init_module(sender: &signer) {
        let seed = vector::empty<u8>();
        vector::append(&mut seed, b"TRANSLATION_FUND_RESOURCE_ACCOUNT");

        // resource account create
        resource_account::create_resource_account(sender, seed, vector::empty<u8>());

        // get resource account signer capability
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(sender, @myAddress);

        // resource_signer create
        let resource_signer = account::create_signer_with_capability(&resource_signer_cap);

        // ModuleData save
        move_to(sender, ModuleData {
            resource_signer_cap,
        });

        // TranslationRequestLockTable save
        move_to(&resource_signer, TranslationRequestLockTable {
            data: table::new(),
        });
    }

    // get resource account signer capability
    fun get_resource_account_signer(): signer acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@myAddress);
        account::create_signer_with_capability(&module_data.resource_signer_cap)
    }

    // lock_funds
    public fun lock_funds(user: &signer, amount: u64, request_id: String) acquires ModuleData, TranslationRequestLockTable {
        let sender = signer::address_of(user);

        validate_funds(user, amount);

        // withdraw coin
        let stake_coin = coin::withdraw<AptosCoin>(user, amount);

        // lock element
        let lock_element = TranslationRequestLockElement {
            creator_account_id: sender,
            original_amount: amount,
            stake: stake_coin,
        };

        let resource_signer = get_resource_account_signer();
        let lock_table = borrow_global_mut<TranslationRequestLockTable>(signer::address_of(&resource_signer));
        table::add(&mut lock_table.data, request_id, lock_element);
    }

    // validate funds
    fun validate_funds(user: &signer, amount: u64) {
        let sender = signer::address_of(user);
        assert!(coin::balance<AptosCoin>(sender) >= amount, error::invalid_argument(E_INSUFFICIENT_DEPOSIT));
    }

    // distribute funds
    public fun distribute_funds(
        admin: &signer,
        request_id: String,
        target_address: address,
        target_amount: u64,
    ) acquires ModuleData, TranslationRequestLockTable {
        let resource_signer = get_resource_account_signer();
        let resource_addr = signer::address_of(&resource_signer);

        let lock_table = borrow_global_mut<TranslationRequestLockTable>(resource_addr);

        let lock_element = table::remove(&mut lock_table.data, request_id);
        let total_amount = coin::value(&lock_element.stake);
        assert!(total_amount >= target_amount, error::invalid_argument(E_INSUFFICIENT_DEPOSIT));

        let target_coin = coin::extract(&mut lock_element.stake, target_amount);
        coin::deposit(target_address, target_coin);

        table::add(&mut lock_table.data, request_id, lock_element);
    }

    // get locked amount
    #[view]
    public fun get_locked_amount(request_id: String): u64 acquires ModuleData, TranslationRequestLockTable {
        let resource_signer = get_resource_account_signer();
        let lock_table = borrow_global<TranslationRequestLockTable>(signer::address_of(&resource_signer));
        let lock_element = table::borrow(&lock_table.data, request_id);
        coin::value(&lock_element.stake)
    }

    // get creator address
    #[view]
    public fun get_creator_address(request_id: String): address acquires ModuleData, TranslationRequestLockTable {
        let resource_signer = get_resource_account_signer();
        let lock_table = borrow_global<TranslationRequestLockTable>(signer::address_of(&resource_signer));
        let lock_element = table::borrow(&lock_table.data, request_id);
        lock_element.creator_account_id
    }
}