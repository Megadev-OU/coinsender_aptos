module multisend::sender {
    use std::error;
    use std::vector;
    use std::signer::address_of;
    // use std::debug;

    use aptos_framework::coin;

    const FECIPIENTS_AND_AMOUNTS_DO_NOT_MATCH: u64 = 1;
    const USER_IS_NOT_ADMIN: u64 = 2;
    const INSUFFICIENT_FUNDS: u64 = 3;

    struct Management has key {
        fee: u64,
        admin: address,
        bank: address
    }

    public entry fun create(sender: &signer, bank_account: address, fee: u64) {
        move_to(
            sender,
            Management {
                fee: fee,
                admin: address_of(sender),
                bank: bank_account
            },
        );
    }


    public entry fun multisend<CoinType>(sender: &signer, recipients: vector<address>, amounts: vector<u64>) acquires Management {

        let num_recipients = vector::length(&recipients);
        assert!(
            num_recipients == vector::length(&amounts),
            error::invalid_argument(FECIPIENTS_AND_AMOUNTS_DO_NOT_MATCH),
        );

        let fee = borrow_global<Management>(@multisend).fee;

        let amount_sum: u64 = 0;
        let i = 0;
        while (i < num_recipients) {
            let amount = *vector::borrow(&amounts, i);
            amount_sum = amount_sum + amount;
            i = i + 1;
        };

        let fee_amount = (amount_sum / 100) * fee;
        let sufficient_funds = amount_sum + fee_amount;
        assert!(
            sufficient_funds <= coin::balance<CoinType>(address_of(sender)),
            error::invalid_argument(INSUFFICIENT_FUNDS),
        );

        let fee_to_charge = coin::withdraw<CoinType>(sender, fee_amount);
        let bank = borrow_global<Management>(@multisend).bank;
        coin::deposit(bank, fee_to_charge);

        let i = 0;
        while (i < num_recipients) {
            let recipient = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);
            let coins = coin::withdraw<CoinType>(sender, amount);
            coin::deposit(recipient, coins);
            i = i + 1;
        };
    }


    public entry fun update_fee(
        sender: &signer,
        fee: u64,
    ) acquires Management {
        let config = borrow_global_mut<Management>(@multisend);
        assert!(
            address_of(sender) == config.admin,
            error::invalid_argument(USER_IS_NOT_ADMIN),
        );
        config.fee = fee;
    }

    public entry fun update_admin(
        sender: &signer,
        new_admin: address,
    ) acquires Management {
        let config = borrow_global_mut<Management>(@multisend);
        assert!(
            address_of(sender) == config.admin,
            error::invalid_argument(USER_IS_NOT_ADMIN),
        );
        config.admin = new_admin;
    }

    public entry fun update_bank_account(
        sender: &signer,
        new_bank_account: address,
    ) acquires Management {
        let config = borrow_global_mut<Management>(@multisend);
        assert!(
            address_of(sender) == config.admin,
            error::invalid_argument(USER_IS_NOT_ADMIN),
        );
        config.bank = new_bank_account;
    }

    #[view]
    public fun get_fee(): u64 acquires Management {
        borrow_global_mut<Management>(@multisend).fee
    }

    #[view]
    public fun get_admin(): address acquires Management {
        borrow_global_mut<Management>(@multisend).admin
    }

    #[view]
    public fun get_bank_account(): address acquires Management {
        borrow_global_mut<Management>(@multisend).bank
    }


    #[test_only]
    use aptos_framework::aptos_account::create_account;

    #[test_only]
    use aptos_framework::aptos_coin::AptosCoin;


    #[test(bank = @0x121, contract = @multisend, sender = @0x123, recipient_1 = @0x124, recipient_2 = @0x125, core = @0x1)]
    public entry fun test_mutlisend(bank: &signer, contract: &signer, sender: &signer,
                                    recipient_1: &signer, recipient_2: &signer, core: &signer) acquires Management {

        let bank_addr = address_of(bank);
        let sender_addr = address_of(sender);
        let recipient_1_addr = address_of(recipient_1);
        let recipient_2_addr = address_of(recipient_2);
        create_account(bank_addr);
        create_account(@multisend);
        create_account(sender_addr);
        create_account(recipient_1_addr);
        create_account(recipient_2_addr);

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(core);
        create(contract, bank_addr, 10);

        coin::deposit(sender_addr, coin::mint(1100, &mint_cap));

        assert!(coin::balance<AptosCoin>(bank_addr) == 0, 0);
        assert!(coin::balance<AptosCoin>(sender_addr) == 1100, 0);
        assert!(coin::balance<AptosCoin>(recipient_1_addr) == 0, 2);
        assert!(coin::balance<AptosCoin>(recipient_2_addr) == 0, 3);

        multisend<AptosCoin>(sender, vector[recipient_1_addr, recipient_2_addr], vector[800, 200]);

        assert!(coin::balance<AptosCoin>(bank_addr) == 100, 0);
        assert!(coin::balance<AptosCoin>(sender_addr) == 0, 1);
        assert!(coin::balance<AptosCoin>(recipient_1_addr) == 800, 2);
        assert!(coin::balance<AptosCoin>(recipient_2_addr) == 200, 3);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test_only]
    use std::string;

    #[test_only]
    struct TestCoin {}

    #[test_only]
    struct TestCoinCapabilities has key {
        burn_cap: coin::BurnCapability<TestCoin>,
        freeze_cap: coin::FreezeCapability<TestCoin>,
        mint_cap: coin::MintCapability<TestCoin>,
    }

    #[test(token = @0x9ac5062617c80912e867abe2eaaece5cc18c208037696a4dbbde896e7b4a5aaa, bank = @0x121,
        contract = @multisend, sender = @0x123, recipient_1 = @0x124, recipient_2 = @0x125)]
    public entry fun test_mutlisend_token(token: &signer, contract: &signer, bank: &signer, sender: &signer,
                                          recipient_1: &signer, recipient_2: &signer) acquires Management {

        aptos_framework::account::create_account_for_test(address_of(token));

        // aptos_framework::aggregator_factory::initialize_aggregator_factory_for_test(token);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoin>(
            token,
            string::utf8(b"Test Coin"),
            string::utf8(b"Test Coin"),
            6,
            false,
        );

        let sender_addr = address_of(sender);
        create_account(sender_addr);

        coin::register<TestCoin>(token);
        coin::register<TestCoin>(sender);

        let coins_minted = coin::mint<TestCoin>(1100, &mint_cap);
        coin::deposit(sender_addr, coins_minted);

        let bank_addr = address_of(bank);
        let recipient_1_addr = address_of(recipient_1);
        let recipient_2_addr = address_of(recipient_2);
        create_account(bank_addr);
        create_account(recipient_1_addr);
        create_account(recipient_2_addr);

        create(contract, bank_addr, 10);

        coin::register<TestCoin>(bank);
        coin::register<TestCoin>(recipient_1);
        coin::register<TestCoin>(recipient_2);

        assert!(coin::balance<TestCoin>(bank_addr) == 0, 0);
        assert!(coin::balance<TestCoin>(sender_addr) == 1100, 0);
        assert!(coin::balance<TestCoin>(recipient_1_addr) == 0, 2);
        assert!(coin::balance<TestCoin>(recipient_2_addr) == 0, 3);

        multisend<TestCoin>(sender, vector[recipient_1_addr, recipient_2_addr], vector[800, 200]);


        assert!(coin::balance<TestCoin>(bank_addr) == 100, 0);
        assert!(coin::balance<TestCoin>(sender_addr) == 0, 1);
        assert!(coin::balance<TestCoin>(recipient_1_addr) == 800, 2);
        assert!(coin::balance<TestCoin>(recipient_2_addr) == 200, 3);

        move_to(token, TestCoinCapabilities {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }


    #[test(bank = @0x121, contract = @multisend, sender = @0x123, recipient_1 = @0x124, recipient_2 = @0x125, core = @0x1)]
    #[expected_failure(abort_code = 65539, location = multisend::sender)]
    public entry fun test_mutlisend_insuficient_funds(bank: &signer, contract: &signer, sender: &signer,
                                                      recipient_1: &signer, recipient_2: &signer, core: &signer) acquires Management {

        let bank_addr = address_of(bank);
        let sender_addr = address_of(sender);
        let recipient_1_addr = address_of(recipient_1);
        let recipient_2_addr = address_of(recipient_2);
        create_account(bank_addr);
        create_account(@multisend);
        create_account(sender_addr);
        create_account(recipient_1_addr);
        create_account(recipient_2_addr);

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(core);
        create(contract, bank_addr, 10);

        coin::deposit(sender_addr, coin::mint(1000, &mint_cap));

        multisend<AptosCoin>(sender, vector[recipient_1_addr, recipient_2_addr], vector[800, 200]);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }


    #[test(bank = @0x121, contract = @multisend, sender = @0x123, recipient_1 = @0x124, recipient_2 = @0x125, core = @0x1)]
    #[expected_failure(abort_code = 65537, location = multisend::sender)]
    public entry fun test_mutlisend_arguments_not_match(bank: &signer, contract: &signer, sender: &signer,
                                                        recipient_1: &signer, recipient_2: &signer, core: &signer) acquires Management {

        let bank_addr = address_of(bank);
        let sender_addr = address_of(sender);
        let recipient_1_addr = address_of(recipient_1);
        let recipient_2_addr = address_of(recipient_2);
        create_account(bank_addr);
        create_account(@multisend);
        create_account(sender_addr);
        create_account(recipient_1_addr);
        create_account(recipient_2_addr);

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(core);
        create(contract, bank_addr, 10);

        coin::deposit(sender_addr, coin::mint(1100, &mint_cap));

        multisend<AptosCoin>(sender, vector[recipient_1_addr], vector[800, 200]);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }



    #[test(bank = @0x123, contract = @multisend, new_bank = @0x124, new_admin = @0x125)]
    public entry fun test_update_config(contract: &signer, new_admin: &signer,
                                        bank: &signer, new_bank: &signer,) acquires Management {

        let bank_addr = address_of(bank);
        let new_bank_addr = address_of(new_bank);
        let new_admin_addr = address_of(new_admin);
        create_account(bank_addr);
        create_account(new_bank_addr);
        create_account(@multisend);
        create_account(new_admin_addr);

        create(contract, bank_addr, 10);

        assert!(get_admin() == @multisend, 0);
        assert!(get_bank_account() == bank_addr, 1);
        assert!(get_fee() == 10, 2);

        update_admin(contract, new_admin_addr);
        update_bank_account(new_admin, new_bank_addr);
        update_fee(new_admin, 15);

        assert!(get_admin() == new_admin_addr, 0);
        assert!(get_bank_account() == new_bank_addr, 1);
        assert!(get_fee() == 15, 2);
    }

    #[test(bank = @0x123, contract = @multisend, not_admin = @0x126)]
    #[expected_failure(abort_code = 65538, location = multisend::sender)]
    public entry fun test_update_fee_not_admin(contract: &signer, bank: &signer, not_admin: &signer) acquires Management {

        let bank_addr = address_of(bank);
        let not_admin_addr = address_of(not_admin);
        create_account(bank_addr);
        create_account(@multisend);
        create_account(not_admin_addr);

        create(contract, bank_addr, 10);
        update_fee(not_admin, 15);
    }


    #[test(bank = @0x123, contract = @multisend, not_admin = @0x126)]
    #[expected_failure(abort_code = 65538, location = multisend::sender)]
    public entry fun test_update_admin_not_admin(contract: &signer, bank: &signer, not_admin: &signer) acquires Management {

        let bank_addr = address_of(bank);
        let not_admin_addr = address_of(not_admin);
        create_account(bank_addr);
        create_account(@multisend);
        create_account(not_admin_addr);

        create(contract, bank_addr, 10);
        update_admin(not_admin, not_admin_addr);
    }


    #[test(bank = @0x123, contract = @multisend, not_admin = @0x126)]
    #[expected_failure(abort_code = 65538, location = multisend::sender)]
    public entry fun test_update_bank_not_admin(contract: &signer, bank: &signer, not_admin: &signer) acquires Management {

        let bank_addr = address_of(bank);
        let not_admin_addr = address_of(not_admin);
        create_account(bank_addr);
        create_account(@multisend);
        create_account(not_admin_addr);

        create(contract, bank_addr, 10);
        update_bank_account(not_admin, bank_addr);
    }

}