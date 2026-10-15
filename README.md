# ServiceBroker

Application operations for Rails: declared inputs, one entry point, one `execute`, and a
replaceable runner for deferred work.

```ruby
class Media::BuildThumbnail < ServiceBroker::Operation
  required do
    finder :media, model: ::Media
    integer :width, min: 1, max: 4096
  end

  optional do
    boolean :crop, default: false
  end

  def execute
    media.build_thumbnail(width: width, crop: crop)
  end
end

Media::BuildThumbnail.call(media: 42, width: 320)                      # => the result of execute
Media::BuildThumbnail.call(media: 42, width: 320, soft: true)          # => ServiceBroker::Outcome
Media::BuildThumbnail.call(media: 42, width: 320, async: true)         # => a job id
```

- An input is declared once and checked before `execute` runs.
- A failed check raises `ServiceBroker::ValidationError`, or returns an outcome with `soft: true`.
- A call never swallows an exception: it reaches the caller unless you ask for `soft: true`.
- Deferred calls go through one replaceable runner, and the job in the queue is named after the
  operation.

## Installation

```ruby
gem 'service_broker'
```

```sh
bundle install
bin/rails generate service_broker:install   # writes config/initializers/service_broker.rb
```

Ruby 3.2 or newer, Rails 7.0 or newer. The core needs `activesupport` only. `activerecord` and
`activejob` back the `finder`, `model`, `gid` and `record` inputs, the `safe` option and the
ActiveJob runner.

## Declaring inputs

```ruby
class Billing::ChargeCard < ServiceBroker::Operation
  required do
    finder :account, model: ::Account, preload: :cards
    decimal :amount, min: 0.01
    hash :address do
      required { string :city, max_length: 80 }
      optional { string :postcode, matches: /\A\d{4}\z/ }
    end
  end

  optional do
    enum :currency, values: %i[aud usd], default: :aud
    array :tags, of: :string, max_length: 10
    hash :counters, of: :integer
    object :receipt_sink
    string :reference, transform: :upcase
  end

  requires_one_of :account, :card

  def execute
    # account is a record, amount is a BigDecimal, address keys are checked
  end
end
```

| Type | Accepts | Error codes |
| --- | --- | --- |
| `string` | text, plus scalars unless `strict: true` | `:string`, `:empty`, `:min_length`, `:max_length`, `:matches`, `:in` |
| `integer` | `Integer`, a whole-number string | `:integer`, `:min`, `:max`, `:in` |
| `float` | `Float`, `Integer`, `BigDecimal`, `Rational`, a number string | `:float`, `:min`, `:max`, `:in` |
| `decimal` | `BigDecimal`, `Integer`, `Rational`, a number string | `:decimal`, `:min`, `:max`, `:in` |
| `boolean` | `true`, `false`, `1`, `0`, `'true'`, `'false'`, `'1'`, `'0'` | `:boolean` |
| `symbol` | `Symbol`, a non-blank string | `:symbol`, `:in` |
| `enum` | a name out of the declared `values`, in as text or symbol, out as a symbol | `:enum`, `:in` |
| `date` | `Date`, `DateTime`, `Time`, a parsable string | `:date`, `:after`, `:before`, `:on_or_after`, `:on_or_before` |
| `time` | `Time`, `Date`, `DateTime`, a parsable string | `:time`, and the same bound codes |
| `duck` | anything answering the named `methods` | `:duck` |
| `object` | any value except `nil` | `:nils` |
| `file` | anything answering `read` and `size` | `:file`, `:size` |
| `array` | `Array` with one element type, from a block, `of:` or `class:` | `:array`, `:min_length`, `:max_length`, `:class` |
| `hash` | `Hash` with declared keys, or `of:` for every value | `:hash`, `:required`, `:unknown_input` |
| `finder` | a record, its id or its GlobalID string | `:not_found`, `:model`, `:new_records` |
| `model` | an object of the declared class | `:model`, `:new_records` |
| `gid` | a GlobalID string | `:gid`, `:not_found`, `:in` |
| `record` | any record: the object, its GlobalID or `{type:, id:}` | `:record`, `:not_found`, `:in` |

Every type takes `nils: true` to accept an explicit `nil`, `coerce:` to convert the value before the
type check, `transform:` to convert it after, and every scalar type takes `empty_is_nil: true`. Optional inputs also take `default:`,
`discard_nils`, `discard_empty`, `discard_invalid` and `error_key`.

```ruby
array :ids, of: :integer                      # one element type by name
array :users, of: :finder, model: ::User      # element options ride along
hash :counters, of: :integer                  # every value of any key
string :email, transform: :downcase           # a method of the value
array :ids, of: :integer, transform: ->(list) { list.uniq }
array :ids, of: :integer, coerce: ->(value) { Array(value) }   # one id arrives as a scalar
requires_one_of :account, :card               # exactly one of the two
```

