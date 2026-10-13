# Мутации проверок

Каждая строка это 1 правка кода, которая нарушает требования файла спеки, и красный итог прогона с
ней. Правки лежат в `test/mutations.json`, прогон идёт командой `bin/mutate`.

| Спека | Файл правки | Набор | Итог прогона с мутацией |
| --- | --- | --- | --- |
| 01-scope.md | `lib/service_broker.rb` | core | 225 runs, 782 assertions, 1 failures, 2 errors |
| 02-operation.md | `lib/service_broker/operation.rb` | core | 225 runs, 790 assertions, 1 failures, 0 errors |
| 03-inputs.md | `lib/service_broker/input_set.rb` | core | 225 runs, 789 assertions, 0 failures, 3 errors |
| 04-filters.md | `lib/service_broker/filters/numeric.rb` | core | 225 runs, 768 assertions, 0 failures, 3 errors |
| 05-execution.md | `lib/service_broker/operation.rb` | core | 225 runs, 784 assertions, 11 failures, 0 errors |
| 06-errors.md | `lib/service_broker/errors.rb` | core | 225 runs, 791 assertions, 1 failures, 0 errors |
| 07-async.md | `lib/service_broker/queueing.rb` | core | 225 runs, 790 assertions, 1 failures, 0 errors |
| 08-rails.md | `lib/service_broker/rails/filters/finder.rb` | rails | 52 runs, 146 assertions, 2 failures, 1 errors |
| 09-extensions.md | `lib/service_broker/filters.rb` | core | 225 runs, 792 assertions, 1 failures, 0 errors |
| 10-testing.md | `lib/service_broker/configuration.rb` | meta | 17 runs, 114 assertions, 4 failures, 0 errors |
| 12-events.md | `lib/service_broker/events.rb` | core | 225 runs, 776 assertions, 3 failures, 1 errors |
| 13-testing-helpers.md | `lib/service_broker/testing.rb` | core | 225 runs, 792 assertions, 2 failures, 0 errors |
| 14-composition.md | `lib/service_broker/composition.rb` | core | 225 runs, 784 assertions, 2 failures, 3 errors |

## Что меняет каждая мутация

| Спека | Правка |
| --- | --- |
| 01-scope.md | Загрузка `InlineAsync` убрана из корневого файла |
| 02-operation.md | Запрет своего `initialize` отключён |
| 03-inputs.md | Неизвестный ключ вызова принимается вместо ошибки |
| 04-filters.md | Регулярка целого числа теряет якоря и принимает `'12abc'` |
| 05-execution.md | Вызов без `soft` возвращает `nil` вместо исключения |
| 06-errors.md | Код ошибки приводится методом `to_sym` вместо отказа |
| 07-async.md | Вызов наследника `SyncOperation` с `async` молча проходит |
| 08-rails.md | Несохранённая запись проходит проверку `finder` |
| 09-extensions.md | Повторная регистрация занятого имени типа молча заменяет его |
| 10-testing.md | Новая настройка добавлена в код, но не в README |
| 12-events.md | Получатель событий не вызывается |
| 13-testing-helpers.md | Прежний механизм очереди не возвращается после блока |
| 14-composition.md | Провал шага возвращает результат вместо ошибок и операция идёт дальше |
