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
