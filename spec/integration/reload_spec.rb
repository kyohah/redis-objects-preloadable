# frozen_string_literal: true

# Regression spec for Rails 8.1 compatibility.
#
# Rails 8.1.2 changed ActiveRecord::Persistence#_find_record to call
# self.class.all(all_queries: all_queries) with a keyword argument.
# The ModelExtension.all override must forward all arguments to super
# to avoid ArgumentError: wrong number of arguments (given 1, expected 0).
RSpec.describe "reload compatibility" do
  let!(:widget) { Widget.create!(name: "w1") }

  before do
    widget.view_count.increment(5)
  end

  it "does not raise ArgumentError when calling reload" do
    expect { widget.reload }.not_to raise_error
  end

  it "returns the record after reload" do
    expect(widget.reload).to eq(widget)
  end

  it "reflects updated DB attributes after reload" do
    Widget.where(id: widget.id).update_all(name: "updated")
    widget.reload
    expect(widget.name).to eq("updated")
  end
end
