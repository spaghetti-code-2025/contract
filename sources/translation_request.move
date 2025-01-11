module myAddress::translation_request {

    use aptos_std::table;
    use std::string::{Self,utf8, String};
    use std::error;
    use std::signer;
    use std::hash;
    use std::vector;
    use aptos_std::string_utils;
    use aptos_std::table::Table;
    use aptos_framework::account;

    use aptos_framework::coin::{Self as Coin, withdraw};
    use aptos_framework::aptos_coin::AptosCoin;



    struct TranslationRequestElement has key, store, copy, drop{
        reviewer_account_id : address,
        creator_account_id : address,
        content_hash : String,
        price : u64,
    }

    struct TranslationRequestTable has key, store, copy, drop{
        data : Table<String, TranslationRequestElement>,
    }

    struct TranslationRequestKeyList has key, store, copy, drop{
        reqeust_ids : vector<String>,
    }

    const ENO_MESSAGE: u64 = 0;



    #[view]
    public fun get_all_translation_request(account_id : address) : vector<String> acquires TranslationRequestKeyList {
        assert!(exists<TranslationRequestKeyList>(account_id), error::not_found(ENO_MESSAGE));
        let translation_request_key_list = borrow_global<TranslationRequestKeyList>(account_id);
        translation_request_key_list.reqeust_ids
    }

    public fun create_translation_request(admin: &signer, request_id : String, reviewer_account_id : address, content_hash : String, price : u64) acquires TranslationRequestTable, TranslationRequestKeyList {
        let creator_account_id = signer::address_of(admin);

        let request_id = string::utf8(hash::sha2_256(*string::bytes(&content_hash)));


        let translation_request_element = TranslationRequestElement{

            reviewer_account_id,
            creator_account_id,
            content_hash,
            price,
        };

        if (exists<TranslationRequestTable>(creator_account_id)) {
            let translation_request = borrow_global_mut<TranslationRequestTable>(creator_account_id);
            table::add(&mut translation_request.data, request_id, translation_request_element);
        } else {
            let transactional_request_table = TranslationRequestTable{
                data : table<String, TranslationRequestElement>::new(),
            };

            table::add(&mut transactional_request_table.data, request_id, translation_request_element);
            move_to(admin, transactional_request_table);
        };

        if (exists<TranslationRequestKeyList>(creator_account_id)) {
            let translation_request_key_list = borrow_global_mut<TranslationRequestKeyList>(creator_account_id);
            vector::push_back(&mut translation_request_key_list.reqeust_ids, request_id);
        } else {

            let transactional_request_key_list = TranslationRequestKeyList{
                reqeust_ids : vector<String>::empty()
            };

            vector::push_back(&mut transactional_request_key_list.reqeust_ids, request_id);
            move_to(admin, transactional_request_key_list);
        }


    }



}
