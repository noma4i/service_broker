---
name: Bug report
about: One defect of the gem, with the smallest operation that shows it
labels: []
---

## The operation

```ruby
class Probe::Example < ServiceBroker::Operation
  required do
    # the inputs that matter
  end

  def execute
    # what it does
  end
end
```

## The call and what came back

```ruby
Probe::Example.call(...)
# => what you got
# expected: what you expected
```

## Versions

- service_broker:
- ruby:
- rails:
