## Technical Overview

The Multisender Contract is a powerful, blockchain-based tool designed to facilitate batch transactions, enabling users
to transfer tokens to multiple accounts in a single operation. This tool is highly useful in various use cases, such as
distributing tokens in airdrops, sending out remuneration to workers, or making payments for goods procured from
different vendors.

One of the distinct features of this contract is the imposition of a fixed 10% fee on every transaction, whether the
transaction involves native or other tokens. This consistent fee structure contributes to the sustainability and
maintenance of the operational services provided by the contract

## Fee Structure
Every transaction that goes through this contract will have a 10% fee automatically deducted. This fee structure
supports the contract's continued operation and service provision, providing a predictable cost basis for users.

### running aptos tests

`cd aptos && aptos move test --named-addresses multisend=default`