Strict by design:

- An unknown call key is an error (`:unknown_input`). Add `allow_unknown true` to the class when a
  pass-through is what you want.
- `hash :payload` without a block is refused at load time, so no unchecked hash reaches `execute`.
- `'12abc'` is not 12, `'3.7'` is not 3, `'yes'` is not `true`, and `0.1` is not an exact decimal.
- A `default:` written as a callable is computed once per call and remembered for that call.

## Calling an operation

`.call(**args, &block)` is the only entry point for application code. `run`, `run!`, `run_sync` and
`validate` exist for tests and for the queue.

| Option | Default | Effect |
| --- | --- | --- |
| `safe` | `false` | Wraps input checking, `validate` and `execute` in one transaction |
| `soft` | `false` | Returns an `Outcome` instead of raising |
| `async` | `false` | Queues the call and returns a job id |
| `queue` | `:default` | Queue name for the deferred call |
| `delay` | `nil` | Seconds or an `ActiveSupport::Duration` to wait |
| `priority` | `nil` | Priority for the deferred call |
| `log` | `false` | Writes one line before and one after the call |

Class-level defaults, as a hash or as short declarations:

```ruby
class Media::Analyze < ServiceBroker::Operation
  defaults async: true, queue: :media, priority: 10
end

class Media::Analyze < ServiceBroker::Operation
  async!
  queue :media
  priority 10
  wait 30
  transactional!
  log!
end
```

Options belong to one call: two threads calling the same operation with different options never
see each other's values, and a nested call reads its own defaults.

Uniqueness is opt-in. An operation is never unique unless it declares it, and the job library
(for example `activejob-uniqueness`) supplies the strategy:

```ruby
class Media::Analyze < ServiceBroker::Operation
  unique :until_executing, ttl: 10.minutes
end
```

Answers:

```ruby
result  = Billing::ChargeCard.call(...)              # the result of execute
outcome = Billing::ChargeCard.call(..., soft: true)  # success?, result, errors, inputs, raw_inputs, exception
job_id  = Billing::ChargeCard.call(..., async: true) # the id the runner returned
```

`ServiceBroker::SyncOperation` is the base for work that must never be queued: a call with
`async: true` raises `ServiceBroker::AsyncForbidden`.

## Chaining operations

An operation calls another one with `step`, and the chain stops on the first failure:

```ruby
class Purchases::Grant < ServiceBroker::Operation
  required do
    model :user, class: ::User
    symbol :kind
    hash :payload, of: :string
  end

  before Purchases::CheckQuota, user: :user
  after  User::PremiumGrantReconcile, user: :user
  after  Media::Analyze, async: true, media: ->(result) { result.media }, if: ->(result) { result.media }

  def execute
    receipt = step(Purchases::Verify, user:, kind:, payload:)

    step(User::PremiumGrantCreate, user:, receipt:)
  end
end
```

| Name | Where it runs | A failed step |
| --- | --- | --- |
| `step(Klass, **args)` | inside `execute` and `validate` | its errors become yours, the operation stops |
| `before Klass, **mapping` | after the input check, before `execute` | the same, and `execute` never runs |
| `after Klass, **mapping` | after a successful `execute` | reported through `error_reporter`, your result stands |

- `step` calls the other operation with `soft: true` and returns its result. No option of the outer
  call reaches it.
- Errors of a step merge at the top level, so `outcome.errors.symbolic` reads the same as the step
  returned it. `step(Klass, as: :payment, ...)` puts them under `payment` instead.
- An `after` step runs once the transaction of the call has committed. `in_transaction: true` moves
  it inside, where a failure rolls the whole call back.
- A value of a step is a symbol naming one of your inputs, an object answering `call`, or a literal.
  A callable receives the result of `execute` in `after` and the operation itself in `before`.
- `async: true` queues the step, `if:` takes a callable over the result, and both names, like
  `in_transaction`, stay out of the arguments of the step.
- Nested steps are limited by `config.max_step_depth`, so two operations calling each other raise
  `ServiceBroker::StepDepthError` instead of running forever.

## Errors

```ruby
def execute
  throw_error(:not_allowed, "Card #{card.last4} is blocked") unless card.active?
  throw_structured_error(code: :rate_limited, retry_after: 30, message: 'Too many charges')
end
```

```ruby
outcome = Billing::ChargeCard.call(account: 1, amount: 'x', soft: true)
outcome.errors.symbolic      # => {"amount" => :decimal}
outcome.errors.message       # => {"amount" => "Amount isn't an exact number"}
outcome.errors.message_list  # => ["Amount isn't an exact number"]
```

