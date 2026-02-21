# frozen_string_literal: true

RSpec.describe "reload behavior" do
  let!(:widget) { Widget.create!(name: "w1") }

  before { widget.view_count.increment(5) }

  # --- Rails 8.1 compatibility (ArgumentError regression) ---

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

  # --- Preload state is intentionally NOT cleared on reload (by design) ---
  #
  # redis-objects attributes are independent of the DB record lifecycle.
  # Calling reload refreshes DB columns only; any preloaded Redis values
  # remain cached on the redis-objects instances.
  # If you need a fresh Redis value after reload, access the attribute on
  # a newly fetched record (e.g. Widget.find(id)) or use the redis-objects
  # instance directly (widget.view_count.value without preloading).

  context "when the record was preloaded" do
    before do
      records = Widget.where(id: widget.id).redis_preload(:view_count).load
      @preloaded_widget = records.first
      @preloaded_widget.view_count.value  # resolve! to populate @preloaded_value
    end

    it "retains the preloaded value after reload (by design)" do
      widget.view_count.increment(10)  # Redis value is now 15
      @preloaded_widget.reload

      # Preloaded value is still cached — this is the documented behaviour.
      expect(@preloaded_widget.view_count.value).to eq(5)
    end
  end
end
