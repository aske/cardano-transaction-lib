# CTL integration with Plutip

[Plutip](https://github.com/mlabs-haskell/plutip) is a tool to run private Cardano testnets. CTL provides integration with Plutip via [`plutip-server` binary](https://github.com/Plutonomicon/cardano-transaction-lib/tree/develop/plutip-server) that exposes an HTTP interface to control local Cardano clusters.

**Table of Contents**
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Architecture](#architecture)
- [Testing contracts](#testing-contracts)
  - [Testing in Aff context](#testing-in-aff-context)
  - [Testing with Mote](#testing-with-mote)
  - [Note on SIGINT](#note-on-sigint)
  - [Testing with Nix](#testing-with-nix)
- [Cluster configuration options](#cluster-configuration-options)
  - [Limitations](#limitations)
- [Using addresses with staking key components](#using-addresses-with-staking-key-components)
  - [See also](#see-also)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->
## Architecture

CTL depends on a number of binaries in the `$PATH` to execute Plutip tests:

- `plutip-server` to launch a local `cardano-node` cluster
- [`ogmios`](https://ogmios.dev/)
- [`kupo`](https://cardanosolutions.github.io/kupo/)

All of these are provided by CTL's `overlays.runtime` (and are provided in CTL's own `devShell`). You **must** use the `runtime` overlay or otherwise make the services available in your package set (e.g. by defining them within your own `overlays` when instantiating `nixpkgs`) as `purescriptProject.runPlutipTest` expects all of them; an example of using CTL's overlays is in a [`ctl-scaffold` template](../templates/ctl-scaffold/flake.nix#L35).

The services are NOT run by `docker-compose` (via `arion`) as is the case with `launchCtlRuntime`: instead they are started and stopped on each CTL `ContractTest` execution by CTL itself.

If you have based your project on the [`ctl-scaffold` template](../templates/ctl-scaffold) then you have two options to run Plutip tests:
1. `nix develop` followed by `npm run test`
2. `nix run .#checks.x86_64-linux.ctl-scaffold-plutip-test`
   * where you'd usually replace `x86_64-linux` with the system you run tests on
   * and `ctl-scaffold-plutip-test` with the name of the plutip test package for your project;
   * note that compilation of your project via Nix will fail in case there are any warnings, so you'd need to either fix or temporarily disable them.

## Testing contracts

CTL can help you test the offchain `Contract`s from your project (and also the interaction of onchain and offchain code) by spinning up a disposable private testnet via Plutip and making all your `Contract`s interact with it.

There are two approaches to writing such tests.

[First](#testing-in-aff-context) is to use the `Contract.Test.Plutip.runPlutipContract` function, which takes a single `Contract`, launches a Plutip cluster and executes the passed contract.
This function runs in `Aff`; it will also throw an exception should contract fail for any reason.
After the contract execution the Plutip cluster is terminated.
You can either call it directly form your test's main or use any library for grouping and describing tests which support effects in the test body, like Mote.

[Mote](https://github.com/garyb/purescript-mote) is a DSL for defining and grouping tests (plus other quality of life features, e.g. skipping marked tests).


[Second](#testing-with-mote) (and more widely used) approach is to first build a tree of tests (in CTL's case a tree of `ContractTest` types) via Mote and then use the `Contract.Test.Plutip.testPlutipContracts` function to execute them.
This allows to set up a Plutip cluster only once per `group` and then use it in many independent tests.
The function will interpret a `MoteT` (effectful test tree) into `Aff`, which you can then actually run.

The [`ctl-scaffold` template](../templates/ctl-scaffold) provides a simple `Mote`-based example.


contracts run
only success is checked

to write actual tests use assertions library

### Testing in Aff context

`Contract.Test.Plutip.runPlutipContract`'s function type is defined as follows:

```purescript
runPlutipContract
  :: forall (distr :: Type) (wallets :: Type) (a :: Type)
   . UtxoDistribution distr wallets
  => PlutipConfig
  -> distr
  -> (wallets -> Contract a)
  -> Aff a
```

`distr` is a specification of how many wallets and with how much funds should be created. It should either be a `Unit` (for no wallets), nested tuples containing `Array BigInt` or an `Array` of `Array BigInt`, where each element of the `Array BigInt` specifies an UTxO amount in Lovelaces (0.000001 Ada).

The `wallets` argument of the callback is either a `Unit`, a tuple of `KeyWallet`s (with the same nesting level as in `distr`, which is guaranteed by `UtxoDistribution`) or an `Array KeyWallet`.

`wallets` should be pattern-matched on, and its components should be passed to `withKeyWallet`:

An example `Contract` with two actors using nested tuples:

```purescript
let
  distribution :: Array BigInt /\ Array BigInt
  distribution =
    [ BigInt.fromInt 1_000_000_000
    , BigInt.fromInt 2_000_000_000
    ] /\
      [ BigInt.fromInt 2_000_000_000 ]
runPlutipContract config distribution \(alice /\ bob) -> do
  withKeyWallet alice do
    pure unit -- sign, balance, submit, etc.
  withKeyWallet bob do
    pure unit -- sign, balance, submit, etc.
```

An example `Contract` with two actors using `Array`:

```purescript
let
  distribution :: Array (Array BigInt)
  distribution =
    -- wallet one: two UTxOs
    [ [ BigInt.fromInt 1_000_000_000, BigInt.fromInt 2_000_000_000]
    -- wallet two: one UTxO
    , [ BigInt.fromInt 2_000_000_000 ]
    ]
runPlutipContract config distribution \wallets -> do
  traverse_ ( \wallet -> do
                withKeyWallet wallet do
                  pure unit -- sign, balance, submit, etc.
            )
            wallets
```

In most cases at least two UTxOs per wallet are needed (one of which will be used as collateral, so it should exceed `5_000_000` Lovelace).


Internally `runPlutipContract` runs a contract in an `Aff.bracket`, which creates Plutip cluster during the setup and terminates it during the teardown or in the case of an exception.
Logs will be printed in case of error.

### Testing with Mote

`Contract.Test.Plutip.testPlutipContracts` type is defined as follows (after expansion of the CTL's `TestPlanM` type synonym):

```purescript
testPlutipContracts
  :: PlutipConfig
  -> MoteT Aff ContractTest Aff Unit
  -> MoteT Aff (Aff Unit) Aff Unit

-- Recall that `MoteT` has three type variables
newtype MoteT bracket test m a
```

where 
* `bracket :: Type -> Type` is where brackets will be run (before/setup is `bracket r` and after/teardown is of type `r -> bracket Unit`),
   * in our case it's `Aff` and is where the Plutip cluster startup/shutdown calls will be made for every `Bracket` from `Mote`
   * ...
   * TODO !!! do nested groups result in nested plutip cluster startups/shutdowns?
* `test :: Type` is a type of tests themselves,
   * in our case it's [`ContractTest`](../src/Internal/Test/ContractTest.hs), which in a nutshell describes a function from some wallet UTxO distribution to a `Contract r`
   * wallet UTxO distribution is the one that you need to pattern-match on when writing tests
* `m :: Type -> Type` is a monad where effects during the construction of the test suite can be performed,
   * here we use `Aff` again
* `a :: Type` is a result of the test suite, we use `Unit` here.

Here the final `MoteT` type requires the bracket, test and test building type to all be in `Aff`. The brackets cannot be ignored in the `MoteT` test runner, as it is what allows a single plutip instance to persist over multiple tests.

To create tests of type `ContractTest`, the user should either use `Contract.Test.Plutip.withWallets` or `Contract.Test.Plutip.noWallet`:

```purescript
withWallets
  :: forall (distr :: Type) (wallets :: Type)
   . UtxoDistribution distr wallets
  => distr
  -> (wallets -> Contract Unit)
  -> ContractTest

noWallet :: Contract Unit -> ContractTest
noWallet test = withWallets unit (const test)
```

Usage of `testPlutipContracts` is similar to that of `runPlutipContract`, and distributions are handled in the same way. The following is an example of running multiple tests under the same plutip instance:

```purescript
suite :: MoteT Aff (Aff Unit) Aff
suite = testPlutipContracts config do
  test "Test 1" do
    let
      distribution :: Array BigInt /\ Array BigInt
      distribution = ...
    withWallets distribution \(alice /\ bob) -> do
      ...

  test "Test 2" do
    let
      distribution :: Array BigInt
      distribution = ...
    withWallets distribution \alice -> do
      ...

  test "Test 3" do
    noWallet do
      ...
```

<!-- see a limitation on groups for complex protocols ... by mitch -->

### Note on SIGINT

Due to `testPlutipContracts`/`runPlutipContract` adding listeners to the SIGINT signal, node's default behaviour of exiting on that signal no longer occurs. This was done to add cleanup handlers and let them run in parallel instead of exiting eagerly, which is possible when running multiple clusters in parallel. To restore the exit behaviour, we provide helpers to cancel an `Aff` fiber and set the exit code, to let node shut down gracefully when no more events are to be processed.

```purescript
...
import Contract.Test.Utils (exitCode, interruptOnSignal)
import Data.Posix.Signal (Signal(SIGINT))
import Effect.Aff (cancelWith, effectCanceler, launchAff)

main :: Effect Unit
main = interruptOnSignal SIGINT =<< launchAff do
  flip cancelWith (effectCanceler (exitCode 1)) do
    ... test suite in Aff ...
```

### Testing with Nix

You can run Plutip tests via CTL's `purescriptProject` as well. After creating your project, you can use the `runPlutipTest` attribute to create a Plutip testing environment that is suitable for use with your flake's `checks`. An example:

```nix
{
  some-plutip-test = project.runPlutipTest {
    name = "some-plutip-test";
    testMain = "Test.MyProject.Plutip";
    # The rest of the arguments are passed through to `runPursTest`:
    env = { SOME_ENV_VAR = "${some-value}"; };
  };
}
```

The usual approach is to put `projectname-plutip-test` in the `checks` attribute of your project's `flake.nix`.
See a [`ctl-scaffold` template](../templates/ctl-scaffold/flake.nix) for an example.

## Cluster configuration options

`PlutipConfig` type contains `clusterConfig` record with the following options:

```purescript
{ slotLength :: Seconds
, epochSize :: Maybe UInt
, maxTxSize :: Maybe UInt
, raiseExUnitsToMax :: Boolean
}
```

- `slotLength` and `epochSize` define time-related protocol parameters. Epoch size is specified in slots.
- `maxTxSize` (in bytes) allows to stress-test protocols with more restrictive transaction size limits.
- `raiseExUnitsToMax` allows to bypass execution units limit (useful when compiling the contract with tracing in development and without it in production).

### Limitations

* Non-default value of `epochSize` (current default is 80) break staking rewards - see [this issue](https://github.com/mlabs-haskell/plutip/issues/149) for more info.
`slotLength` can be changed without any problems.

<!-- 2. share wallets for complex protocols (see mitch's slack) -->
<!-- 3. suite :: PlutipConfig -> TestPlanM (Aff Unit) Unit -->
<!-- suite config = -->
<!--   -- Plutip was creating too many connections with Kupo, causing tests to fail -->
<!--   -- if there was more than one `InitContract` in the test plan. Therefore, -->
<!--   -- each test plan will run on its own Plutip instance.  -->
<!--   group "CDP Plutip Tests" do -->
<!--     testPlutipContracts' config adjusting -->
<!--     testPlutipContracts' config merging -->
<!--     testPlutipContracts' config partialLiquidation -->

4. Also, there is this important fact that differs e.g. between PSM and Plutip - the time travel is not possible, like you can’t just go a year forward in time to see how a contract would behave after some time (real time).
That’s what we’ve found out when we were working with the Vesting contract.

you mean that it will take too much time and even slot length configuration doesn’t help that much?
Yup, that’s right, slot length doesn’t help at all in case you want to wait the actual time (e.g. 2 months, 1 year, etc.), it’s irrelevant from the slot length.

if you used plutus-simple-model ....

11:18
Such a test made sense in case of vesting script, where we wanted to test - after a year we want to unlock given amount of funds

When I was with Indigo, the main issue that I had with Plutip in CTL was about wallet creation. ContractTests are currently set up in a way that they need their own distribution for each wallet they are using inside of the test. This will create brand new wallets for every test. This is fine in most scenarios, but for a complicated protocol like Indigo, it is beneficial to have the same wallet when executing different tests. I implemented my own solution into a CTL fork that included an alternative way to create Test Plans inside of testPlutipContracts.
I feel like it should be possible to accomplish this without a fork, if startPlutipContractEnv was exported and there was more documentation around executing ContractTests inside of the ContractEnv that gets created.


kirill
  11:43 PM
ah, I see, so sameWallets function was from your fork?



## Using addresses with staking key components

It's possible to use stake keys with Plutip. `Contract.Test.Plutip.withStakeKey` function can be used to modify the distribution spec:

```purescript
let
  privateStakeKey :: PrivateStakeKey
  privateStakeKey = wrap $ unsafePartial $ fromJust
    $ privateKeyFromBytes =<< hexToRawBytes
      "633b1c4c4a075a538d37e062c1ed0706d3f0a94b013708e8f5ab0a0ca1df163d"
  aliceUtxos =
    [ BigInt.fromInt 2_000_000_000
    , BigInt.fromInt 2_000_000_000
    ]
  distribution = withStakeKey privateStakeKey aliceUtxos
```

Although stake keys serve no real purpose in plutip context, they allow to use base addresses, and thus allow to have the same code for plutip testing, in-browser tests and production.

Note that CTL re-distributes tADA from payment key-only ("enterprise") addresses to base addresses, which requires a few transactions before the test can be run. These transactions happen on the CTL side, because Plutip can currently handle only enterprise addreses (see [this issue](https://github.com/mlabs-haskell/plutip/issues/103)).

### See also

- To actually write the test bodies, [assertions library](./test-utils.md) can be useful.