- `add_error(:field, :code, 'optional text')` is available in `validate` and in `execute`.
- `merge_errors(other_outcome.errors)` keeps the keys of a nested operation.
- Error texts come from `config.message_builder`, so I18n stays in your application.
- A failed check raises `ServiceBroker::ValidationError`, which carries `errors`.

## Deferred calls

```ruby
Media::Analyze.call(media: 42, async: true, queue: :media, delay: 5.minutes)
```

Records travel as GlobalIDs: an input holding a record is serialized by its global id and comes
back as the record inside the worker, for the `finder`, `model`, `record` and `gid` types. A job
whose record was deleted in the meantime is not retried, and the failure is reported once.

- The job class is built per operation, so the queue shows
  `ServiceBroker::Jobs::Media::Analyze` instead of one shared job name.
- `config.job_parent_name` picks the parent job, usually `'ApplicationJob'`, so your retries,
  uniqueness and labels keep working.
- An input the queue cannot serialize raises `ServiceBroker::SerializationError` at call time, not
  inside the worker.
- A queued call that fails its input check is not retried.
- An exception answering `retry_after` schedules the retry at that moment. Other classes retry
  through `config.retry_on`:

```ruby
config.retry_on = { 'Faraday::TimeoutError' => { attempts: 3, wait: 5 } }
```

Another backend is one object with 2 methods:

```ruby
class SidekiqRunner
  def enqueue(operation_class, inputs, queue:, delay:, priority:)
    SidekiqJob.set(queue: queue).perform_in(delay.to_i, operation_class.name, inputs)
  end

  def job_name_for(operation_class) = operation_class.name
end

ServiceBroker.configure { |config| config.async_runner = SidekiqRunner.new }
```

## Events

```ruby
config.instrumenter = lambda do |name, payload|
  ActiveSupport::Notifications.instrument(name, payload)
end
```

`service_broker.call` carries the operation name, the options, input names with their classes, the
success flag, the error class and the duration in milliseconds. `service_broker.enqueue` carries
the queue, the delay, the priority and the job id. Input values never reach a payload.

## Reporting

```ruby
config.error_reporter = ->(error, **context) { Sentry.capture_exception(error, extra: context) }
config.error_dedup = ->(context:, error_class:) { RateGate.allow?(context, error_class) }
```

The reporter receives the operation name, the input names with their classes and anything an
operation adds through a private `report_context`:

```ruby
private

def report_context
  { account_id: account.id, provider: :stripe }
end
```

## Extending

A new input type:

```ruby
class MoneyFilter < ServiceBroker::Filters::Base
  def self.default_options = { nils: false, currency: 'AUD' }

  def filter(value)
    return [value, :money] unless value.is_a?(String) && value.match?(/\A\d+(\.\d{2})?\z/)

    [Money.new(value, options[:currency]), nil]
  end
end

ServiceBroker::Filters.register(:money, MoneyFilter)
```

A family of operations shares its inputs and its `execute` through a base class, and names the
methods a subclass has to supply:

```ruby
class Providers::Base < ServiceBroker::Operation
  abstract_methods :endpoint

  required { string :token }

  def execute
    Net::HTTP.get(URI(endpoint))
  end
end
```

Inside `execute`, `memo(:key) { ... }` keeps a value for the length of that call.

## Testing an application

```ruby
require 'service_broker/testing'

class CheckoutTest < ActiveSupport::TestCase
  include ServiceBroker::Testing

  test 'queues the charge' do
    with_queued_operations do
      Checkout.call(cart: cart)

      assert_operation_queued(Billing::ChargeCard, amount: 10)
    end
  end

  test 'charges the card' do
    with_inline_operations { Checkout.call(cart: cart) }

    assert_equal 1, cart.account.charges.count
  end
end
```

## Settings

| Setting | Default | Role |
| --- | --- | --- |
| `async_runner` | ActiveJob runner under Rails | Queues deferred calls |
| `error_reporter` | no-op | Receives an exception of a failed call |
| `error_dedup` | allows every report | Answers `false` to skip a repeated report |
| `message_builder` | built-in English texts | Builds the text of one error |
| `logger` | no-op | Receives one line about a call with `log: true` |
| `instrumenter` | `nil` | Receives one event per call and per queueing |
| `retry_on` | `{}` | Retry rules per error class name |
| `job_parent_name` | `'ActiveJob::Base'` | Parent of the generated job classes |
| `max_retries` | `25` | Upper limit of retries of one queued operation |
| `max_step_depth` | `10` | Upper limit of nested steps of one call |

## License

MIT, see [LICENSE](LICENSE).
