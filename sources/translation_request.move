module myAddress::translation_request {

    use aptos_std::table;
    use std::string::{Self,utf8, String};
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::from_bcs::to_u8;
    use aptos_std::table::Table;
    use aptos_framework::account;
    use aptos_framework::randomness::u16_integer;

    use myAddress::translation_request_fund;


    struct TranslationRequestElement has key, store, copy, drop{
        reviewer_account_id : address,
        creator_account_id : address,
        content_hash : String,
        total_price: u64,
        content_length: u64,
    }

    struct TranslationRequestTable has key, store{
        data : Table<String, TranslationRequestElement>,
    }

    struct TranslationRequestKeyList has key, store, copy, drop{
        reqeust_ids : vector<String>,
    }

    struct TranslatedContentElement has key, store, copy, drop{
        translated_content_hash : String,
        translator_account_id : address,
        start_idx : u64,
        end_idx : u64,
    }

    struct TranslatedContentTable has key, store{
        data : Table<String, TranslatedContentElement>,
    }

    const ENO_MESSAGE: u64 = 0;



    #[view]
    public entry fun get_all_translation_request(account_id : address) : vector<String> acquires TranslationRequestKeyList {
        assert!(exists<TranslationRequestKeyList>(account_id), error::not_found(ENO_MESSAGE));
        let translation_request_key_list = borrow_global<TranslationRequestKeyList>(account_id);
        translation_request_key_list.reqeust_ids
    }

    #[view]
    public entry fun get_translation_request(request_id: String, account_id: address): TranslationRequestElement acquires TranslationRequestTable {
        // Check if TranslationRequestTable exists for the account
        assert!(exists<TranslationRequestTable>(account_id), error::not_found(ENO_MESSAGE));

        // Borrow the TranslationRequestTable
        let translation_request_table = borrow_global<TranslationRequestTable>(account_id);

        // Get the translation request element from the table
        // Note: table::contains checks if the key exists in the table
        assert!(table::contains(&translation_request_table.data, request_id), error::not_found(ENO_MESSAGE));

        // Return the TranslationRequestElement
        *table::borrow(&translation_request_table.data, request_id)
    }

    public entry fun create_translation_request(admin: &signer,request_id : String,  reviewer_account_id : address, content_hash : String, total_price : u64, content_length: u64) acquires TranslationRequestTable, TranslationRequestKeyList {
        let creator_account_id = signer::address_of(admin);

        let translation_request_element = TranslationRequestElement{
            content_length,
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


    public entry fun accept_translation_pr(admin: &signer, request_id: String, start_idx: u64, end_idx: u64, translated_content_hash: String, translator_account_id: address) acquires TranslationRequestTable, TranslatedContentTable {

        let reviewer_account_id = signer::address_of(admin);

        let translater_account_id = signer::address_of(admin);


        let translation_request = get_translation_request(request_id, translater_account_id);
        assert!(translation_request.reviewer_account_id==reviewer_account_id, error::invalid_argument(ENO_MESSAGE));

        if (exists<TranslatedContentTable>(translater_account_id)) {
            let translation_content = borrow_global_mut<TranslatedContentTable>(translater_account_id);
            let translated_content_element = TranslatedContentElement{
                translated_content_hash,
                translator_account_id,
                start_idx,
                end_idx,
            };
            table::add(&mut translation_content.data, request_id, translated_content_element);
        } else {
            let transactional_content_table = TranslatedContentTable{
                data : table::new<String, TranslatedContentElement>(),
            };

            let translated_content_element = TranslatedContentElement{
                translated_content_hash,
                translator_account_id,
                start_idx,
                end_idx,
            };
            table::add(&mut transactional_content_table.data, request_id, translated_content_element);
            move_to(admin, transactional_content_table);
        };

        let total_size = translation_request.content_length;
        let translated_size = end_idx - start_idx;

        let price = translation_request.total_price;
        let translated_price = price * translated_size / total_size;

        translation_request_fund::distribute_funds(admin, request_id, translator_account_id, translated_price);
    }

}
