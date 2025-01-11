module myAddress::translation_request {

    use aptos_std::table;
    use std::string::{Self,utf8, String};
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::table::Table;

    use myAddress::translation_request_fund;


    struct TranslationRequestElement has key, store, copy, drop{
        reviewer_account_id : address,
        creator_account_id : address,
        content_hash : String,
        total_price: u64,
    }

    struct TranslationRequestTable has key, store{
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

    public entry fun create_translation_request(admin: &signer,request_id : String,  reviewer_account_id : address, content_hash : String, total_price : u64) acquires TranslationRequestTable, TranslationRequestKeyList {
        let creator_account_id = signer::address_of(admin);

        let translation_request_element = TranslationRequestElement{
            reviewer_account_id,
            creator_account_id,
            content_hash,
            total_price,
        };

        if (exists<TranslationRequestTable>(creator_account_id)) {
            let translation_request = borrow_global_mut<TranslationRequestTable>(creator_account_id);
            table::add(&mut translation_request.data, request_id, translation_request_element);
        } else {
            let transactional_request_table = TranslationRequestTable{
                data : table::new<String, TranslationRequestElement>(),
            };

            table::add(&mut transactional_request_table.data, request_id, translation_request_element);
            move_to(admin, transactional_request_table);
        };

        if (exists<TranslationRequestKeyList>(creator_account_id)) {
            let translation_request_key_list = borrow_global_mut<TranslationRequestKeyList>(creator_account_id);
            vector::push_back(&mut translation_request_key_list.reqeust_ids, request_id);
        } else {

            let transactional_request_key_list = TranslationRequestKeyList{
                reqeust_ids : vector::empty()
            };

            vector::push_back(&mut transactional_request_key_list.reqeust_ids, request_id);
            move_to(admin, transactional_request_key_list);
        };

        translation_request_fund::lock_funds(admin, total_price, request_id);


    }
}
