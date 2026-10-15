# Changelog

Versions follow semantic versioning. Dates are omitted on purpose: the tags carry them.

## Unreleased

<!-- Template of a version section. Keep the subsections that carry changes, drop the rest. -->

### Operations

### Inputs

### Execution

### Errors and reporting

### Deferred calls

### Around the gem

## 1.3.0

### Deferred calls

- `unique(strategy = :until_executing, ttl: nil)` marks an operation as unique while its job waits
  in the queue. An operation is never unique unless it says so. The job class takes the strategy
  from the base job (`unique(strategy, lock_ttl: ttl)`), in the process that enqueues and in a
  fresh worker that loads the job name. A base job without `unique` raises `ConfigurationError`.

## 1.2.2

### Deferred calls

- A worker that boots fresh now resolves the job name of a namespaced operation
  (`ServiceBroker::Jobs::Actions::CollectImpression`). The first missing segment became a plain
  class that could not answer the next segment, so every such job failed with
  `ActiveJob::UnknownJobClassError`. Only a process that had enqueued the operation itself ran it.

## 1.2.1

### Deferred calls

- A refused enqueue (job not unique, enqueue limit, `before_enqueue` abort) makes
  `call(async: true)` return `nil` and send no `service_broker.enqueue` event. It used to raise
  `NoMethodError: undefined method 'job_id' for false`.

## 1.2.0

### Inputs

- New option `coerce:` converts the value of an input before its type check, so a scalar can reach
  an `array` input. A failing `coerce` gives the error code `:coerce`.

## 1.1.0

### Operations

- `step(operation_class, **arguments)` calls another operation from `execute` or `validate`,
  returns its result and, on a failure, merges its errors and stops the operation. `as:` puts the
  errors of the step under one key.
- `before operation_class, **mapping` runs a step after the input check and before `execute`.
- `after operation_class, **mapping` runs a step once a successful call has committed. A failed
  step is reported and the result of the operation stands. `in_transaction: true` moves the step
  inside the transaction, `async: true` queues it, and `if:` takes a callable over the result.
- A value of a step is a symbol naming an input, an object answering `call`, or a literal.

### Execution

- New setting `max_step_depth` (10 by default) limits nested steps and raises
  `ServiceBroker::StepDepthError` beyond it.
- `step` joins the reserved input names.

### Around the gem

- Ruby 3.2 and Rails 7.0 are the new lower bounds, down from Ruby 3.4 and Rails 8.1. The suites run
  on both bounds in CI, the lower one through `gemfiles/rails_7_0.gemfile`.

## 1.0.0

First release.

### Operations

- `ServiceBroker::Operation`: declared inputs, one `.call` entry point, one instance `execute`.
- `ServiceBroker::SyncOperation` refuses `async: true` with `ServiceBroker::AsyncForbidden`.
- A family of operations shares inputs and `execute` through a base class and `abstract_methods`.
- `memo(:key) { ... }` keeps a value for the length of one call.
- A block passed to `.call` reaches `execute`.

### Inputs

- 14 types in the core: `string`, `integer`, `float`, `decimal`, `boolean`, `symbol`, `enum`,
  `date`, `time`, `duck`, `object`, `file`, `array`, `hash`.
- 4 more under Rails: `finder`, `model`, `gid`, `record`. `finder` takes a record, an id or a
  GlobalID string. `record` takes a record, a GlobalID or `{type:, id:}`.
- `of:` names the element type of `array` and the value type of `hash`.
- `transform:` converts a checked value, by a method name or a callable.
- `requires_one_of` demands exactly one input of a list.
- An unknown call key is an error, `hash` without declared keys is refused at load time, and a
  callable default is computed once per call.

### Execution

- Options `safe`, `soft`, `async`, `queue`, `delay`, `priority`, `log`, isolated per call.
- Class declarations `defaults`, `queue`, `wait`, `priority`, `async!`, `transactional!`, `log!`.
- `soft: true` answers with `ServiceBroker::Outcome`, which carries `success?`, `result`, `errors`,
  `inputs`, `raw_inputs` and `exception`.
- Without `soft`, a failed check raises `ServiceBroker::ValidationError` and an exception of
  `execute` reaches the caller unchanged.
- `safe: true` wraps input checking, `validate` and `execute` in one transaction, and takes its own
  savepoint inside a transaction that is already open.

### Errors and reporting

- `Errors`, `ErrorAtom` and structured failures through `throw_structured_error`.
- Texts come from a replaceable `message_builder`, so I18n stays in the application.
- `error_reporter`, `error_dedup` and an operation's own `report_context`.

### Deferred calls

- A replaceable `async_runner`, `ActiveJobAsync` by default, `InlineAsync` for tests.
- The job class carries the name of its operation and resolves in a worker that boots fresh.
- Records travel as GlobalIDs. A job whose record disappeared is reported once and not retried.
- Retries by `retry_after` on the exception and by `retry_on` rules per error class name.

### Around the gem

- Events `service_broker.call` and `service_broker.enqueue` through a replaceable `instrumenter`.
- `ServiceBroker::Testing`: `with_queued_operations`, `with_inline_operations`,
  `assert_operation_queued`.
- A `service_broker:install` generator writes one settings file.
