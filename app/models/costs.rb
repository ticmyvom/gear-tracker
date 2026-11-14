# Totals per currency. Amounts in different currencies are kept apart, since
# adding them would need exchange rates.
class Costs
  include Enumerable

  def self.of(records, attribute)
    records.reduce(new) { |costs, record| costs.add(record.public_send(attribute), record.currency) }
  end

  def initialize(amounts = {})
    @amounts = amounts.freeze
  end

  def add(amount, currency)
    return self if amount.nil?

    self.class.new(@amounts.merge(currency => @amounts.fetch(currency, 0) + amount))
  end

  def +(other)
    other.reduce(self) { |costs, (currency, amount)| costs.add(amount, currency) }
  end

  def /(number)
    self.class.new(@amounts.transform_values { it.to_d / number })
  end

  def [](currency)
    @amounts.fetch(currency, 0)
  end

  def each(&)
    @amounts.each(&)
  end

  def empty?
    @amounts.empty?
  end

  def ==(other)
    other.is_a?(Costs) && to_h == other.to_h
  end
end
