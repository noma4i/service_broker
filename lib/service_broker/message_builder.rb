module ServiceBroker
  # Builds the English text of one error out of the input name and the code.
  class MessageBuilder
    TEXTS = {
      required: 'is required',
      unknown_input: 'is not an input of this operation',
      nils: "can't be nil",
      empty: "can't be blank",
      string: "isn't a string",
      integer: "isn't an integer",
      float: "isn't a number",
      decimal: "isn't an exact number",
      boolean: "isn't a boolean",
      symbol: "isn't a symbol",
      date: "isn't a date",
      time: "isn't a time",
      duck: "doesn't answer to the methods this input needs",
      file: "isn't a file",
      array: "isn't an array",
      hash: "isn't a hash",
      model: "isn't the right class",
      gid: "isn't a global id",
      not_found: 'was not found',
      new_records: "isn't a saved record",
      min: 'is too small',
      max: 'is too big',
      min_length: 'is too short',
      max_length: 'is too long',
      matches: "isn't in the right format",
      in: "isn't an option",
      size: 'is too big',
      class: "isn't the right class",
      after: "isn't after the given moment",
      before: "isn't before the given moment",
      on_or_after: 'is before the given moment',
      on_or_before: 'is after the given moment',
      exception: 'could not be processed'
    }.freeze

    def call(key, code, index: nil)
      name = titleize(key)
      name = "#{name}[#{index}]" if index

      "#{name} #{TEXTS.fetch(code, 'is invalid')}"
    end

    private

    def titleize(key)
      text = key.to_s.tr('_', ' ')
      return 'ID' if text == 'id'

      text.sub(/\Aid\z/, 'ID').split.map(&:capitalize).join(' ')
    end
  end
end
