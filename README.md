# FraxCake Swap Hook

Hook based on FraxPoints to discount for swaps.

## Prerequisite

1. Install foundry, see https://book.getfoundry.sh/getting-started/installation

## Running test

1. Install dependencies with `forge install`
2. Run test with `forge test`

## Deployments

Frax Testnet (Holesky):
- SwapFee: [0xa88B7b20fE4b88A0C7C56521366414441ef4cF05](https://holesky.fraxscan.com/address/0xa88B7b20fE4b88A0C7C56521366414441ef4cF05)

## Description

### SwapFee Contract

The `SwapFee` contract is designed to manage swap fee discounts for token holders based on their token balances. It allows for tiered discounts depending on the percentage of the total token supply that a holder possesses. Here's a breakdown of the contract's functionality:

1. **Constructor**: Initializes the contract with specific parameters:
    - `fraxPointsAddress`: The address of the `fraxPoints` token contract.
    - `tier1Divider`, `tier2Divider`, `tier3Divider`: Divisors that determine the thresholds for different discount tiers.
    - `tier1Discount`, `tier2Discount`, `tier3Discount`: The corresponding discount percentages for each tier.

2. **Discount Logic**: 
    - Token holders are eligible for a discount based on the amount of `fraxPoints` they hold.
    - There are three discount tiers:
        - **Tier 1**: Holders with more than 1/4 of the total `fraxPoints` supply receive a 50% discount.
        - **Tier 2**: Holders with more than 1/8 of the total `fraxPoints` supply receive a 20% discount.
        - **Tier 3**: Holders with more than 1/32 of the total `fraxPoints` supply receive a 10% discount.

3. **Functionality**:
    - The contract interacts with the `fraxPoints` token to determine a user's balance.
    - It calculates the appropriate discount tier for each user and adjusts the swap fees accordingly.

### FraxcakeSwapHook Contract

The `FraxcakeSwapHook` contract integrates with the PancakeSwap V4 core and allows for customized swap fee handling based on the `fraxPoints` balance of the users. Here's how it works:

1. **Initialization**:
    - Deploys the `FraxcakeSwapHook` contract with a reference to the `SwapFee` contract.
    - Configures the swap pool with initial parameters, including the swap fee logic.

2. **Pool Key Creation**:
    - A `PoolKey` is created with details about the tokens involved in the pool (`currency0` and `currency1`), the fee structure, and the custom hook logic.
    - The pool is initialized with a 1:1 price point and a dynamic LP fee flag.

3. **Liquidity Management**:
    - The contract adds deep liquidity to the pool, ensuring significant liquidity for swaps.
    - Token balances and approvals are managed to facilitate seamless swaps for test cases.

4. **Test Cases**:
    - **Non-FraxPoints Holder**: Tests swaps for users without any `fraxPoints`, ensuring they receive the standard swap fee without any discount.
    - **Tier 1, 2, and 3 Holders**: Tests swaps for users in each discount tier, verifying they receive the correct fee reduction based on their `fraxPoints` balance.

5. **Internal Swap Function**:
    - The `_swap` function handles the actual token swap logic, interacting with the swap router to execute the swap based on the provided parameters.
    - It calculates the output amount and verifies the correct application of swap fees and discounts.

### Detailed Walkthrough of the Test Cases

1. **setUp Function**:
    - Deploys the `SwapFee` contract with specified tier thresholds and discounts.
    - Initializes the tokens and adds liquidity to the pool.
    - Sets up the `FraxcakeSwapHook` contract and prepares the pool key with appropriate parameters.
    - Approves tokens for Alice to use in swap operations and mints `fraxPoints` to Bob.

2. **testNonFraxPointsHolder**:
    - Performs a swap operation for a user without `fraxPoints`.
    - Asserts that the amount received is reduced by the standard swap fee, ensuring no discount is applied.

3. **testFraxPointsTier1Holder**:
    - Mints `fraxPoints` to Alice, placing her in Tier 1.
    - Executes a swap and asserts that Alice receives the maximum discount, verifying the correct application of the Tier 1 fee reduction.

4. **testFraxPointsTier2Holder**:
    - Mints `fraxPoints` to Alice, placing her in Tier 2.
    - Executes a swap and asserts that Alice receives the Tier 2 discount, verifying the correct application of the Tier 2 fee reduction.

5. **testFraxPointsTier3Holder**:
    - Mints `fraxPoints` to Alice, placing her in Tier 3.
    - Executes a swap and asserts that Alice receives the Tier 3 discount, verifying the correct application of the Tier 3 fee reduction.

The `FraxcakeSwapHook` and `SwapFee` contracts work together to provide a flexible and efficient swap fee discount system based on token holdings, ensuring a dynamic and user-friendly experience on the PancakeSwap platform.
